// Replace your existing MainActivity.kt with this file.
// KEEP the package line below matching YOUR project's existing package.
//
// Location: android/app/src/main/kotlin/<your/package/path>/MainActivity.kt
//
// Needs these permissions in AndroidManifest.xml:
//   INTERNET, ACCESS_WIFI_STATE, ACCESS_NETWORK_STATE, CHANGE_WIFI_MULTICAST_STATE

package com.signalscope.signalscope // <-- change to YOUR package name

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.net.ConnectException
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.Inet4Address
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.NetworkInterface
import java.net.Socket
import java.net.SocketTimeoutException
import java.util.Locale
import java.util.concurrent.Callable
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "signalscope/wifi")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getRssi" -> {
                        val rssi = currentRssi()
                        if (rssi != null) result.success(rssi)
                        else result.error("UNAVAILABLE", "RSSI not available", null)
                    }
                    "getSsid" -> {
                        // May be null if location permission/services are off —
                        // that is an OS restriction, not an error here.
                        result.success(currentSsid())
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "signalscope/lan")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Slow (several seconds) — runs on a worker thread.
                    "scanLanDevices" -> scanLanDevices(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun wifiManager(): WifiManager =
        applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

    /** Connected network's signal strength in dBm, or null. */
    private fun currentRssi(): Int? {
        return try {
            @Suppress("DEPRECATION")
            val rssi = wifiManager().connectionInfo?.rssi
            if (rssi == null || rssi == -127) null else rssi
        } catch (e: Exception) {
            null
        }
    }

    /** Connected network's SSID (quotes stripped), or null when hidden by the OS. */
    private fun currentSsid(): String? {
        return try {
            @Suppress("DEPRECATION")
            var ssid = wifiManager().connectionInfo?.ssid ?: return null
            if (ssid.length >= 2 && ssid.startsWith("\"") && ssid.endsWith("\"")) {
                ssid = ssid.substring(1, ssid.length - 1)
            }
            // WifiManager.UNKNOWN_SSID is "<unknown ssid>"; "0x" also means hidden.
            if (ssid.isEmpty() || ssid == "<unknown ssid>" || ssid == "0x") null else ssid
        } catch (e: Exception) {
            null
        }
    }

    // --- LAN device scan ------------------------------------------------------

    /**
     * Multi-method discovery of the phone's /24 subnet:
     *  1. Ping + TCP probe of every host ("connection refused" also proves a
     *     host is alive).
     *  2. SSDP / UPnP multicast  (TVs, consoles, media boxes, routers).
     *  3. mDNS / Bonjour multicast (Apple devices, Chromecast, printers, IoT).
     *  4. ARP table for MAC addresses (restricted on some Android 10+ builds).
     *  5. Reverse DNS for hostnames.
     * Result is posted on the main thread as
     * { selfIp, gatewayIp, devices: [{ip, mac, hostname?, role?}] }.
     */
    private fun scanLanDevices(result: MethodChannel.Result) {
        thread {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            var lock: WifiManager.MulticastLock? = null
            try {
                bindToWifi(cm)
                lock = acquireMulticastLock()

                val self = localIPv4() ?: ""
                val gateway = currentGateway(self)
                val prefix = self.substringBeforeLast('.', "")

                val alive = ConcurrentHashMap.newKeySet<String>()

                if (prefix.isNotEmpty()) {
                    // Multicast listeners run alongside the sweep.
                    val ssdpThread = thread { ssdpDiscover(alive) }
                    val mdnsThread = thread { mdnsDiscover(alive) }

                    // 1. Sweep every host of the subnet.
                    val pool = Executors.newFixedThreadPool(64)
                    for (i in 1..254) {
                        val ip = "$prefix.$i"
                        if (ip == self) continue
                        pool.execute { probeHost(ip, alive) }
                    }
                    pool.shutdown()
                    if (!pool.awaitTermination(25, TimeUnit.SECONDS)) pool.shutdownNow()

                    ssdpThread.join(6000)
                    mdnsThread.join(6000)
                }

                // 4. Pair live hosts with MAC addresses.
                val arp = arpTable()
                for (ip in arp.keys) if (prefix.isNotEmpty() && ip.startsWith("$prefix.")) alive.add(ip)
                if (gateway != null) alive.add(gateway)
                alive.remove(self)

                val ips = alive.filter { prefix.isNotEmpty() && it.startsWith("$prefix.") }
                val names = resolveNames(ips)

                val devices = ArrayList<HashMap<String, Any>>()
                for (ip in ips) {
                    val row = HashMap<String, Any>()
                    row["ip"] = ip
                    row["mac"] = arp[ip] ?: ""
                    names[ip]?.let { row["hostname"] = it }
                    if (ip == gateway) row["role"] = "gateway"
                    devices.add(row)
                }

                // The phone itself (MAC comes from its own network interface).
                if (self.isNotEmpty()) {
                    val row = HashMap<String, Any>()
                    row["ip"] = self
                    row["mac"] = arp[self] ?: selfMac()
                    row["role"] = "self"
                    devices.add(row)
                }

                // Gateway first, then self, then everything else by address.
                devices.sortWith(
                    compareBy(
                        { when (it["role"]) { "gateway" -> 0; "self" -> 1; else -> 2 } },
                        { lastOctet(it["ip"].toString()) },
                    )
                )

                val out = HashMap<String, Any>()
                out["selfIp"] = self
                out["gatewayIp"] = gateway ?: ""
                out["devices"] = devices
                mainHandler.post { result.success(out) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("SCAN_FAILED", e.message ?: "LAN scan failed", null)
                }
            } finally {
                try { if (lock?.isHeld == true) lock.release() } catch (_: Exception) {}
                try { cm.bindProcessToNetwork(null) } catch (_: Exception) {}
            }
        }
    }

    /** Keep scan traffic on WiFi even when mobile data is also active. */
    private fun bindToWifi(cm: ConnectivityManager) {
        try {
            @Suppress("DEPRECATION")
            val net = cm.allNetworks.firstOrNull {
                cm.getNetworkCapabilities(it)
                    ?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
            }
            if (net != null) cm.bindProcessToNetwork(net)
        } catch (_: Exception) {
        }
    }

    /** Multicast packets are dropped by the WiFi chip unless a lock is held. */
    private fun acquireMulticastLock(): WifiManager.MulticastLock? {
        return try {
            wifiManager().createMulticastLock("signalscope-lan").apply {
                setReferenceCounted(false)
                acquire()
            }
        } catch (e: Exception) {
            null // permission missing -> SSDP/mDNS may find less, sweep still works
        }
    }

    private val probePorts = intArrayOf(80, 443, 445, 62078, 8080, 53)
    private var pingBinaryAvailable = true

    /** Marks [ip] alive if it answers ping, accepts a TCP connect, or actively
     *  refuses one (a RST proves a host is there). */
    private fun probeHost(ip: String, alive: MutableSet<String>) {
        if (pingBinaryAvailable) {
            try {
                val proc = Runtime.getRuntime()
                    .exec(arrayOf("/system/bin/ping", "-c", "1", "-W", "1", ip))
                val code = proc.waitFor()
                proc.destroy()
                if (code == 0) { alive.add(ip); return }
            } catch (e: Exception) {
                pingBinaryAvailable = false
            }
        }
        if (!pingBinaryAvailable) {
            try {
                if (InetAddress.getByName(ip).isReachable(300)) { alive.add(ip); return }
            } catch (_: Exception) {
            }
        }
        for (port in probePorts) {
            try {
                Socket().use { it.connect(InetSocketAddress(ip, port), 200) }
                alive.add(ip); return
            } catch (e: ConnectException) {
                if (e.message?.contains("refused", ignoreCase = true) == true) {
                    alive.add(ip); return
                }
            } catch (_: SocketTimeoutException) {
            } catch (_: Exception) {
            }
        }
    }

    // --- SSDP / mDNS ---------------------------------------------------------

    private fun ssdpDiscover(found: MutableSet<String>) {
        try {
            DatagramSocket().use { s ->
                s.soTimeout = 800
                val msg = ("M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\n" +
                        "MAN: \"ssdp:discover\"\r\nMX: 2\r\nST: ssdp:all\r\n\r\n").toByteArray()
                s.send(
                    DatagramPacket(msg, msg.size, InetAddress.getByName("239.255.255.250"), 1900)
                )
                collectSenders(s, found, 4000)
            }
        } catch (_: Exception) {
        }
    }

    private fun mdnsDiscover(found: MutableSet<String>) {
        try {
            DatagramSocket().use { s ->
                s.soTimeout = 800
                // DNS query: PTR _services._dns-sd._udp.local (unicast-response bit set)
                val q = ByteArrayOutputStream()
                intArrayOf(0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0).forEach { q.write(it) } // header
                for (label in listOf("_services", "_dns-sd", "_udp", "local")) {
                    q.write(label.length)
                    q.write(label.toByteArray())
                }
                q.write(0)
                intArrayOf(0x00, 0x0C, 0x80, 0x01).forEach { q.write(it) } // PTR, IN | QU
                val data = q.toByteArray()
                s.send(DatagramPacket(data, data.size, InetAddress.getByName("224.0.0.251"), 5353))
                collectSenders(s, found, 4000)
            }
        } catch (_: Exception) {
        }
    }

    private fun collectSenders(s: DatagramSocket, out: MutableSet<String>, millis: Long) {
        val buf = ByteArray(2048)
        val end = System.currentTimeMillis() + millis
        while (System.currentTimeMillis() < end) {
            try {
                val p = DatagramPacket(buf, buf.size)
                s.receive(p)
                val addr = p.address
                if (addr is Inet4Address) addr.hostAddress?.let { out.add(it) }
            } catch (_: SocketTimeoutException) {
            }
        }
    }

    // --- ARP / names ---------------------------------------------------------

    /** Live ARP entries as ip -> mac. /proc/net/arp is restricted on some
     *  Android builds, so `ip neigh` is used as a fallback. */
    private fun arpTable(): Map<String, String> {
        val table = HashMap<String, String>()
        try {
            for (row in File("/proc/net/arp").readLines().drop(1)) {
                val parts = row.trim().split(Regex("\\s+"))
                if (parts.size < 6) continue
                val mac = parts[3].lowercase(Locale.US)
                // 0x0 flags / zeroed MAC mean a stale or incomplete entry.
                if (mac == "00:00:00:00:00:00" || parts[2] == "0x0") continue
                table[parts[0]] = mac
            }
        } catch (e: Exception) {
            // Restricted access — fall through to the alternative below.
        }
        if (table.isEmpty()) {
            try {
                val proc = Runtime.getRuntime().exec(arrayOf("/system/bin/ip", "neigh"))
                val lines = proc.inputStream.bufferedReader().readLines()
                proc.destroy()
                // "192.168.1.23 dev wlan0 lladdr aa:bb:cc:dd:ee:ff REACHABLE"
                for (line in lines) {
                    val parts = line.trim().split(Regex("\\s+"))
                    val lladdr = parts.indexOf("lladdr")
                    if (parts.isNotEmpty() && parts[0].contains(".") &&
                        parts[0].first().isDigit() && lladdr in 1 until parts.size - 1
                    ) {
                        table[parts[0]] = parts[lladdr + 1].lowercase(Locale.US)
                    }
                }
            } catch (e: Exception) {
                // No ARP data available on this device.
            }
        }
        return table
    }

    /** Reverse DNS (routers often resolve DHCP hostnames); 4s overall budget. */
    private fun resolveNames(ips: List<String>): Map<String, String?> {
        val pool = Executors.newFixedThreadPool(16)
        val futures = ips.associateWith { ip ->
            pool.submit(Callable<String?> {
                try {
                    val n = InetAddress.getByName(ip).canonicalHostName
                    if (n.isNullOrBlank() || n == ip) null else n
                } catch (_: Exception) {
                    null
                }
            })
        }
        val out = HashMap<String, String?>()
        val end = System.currentTimeMillis() + 4000
        for ((ip, f) in futures) {
            out[ip] = try {
                f.get(maxOf(1L, end - System.currentTimeMillis()), TimeUnit.MILLISECONDS)
            } catch (_: Exception) {
                null
            }
        }
        pool.shutdownNow()
        return out
    }

    // --- Helpers -------------------------------------------------------------

    private fun lastOctet(ip: String): Int = ip.substringAfterLast('.').toIntOrNull() ?: 0

    /** The phone's own IPv4 on the WiFi interface, or null when offline. */
    private fun localIPv4(): String? {
        return try {
            NetworkInterface.getNetworkInterfaces().asSequence()
                .filter { it.isUp && !it.isLoopback && !it.isVirtual }
                .flatMap { it.inetAddresses.asSequence() }
                .filterIsInstance<Inet4Address>()
                .firstOrNull { it.isSiteLocalAddress }
                ?.hostAddress
        } catch (e: Exception) {
            null
        }
    }

    /** Gateway IP from the DHCP lease, or the conventional x.x.x.1. */
    private fun currentGateway(self: String): String? {
        return try {
            @Suppress("DEPRECATION")
            val gw = wifiManager().dhcpInfo?.gateway ?: 0
            if (gw != 0 && gw != -1) intToIp(gw)
            else self.substringBeforeLast('.', "").takeIf { it.isNotEmpty() }?.let { "$it.1" }
        } catch (e: Exception) {
            null
        }
    }

    private fun intToIp(i: Int): String =
        String.format(
            Locale.US, "%d.%d.%d.%d",
            i and 0xff, i shr 8 and 0xff, i shr 16 and 0xff, i shr 24 and 0xff,
        )

    /** The phone's own WiFi MAC, if the OS still exposes it. */
    private fun selfMac(): String {
        return try {
            val self = localIPv4() ?: return ""
            val nif = NetworkInterface.getByInetAddress(InetAddress.getByName(self))
            nif?.hardwareAddress
                ?.joinToString(":") { String.format(Locale.US, "%02x", it) }
                ?: ""
        } catch (e: Exception) {
            ""
        }
    }
}
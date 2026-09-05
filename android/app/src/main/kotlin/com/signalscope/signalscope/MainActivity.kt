// Replace your existing MainActivity.kt with this file.
// KEEP the package line below matching YOUR project's existing package.
//
// Location: android/app/src/main/kotlin/<your/package/path>/MainActivity.kt

package com.signalscope.signalscope // <-- change to YOUR package name

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "signalscope/wifi"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
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
}
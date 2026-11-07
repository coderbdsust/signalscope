import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'wifi_reading.dart';

/// Reads RSSI via the native channel (see MainActivity.kt) and SSID via
/// network_info_plus.
class WifiService {
  static const _channel = MethodChannel('signalscope/wifi');
  final NetworkInfo _networkInfo = NetworkInfo();

  /// SSID lookup needs a location permission (and location services ON).
  Future<void> requestPermission() => Permission.locationWhenInUse.request();

  Future<WifiReading> read() async {
    int? rssi;
    String? ssid;
    try {
      rssi = await _channel.invokeMethod<int>('getRssi');
    } catch (_) {
      // Not on WiFi, or channel unavailable.
    }
    try {
      ssid = await _networkInfo.getWifiName();
    } catch (_) {
      // Location off / permission denied.
    }
    return WifiReading(rssi: rssi, ssid: _cleanSsid(ssid));
  }

  /// Emits a reading immediately, then every [interval].
  Stream<WifiReading> watch(
      {Duration interval = const Duration(seconds: 2)}) async* {
    await requestPermission();
    while (true) {
      yield await read();
      await Future<void>.delayed(interval);
    }
  }

  String? _cleanSsid(String? raw) {
    if (raw == null) return null;
    var s = raw;
    // network_info_plus often wraps the SSID in quotes on Android.
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1);
    }
    if (s.isEmpty || s.contains('unknown')) return null;
    return s;
  }
}

import 'package:flutter/services.dart';

import 'device_type.dart';
import 'lan_device.dart';
import 'oui_lookup.dart';

/// Local network scan through the native channel (see MainActivity.kt),
/// enriched on the Dart side with vendor + device type.
class LanService {
  static const _channel = MethodChannel('signalscope/lan');

  /// Throws on failure / timeout — callers show the error state.
  Future<LanScanResult> scan({
    Duration timeout = const Duration(seconds: 45),
  }) async {
    await OuiLookup.instance.ensureLoaded();

    final raw = await _channel
        .invokeMethod<Map<dynamic, dynamic>>('scanLanDevices')
        .timeout(timeout);

    final devices = ((raw?['devices'] as List?) ?? const [])
        .whereType<Map>()
        .map(LanDevice.fromMap)
        .where((d) => d.ip.isNotEmpty)
        .map(_enrich)
        .toList();

    return LanScanResult(
      devices: devices,
      gatewayIp: _validIp(raw?['gatewayIp'] as String?),
      selfIp: _validIp(raw?['selfIp'] as String?),
    );
  }

  LanDevice _enrich(LanDevice d) {
    final vendor = (d.hasMac && !d.isPrivateMac)
        ? OuiLookup.instance.vendorOf(d.mac)
        : null;
    final type = classifyDevice(
      isGateway: d.isGateway,
      isSelf: d.isSelf,
      isPrivateMac: d.isPrivateMac,
      hostname: d.hostname,
      vendor: vendor,
    );
    return d.copyWith(vendor: vendor, type: type);
  }

  String? _validIp(String? ip) {
    if (ip == null || ip.isEmpty || ip == '0.0.0.0') return null;
    return ip;
  }
}

import 'package:flutter/material.dart';

import 'device_type.dart';

class LanDevice {
  final String ip;
  final String mac; // normalized "AA:BB:CC:DD:EE:FF" or '' if unavailable
  final String? hostname;
  final String? vendor;
  final DeviceType type;
  final bool isGateway;
  final bool isSelf;

  const LanDevice({
    required this.ip,
    required this.mac,
    this.hostname,
    this.vendor,
    this.type = DeviceType.unknown,
    this.isGateway = false,
    this.isSelf = false,
  });

  factory LanDevice.fromMap(Map<dynamic, dynamic> map) {
    final role = map['role'] as String?;
    final host = (map['hostname'] as String?)?.trim();
    final ip = (map['ip'] as String?) ?? '';
    return LanDevice(
      ip: ip,
      mac: normalizeMac(map['mac'] as String?),
      // Reverse DNS often just echoes the IP back; treat that as "no name".
      hostname: (host == null || host.isEmpty || host == ip) ? null : host,
      isGateway: role == 'gateway',
      isSelf: role == 'self',
    );
  }

  LanDevice copyWith({String? vendor, DeviceType? type}) => LanDevice(
        ip: ip,
        mac: mac,
        hostname: hostname,
        vendor: vendor ?? this.vendor,
        type: type ?? this.type,
        isGateway: isGateway,
        isSelf: isSelf,
      );

  bool get hasMac => mac.isNotEmpty;

  /// Locally-administered bit set => randomized/private MAC (no real vendor).
  bool get isPrivateMac {
    if (!hasMac) return false;
    final first = int.tryParse(mac.substring(0, 2), radix: 16);
    return first != null && (first & 0x02) != 0;
  }

  /// Best human-readable name for the row title.
  String get displayName {
    if (isSelf) return hostname ?? 'This device';
    if (hostname != null) return hostname!;
    if (isGateway) return 'Router';
    if (vendor != null) return vendor!;
    return type.label;
  }

  IconData get icon => type.icon;

  static String normalizeMac(String? raw) {
    if (raw == null) return '';
    final hex = raw.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
    if (hex.length != 12 || hex == '000000000000' || hex == '020000000000') {
      return ''; // Android hides real MACs (e.g. 02:00:00:00:00:00)
    }
    return [for (var i = 0; i < 12; i += 2) hex.substring(i, i + 2)].join(':');
  }
}

class LanScanResult {
  final List<LanDevice> devices;
  final String? gatewayIp;
  final String? selfIp;
  const LanScanResult({
    this.devices = const [],
    this.gatewayIp,
    this.selfIp,
  });
}

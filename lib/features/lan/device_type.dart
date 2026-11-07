import 'package:flutter/material.dart';

enum DeviceType {
  router('Router', Icons.router_rounded),
  phone('Phone / Tablet', Icons.smartphone_rounded),
  computer('Computer', Icons.laptop_mac_rounded),
  tv('TV / Streaming', Icons.tv_rounded),
  speaker('Smart speaker', Icons.speaker_rounded),
  camera('Camera', Icons.videocam_rounded),
  printer('Printer', Icons.print_rounded),
  console('Game console', Icons.sports_esports_rounded),
  iot('IoT / Smart home', Icons.sensors_rounded),
  unknown('Unknown device', Icons.devices_other_rounded);

  final String label;
  final IconData icon;
  const DeviceType(this.label, this.icon);
}

/// Best-effort guess. Android can't tell us what a device really is, so we
/// combine: role -> hostname -> MAC vendor -> randomized-MAC heuristic.
DeviceType classifyDevice({
  required bool isGateway,
  required bool isSelf,
  required bool isPrivateMac,
  String? hostname,
  String? vendor,
}) {
  if (isGateway) return DeviceType.router;
  if (isSelf) return DeviceType.phone;

  final h = (hostname ?? '').toLowerCase();
  if (h.isNotEmpty) {
    final byHost = _match(h, _hostRules);
    if (byHost != null) return byHost;
  }

  final v = (vendor ?? '').toLowerCase();
  if (v.isNotEmpty) {
    final byVendor = _match(v, _vendorRules);
    if (byVendor != null) return byVendor;
  }

  // Randomized ("private") MACs are what modern phones/tablets use per network.
  if (isPrivateMac) return DeviceType.phone;
  return DeviceType.unknown;
}

DeviceType? _match(String text, Map<DeviceType, List<String>> rules) {
  for (final e in rules.entries) {
    for (final k in e.value) {
      if (text.contains(k)) return e.key;
    }
  }
  return null;
}

const _hostRules = <DeviceType, List<String>>{
  DeviceType.phone: ['iphone', 'ipad', 'android', 'galaxy', 'pixel', 'redmi', 'oneplus', 'huawei'],
  DeviceType.computer: ['macbook', 'imac', 'laptop', 'desktop', 'pc-', '-pc', 'thinkpad', 'ubuntu', 'windows'],
  DeviceType.tv: ['tv', 'chromecast', 'roku', 'firetv', 'appletv', 'bravia'],
  DeviceType.speaker: ['echo', 'alexa', 'homepod', 'sonos', 'nest-mini', 'google-home'],
  DeviceType.printer: ['printer', 'laserjet', 'officejet', 'epson', 'brother'],
  DeviceType.camera: ['cam', 'ipcam', 'hikvision', 'dahua'],
  DeviceType.console: ['playstation', 'ps4', 'ps5', 'xbox', 'nintendo', 'switch'],
};

// Vendor-only matches are weaker (e.g. Samsung also makes TVs), so the UI
// should treat them as hints.
const _vendorRules = <DeviceType, List<String>>{
  DeviceType.router: [
    'tp-link', 'tplink', 'netgear', 'd-link', 'zyxel', 'ubiquiti', 'mikrotik',
    'tenda', 'linksys', 'cisco', 'arris', 'technicolor', 'sagemcom', 'ruijie',
  ],
  DeviceType.printer: ['canon', 'epson', 'brother', 'xerox', 'lexmark', 'ricoh', 'kyocera'],
  DeviceType.camera: ['hikvision', 'dahua', 'axis comm', 'reolink', 'ezviz', 'wyze', 'arlo'],
  DeviceType.console: ['nintendo', 'sony interactive'],
  DeviceType.speaker: ['sonos', 'bose'],
  DeviceType.tv: ['roku', 'hisense', 'tcl', 'vizio', 'skyworth', 'lg electronics'],
  DeviceType.iot: ['espressif', 'tuya', 'shelly', 'sonoff', 'itead'],
  DeviceType.computer: ['intel', 'dell', 'lenovo', 'micro-star', 'gigabyte', 'raspberry', 'asustek'],
  DeviceType.phone: [
    'apple', 'samsung', 'xiaomi', 'oneplus', 'oppo', 'vivo', 'realme',
    'motorola', 'huawei', 'honor', 'google', 'nothing tech',
  ],
};

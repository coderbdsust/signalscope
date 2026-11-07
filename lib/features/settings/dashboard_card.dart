import 'package:flutter/material.dart';

/// The dashboard cards that can be switched on/off.
enum DashboardCardId {
  wifi('WiFi Signal', 'Signal strength and network name', Icons.wifi_rounded),
  noise('Sound Level', 'Ambient loudness (uses the microphone)',
      Icons.graphic_eq_rounded),
  lan('Local Devices', 'Devices on your network (runs a scan)',
      Icons.lan_rounded);

  final String label;
  final String description;
  final IconData icon;
  const DashboardCardId(this.label, this.description, this.icon);

  String get prefKey => 'card_enabled_$name';
}

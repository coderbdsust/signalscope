import 'package:flutter/material.dart';

import '../../core/widgets/gauge_card.dart';
import 'wifi_reading.dart';
import 'wifi_status.dart';

class WifiCard extends StatelessWidget {
  final WifiReading reading;
  const WifiCard({super.key, required this.reading});

  String get _networkLabel {
    if (reading.ssid != null) return reading.ssid!;
    if (reading.isConnected) return 'Connected'; // name hidden by location
    return 'Not connected';
  }

  @override
  Widget build(BuildContext context) {
    final rssi = reading.rssi;
    final status = wifiStatus(rssi);

    return GaugeCard(
      icon: Icons.wifi_rounded,
      title: 'WiFi Signal',
      progress: reading.quality,
      centerValue: rssi == null ? '--' : '$rssi',
      unit: 'dBm',
      statusLabel: status.$1,
      color: status.$2,
      details: [
        ('Network', _networkLabel),
        ('Quality', rssi == null ? '--' : '${(reading.quality * 100).round()}%'),
      ],
    );
  }
}

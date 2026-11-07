import 'package:flutter/material.dart';

import '../../core/widgets/gauge_card.dart';
import '../../core/widgets/permission_card.dart';
import 'noise_status.dart';

class NoiseCard extends StatelessWidget {
  final double? db;
  final double? maxDb;
  final bool micGranted;
  final VoidCallback onRequestPermission;

  const NoiseCard({
    super.key,
    required this.db,
    required this.maxDb,
    required this.micGranted,
    required this.onRequestPermission,
  });

  @override
  Widget build(BuildContext context) {
    if (!micGranted) {
      return PermissionCard(
        icon: Icons.mic_off_rounded,
        title: 'Sound Level',
        message: 'Microphone permission is needed to measure ambient noise.',
        onRetry: onRequestPermission,
      );
    }

    final value = db;
    final status = noiseStatus(value);

    return GaugeCard(
      icon: Icons.graphic_eq_rounded,
      title: 'Sound Level',
      progress: value == null ? 0.0 : (value / 100).clamp(0.0, 1.0),
      centerValue: value == null ? '--' : value.toStringAsFixed(0),
      unit: 'dB',
      statusLabel: status.$1,
      color: status.$2,
      details: [
        ('Peak', maxDb == null ? '--' : '${maxDb!.toStringAsFixed(0)} dB'),
        ('Mode', 'Live'),
      ],
    );
  }
}

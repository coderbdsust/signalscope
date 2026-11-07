import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_card.dart';
import 'detail_tile.dart';
import 'gauge_painter.dart';

class GaugeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final double progress; // 0..1
  final String centerValue;
  final String unit;
  final String statusLabel;
  final Color color;
  final List<(String, String)> details;

  const GaugeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.progress,
    required this.centerValue,
    required this.unit,
    required this.statusLabel,
    required this.color,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: CardTitle(icon: icon, title: title, color: color),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            width: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => CustomPaint(
                    size: const Size(220, 220),
                    painter: GaugePainter(progress: v, color: color),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      centerValue,
                      style: const TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unit,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textDim),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < details.length; i++) ...[
                Expanded(child: DetailTile(details[i].$1, details[i].$2)),
                if (i != details.length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

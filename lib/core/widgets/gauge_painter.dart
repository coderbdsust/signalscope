import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class GaugePainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;

  GaugePainter({required this.progress, required this.color});

  static const double _start = math.pi * 0.75; // 135°
  static const double _sweep = math.pi * 1.5; // 270°
  static const double _stroke = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - _stroke;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    canvas.drawArc(
      rect,
      _start,
      _sweep,
      false,
      Paint()
        ..color = AppColors.track
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round,
    );

    final p = progress.clamp(0.0, 1.0);
    if (p <= 0.001) return;

    // Value arc with a gradient that follows the sweep
    final valuePaint = Paint()
      ..shader = SweepGradient(
        startAngle: _start,
        endAngle: _start + _sweep,
        colors: [color.withOpacity(0.30), color],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _start, _sweep * p, false, valuePaint);

    // Glowing tip
    final tipAngle = _start + _sweep * p;
    final tip = Offset(
      center.dx + radius * math.cos(tipAngle),
      center.dy + radius * math.sin(tipAngle),
    );
    canvas.drawCircle(
      tip,
      9,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(tip, 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant GaugePainter old) =>
      old.progress != progress || old.color != color;
}

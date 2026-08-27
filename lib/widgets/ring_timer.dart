import 'package:flutter/material.dart';

class RingTimerPainter extends CustomPainter {
  final double fraction; // 1.0 = full, 0.0 = empty
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  RingTimerPainter({
    required this.fraction,
    required this.trackColor,
    required this.progressColor,
    this.strokeWidth = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, track);

    final progress = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweep = 2 * 3.1415926535 * fraction.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.1415926535 / 2,
      sweep,
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(covariant RingTimerPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.progressColor != progressColor;
}

import 'dart:math';
import 'package:flutter/material.dart';

class CyberStar extends StatelessWidget {
  final bool isLit;
  final Color color;
  final double size;
  final bool isDiamond;

  const CyberStar({
    super.key,
    required this.isLit,
    required this.color,
    this.size = 24.0,
    this.isDiamond = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: CyberStarPainter(
          isLit: isLit,
          color: color,
          isDiamond: isDiamond,
        ),
      ),
    );
  }
}

class CyberStarPainter extends CustomPainter {
  final bool isLit;
  final Color color;
  final bool isDiamond;

  CyberStarPainter({
    required this.isLit,
    required this.color,
    required this.isDiamond,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    if (isDiamond) {
      // Rotated square/diamond
      path.moveTo(cx, 0);
      path.lineTo(w, cy);
      path.lineTo(cx, h);
      path.lineTo(0, cy);
      path.close();
    } else {
      // 5-pointed cyber star (sharp angles, no rounded curves)
      final double outerRadius = w / 2;
      final double innerRadius = outerRadius * 0.42;
      final double step = pi / 5;

      path.moveTo(cx, cy - outerRadius);
      for (int i = 1; i < 10; i++) {
        final double r = i.isOdd ? innerRadius : outerRadius;
        final double angle = -pi / 2 + i * step;
        path.lineTo(cx + r * cos(angle), cy + r * sin(angle));
      }
      path.close();
    }

    if (isLit) {
      // 1. Draw glowing background fill
      final fillPaint = Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      // 2. Draw crisp outer neon stroke
      final borderPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, borderPaint);

      // 3. Draw a smaller inner star/diamond (cyber core)
      final innerPath = Path();
      if (isDiamond) {
        final double scale = 0.4;
        innerPath.moveTo(cx, cy - h / 2 * scale);
        innerPath.lineTo(cx + w / 2 * scale, cy);
        innerPath.lineTo(cx, cy + h / 2 * scale);
        innerPath.lineTo(cx - w / 2 * scale, cy);
        innerPath.close();
      } else {
        final double outerRadiusInner = w / 2 * 0.45;
        final double innerRadiusInner = outerRadiusInner * 0.42;
        final double step = pi / 5;

        innerPath.moveTo(cx, cy - outerRadiusInner);
        for (int i = 1; i < 10; i++) {
          final double r = i.isOdd ? innerRadiusInner : outerRadiusInner;
          final double angle = -pi / 2 + i * step;
          innerPath.lineTo(cx + r * cos(angle), cy + r * sin(angle));
        }
        innerPath.close();
      }

      final innerPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawPath(innerPath, innerPaint);
    } else {
      // Dimmed empty outline to represent unachieved star
      final borderPaint = Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CyberStarPainter oldDelegate) {
    return oldDelegate.isLit != isLit ||
        oldDelegate.color != color ||
        oldDelegate.isDiamond != isDiamond;
  }
}

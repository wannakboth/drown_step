import 'package:flutter/material.dart';

class CockpitTabPainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;

  const CockpitTabPainter({
    required this.backgroundColor,
    required this.borderColor,
    this.borderWidth = 1.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const slant = 14.0;
    const radius = 8.0;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(slant - 2, size.height - radius);
    path.quadraticBezierTo(slant, size.height, slant + radius, size.height);
    path.lineTo(size.width - slant - radius, size.height);
    path.quadraticBezierTo(
      size.width - slant,
      size.height,
      size.width - slant + 2,
      size.height - radius,
    );
    path.lineTo(size.width, 0);
    path.close();

    // Paint background
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, bgPaint);

    // Paint border (only left, bottom, right; not the top edge)
    final borderPath = Path();
    borderPath.moveTo(0, 0);
    borderPath.lineTo(slant - 2, size.height - radius);
    borderPath.quadraticBezierTo(
      slant,
      size.height,
      slant + radius,
      size.height,
    );
    borderPath.lineTo(size.width - slant - radius, size.height);
    borderPath.quadraticBezierTo(
      size.width - slant,
      size.height,
      size.width - slant + 2,
      size.height - radius,
    );
    borderPath.lineTo(size.width, 0);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    borderPaint.strokeWidth = borderWidth;
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CockpitTabPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth;
  }
}

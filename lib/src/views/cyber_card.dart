import 'package:flutter/material.dart';

class CyberCard extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final Color backgroundColor;
  final double borderWidth;
  final double chamferSize;
  final List<BoxShadow>? shadows;
  final bool showAccents;

  const CyberCard({
    super.key,
    required this.child,
    required this.borderColor,
    this.backgroundColor = const Color(0xFF0E101A),
    this.borderWidth = 1.0,
    this.chamferSize = 8.0,
    this.shadows,
    this.showAccents = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CyberCardPainter(
        borderColor: borderColor,
        backgroundColor: backgroundColor,
        borderWidth: borderWidth,
        chamferSize: chamferSize,
        shadows: shadows,
        showAccents: showAccents,
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.0),
        child: child,
      ),
    );
  }
}

class CyberCardPainter extends CustomPainter {
  final Color borderColor;
  final Color backgroundColor;
  final double borderWidth;
  final double chamferSize;
  final List<BoxShadow>? shadows;
  final bool showAccents;

  CyberCardPainter({
    required this.borderColor,
    required this.backgroundColor,
    this.borderWidth = 1.0,
    this.chamferSize = 8.0,
    this.shadows,
    this.showAccents = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final half = borderWidth / 2.0;
    final left = half;
    final top = half;
    final right = w - half;
    final bottom = h - half;
    final c = chamferSize;

    // Build the outer path inset by half the border width to prevent edge clipping and ensure smooth anti-aliased rendering.
    final path = Path()
      ..moveTo(left + c, top)
      ..lineTo(right - 4.0, top)
      ..quadraticBezierTo(right, top, right, top + 4.0)
      ..lineTo(right, bottom - c)
      ..lineTo(right - c, bottom)
      ..lineTo(left + 4.0, bottom)
      ..quadraticBezierTo(left, bottom, left, bottom - 4.0)
      ..lineTo(left, top + c)
      ..close();

    // Paint shadows
    if (shadows != null) {
      for (final shadow in shadows!) {
        final shadowPaint = Paint()
          ..color = shadow.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurRadius)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;
        
        canvas.save();
        canvas.translate(shadow.offset.dx, shadow.offset.dy);
        canvas.drawPath(path, shadowPaint);
        canvas.restore();
      }
    }

    // Paint background
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(path, bgPaint);

    // Paint main border stroke
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.drawPath(path, borderPaint);

    if (showAccents && w > 20 && h > 20) {
      final accentPaint = Paint()
        ..color = borderColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      // Small parallel line on the bottom-right chamfer
      final brAccent = Path()
        ..moveTo(right - c + 3.0, bottom - 3.0)
        ..lineTo(right - 3.0, bottom - c + 3.0);
      canvas.drawPath(brAccent, accentPaint);

      // Small parallel line on the top-left chamfer
      final tlAccent = Path()
        ..moveTo(left + 3.0, top + c - 3.0)
        ..lineTo(left + c - 3.0, top + 3.0);
      canvas.drawPath(tlAccent, accentPaint);

      // A small glowing corner tick mark at the top-right
      final trTick = Path()
        ..moveTo(right - 10.0, top + 3.0)
        ..lineTo(right - 3.0, top + 3.0)
        ..lineTo(right - 3.0, top + 10.0);
      canvas.drawPath(trTick, accentPaint);

      // A small glowing tick at the bottom-left
      final blTick = Path()
        ..moveTo(left + 3.0, bottom - 10.0)
        ..lineTo(left + 3.0, bottom - 3.0)
        ..lineTo(left + 10.0, bottom - 3.0);
      canvas.drawPath(blTick, accentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CyberCardPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.chamferSize != chamferSize ||
        oldDelegate.showAccents != showAccents;
  }
}

class CyberCardClipper extends CustomClipper<Path> {
  final double chamferSize;
  final double borderWidth;

  CyberCardClipper({this.chamferSize = 8.0, this.borderWidth = 1.0});

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final half = borderWidth / 2.0;
    final left = half;
    final top = half;
    final right = w - half;
    final bottom = h - half;
    final c = chamferSize;

    return Path()
      ..moveTo(left + c, top)
      ..lineTo(right - 4.0, top)
      ..quadraticBezierTo(right, top, right, top + 4.0)
      ..lineTo(right, bottom - c)
      ..lineTo(right - c, bottom)
      ..lineTo(left + 4.0, bottom)
      ..quadraticBezierTo(left, bottom, left, bottom - 4.0)
      ..lineTo(left, top + c)
      ..close();
  }

  @override
  bool shouldReclip(covariant CyberCardClipper oldClipper) {
    return oldClipper.chamferSize != chamferSize ||
        oldClipper.borderWidth != borderWidth;
  }
}


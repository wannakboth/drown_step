import 'dart:math' as math;
import 'package:flutter/material.dart';

class CyberArrowButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLeft;
  final Color color;
  final double width;
  final double height;

  const CyberArrowButton({
    super.key,
    required this.onPressed,
    required this.isLeft,
    required this.color,
    this.width = 36.0,
    this.height = 68.0,
  });

  @override
  State<CyberArrowButton> createState() => _CyberArrowButtonState();
}

class _CyberArrowButtonState extends State<CyberArrowButton>
    with TickerProviderStateMixin {
  late final AnimationController _hoverController;
  late final AnimationController _pressController;
  late final AnimationController _flashController;
  late final AnimationController _idleController;

  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
      lowerBound: 0.9,
      upperBound: 1.0,
      value: 1.0,
    );
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _idleController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _idleController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _pressController.dispose();
    _flashController.dispose();
    _idleController.dispose();
    super.dispose();
  }

  void _handleHover(bool hovered) {
    if (_isHovered == hovered) return;
    setState(() {
      _isHovered = hovered;
    });
    if (hovered) {
      _hoverController.forward();
    } else {
      _hoverController.reverse();
    }
  }

  void _handleTapDown(TapDownDetails details) {
    _pressController.animateTo(0.9, curve: Curves.easeOut);
  }

  void _handleTapUp(TapUpDetails details) {
    _pressController.animateTo(1.0, curve: Curves.easeOut);
  }

  void _handleTapCancel() {
    _pressController.animateTo(1.0, curve: Curves.easeOut);
  }

  void _handleTap() {
    _flashController.forward(from: 0.0);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: _handleTap,
        child: ScaleTransition(
          scale: _pressController,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _hoverController,
              _flashController,
              _idleController,
            ]),
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.width, widget.height),
                painter: _CyberArrowPainter(
                  isLeft: widget.isLeft,
                  color: widget.color,
                  hoverVal: _hoverController.value,
                  flashVal: _flashController.value,
                  idleVal: _idleController.value,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CyberArrowPainter extends CustomPainter {
  final bool isLeft;
  final Color color;
  final double hoverVal;
  final double flashVal;
  final double idleVal;

  _CyberArrowPainter({
    required this.isLeft,
    required this.color,
    required this.hoverVal,
    required this.flashVal,
    required this.idleVal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final borderWidth = 1.5;
    final half = borderWidth / 2.0;

    final left = half;
    final top = half;
    final right = w - half;
    final bottom = h - half;

    // We'll use 12.0 for the main pointer chamfer
    final c = 12.0;

    // Define the outer path
    final path = Path();
    if (!isLeft) {
      // Right pointing wedge: chiseled back edge, points to center-right
      path.moveTo(left, top + 4.0);
      path.lineTo(left + 4.0, top);
      path.lineTo(right - c, top);
      path.lineTo(right, h / 2.0);
      path.lineTo(right - c, bottom);
      path.lineTo(left + 4.0, bottom);
      path.lineTo(left, bottom - 4.0);
      path.close();
    } else {
      // Left pointing wedge: points to center-left, chiseled back edge
      path.moveTo(right, top + 4.0);
      path.lineTo(right - 4.0, top);
      path.lineTo(left + c, top);
      path.lineTo(left, h / 2.0);
      path.lineTo(left + c, bottom);
      path.lineTo(right - 4.0, bottom);
      path.lineTo(right, bottom - 4.0);
      path.close();
    }

    // 1. Neon Glow Shadow (pulses when idle, gets strong on hover)
    final double baseGlow = 0.12 + 0.06 * idleVal;
    final double maxGlow = 0.38;
    final double glowOpacity = ((baseGlow * (1.0 - hoverVal)) + (maxGlow * hoverVal)) * (1.0 - flashVal);

    final double baseRadius = 5.0 + 3.0 * idleVal;
    final double maxRadius = 14.0;
    final double glowRadius = (baseRadius * (1.0 - hoverVal)) + (maxRadius * hoverVal);

    if (glowOpacity > 0.0) {
      final shadowPaint = Paint()
        ..color = color.withValues(alpha: glowOpacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      canvas.drawPath(path, shadowPaint);
    }

    // 2. Background Fill (with hover and tap-flash interpolation)
    final bgOpacity = 0.08 + 0.12 * hoverVal;
    Color bgColor = color.withValues(alpha: bgOpacity);
    if (flashVal > 0.0) {
      // Linear ease-out for flash
      final double flashCurve = math.pow(1.0 - flashVal, 3.0).toDouble(); // fast fade
      final double flashIntensity = 1.0 - flashCurve;
      bgColor = Color.lerp(bgColor, Colors.white.withValues(alpha: 0.5), flashIntensity)!;
    }

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(path, bgPaint);

    // 3. Border Stroke (lerp with white during flash)
    Color borderColor = color;
    if (flashVal > 0.0) {
      final double flashIntensity = math.pow(1.0 - flashVal, 2.0).toDouble();
      borderColor = Color.lerp(color, Colors.white, 1.0 - flashIntensity)!;
    }

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.drawPath(path, borderPaint);

    // 4. Inner Chevrons with shift animation (constant gentle shifting, locks forward on hover)
    final double baseShift = idleVal * 3.5;
    final double targetShift = 5.5;
    final double shift = (baseShift * (1.0 - hoverVal)) + (targetShift * hoverVal);

    final chevronPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.4 + 0.4 * hoverVal)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final chevronPath = Path();
    if (!isLeft) {
      // First chevron
      final c1x = left + w * 0.28 + shift;
      chevronPath.moveTo(c1x, top + h * 0.32);
      chevronPath.lineTo(c1x + w * 0.22, h / 2.0);
      chevronPath.lineTo(c1x, bottom - h * 0.32);

      // Second chevron
      final c2x = left + w * 0.46 + shift;
      chevronPath.moveTo(c2x, top + h * 0.32);
      chevronPath.lineTo(c2x + w * 0.22, h / 2.0);
      chevronPath.lineTo(c2x, bottom - h * 0.32);
    } else {
      // First chevron (pointing left)
      final c1x = right - w * 0.28 - shift;
      chevronPath.moveTo(c1x, top + h * 0.32);
      chevronPath.lineTo(c1x - w * 0.22, h / 2.0);
      chevronPath.lineTo(c1x, bottom - h * 0.32);

      // Second chevron
      final c2x = right - w * 0.46 - shift;
      chevronPath.moveTo(c2x, top + h * 0.32);
      chevronPath.lineTo(c2x - w * 0.22, h / 2.0);
      chevronPath.lineTo(c2x, bottom - h * 0.32);
    }
    canvas.drawPath(chevronPath, chevronPaint);

    // 5. Tech Accent: Parallel ticks on flat back edges
    final accentPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.3 + 0.4 * hoverVal)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    if (!isLeft) {
      // Vertical line on left side inside the border
      canvas.drawLine(
        Offset(left + 3.0, top + 8.0),
        Offset(left + 3.0, bottom - 8.0),
        accentPaint,
      );
    } else {
      // Vertical line on right side inside the border
      canvas.drawLine(
        Offset(right - 3.0, top + 8.0),
        Offset(right - 3.0, bottom - 8.0),
        accentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CyberArrowPainter oldDelegate) {
    return oldDelegate.isLeft != isLeft ||
        oldDelegate.color != color ||
        oldDelegate.hoverVal != hoverVal ||
        oldDelegate.flashVal != flashVal ||
        oldDelegate.idleVal != idleVal;
  }
}

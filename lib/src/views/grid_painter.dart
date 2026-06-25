import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/level.dart';
import '../theme/colors.dart';
import '../providers/game_state.dart';
class GameGridPainter extends CustomPainter {
  final Level level;
  final int droneX;
  final int droneY;
  final int droneHeight;
  final List<EnergyCell> remainingEnergyCells;
  final List<Offset> pathHistory;
  final double animationValue; // For pulsing and spinning animations
  final bool hasCargo; // Determines if cargo is still on grid or picked up
  final GameStatus status;

  GameGridPainter({
    required this.level,
    required this.droneX,
    required this.droneY,
    required this.droneHeight,
    required this.remainingEnergyCells,
    required this.pathHistory,
    required this.animationValue,
    required this.hasCargo,
    required this.status,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / level.gridWidth;
    final cellHeight = size.height / level.gridHeight;

    // 1. Draw Grid Background (transparent to allow 3D Land Base and Radar Sweeper to show through)
    final bgPaint = Paint()..color = Colors.transparent;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Draw architectural grid lines
    final linePaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.25)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= level.gridWidth; i++) {
      final x = i * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (int j = 0; j <= level.gridHeight; j++) {
      final y = j * cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Draw intersection micro-dots
    final dotPaint = Paint()
      ..color = CyberTheme.neonCyan.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    for (int i = 1; i < level.gridWidth; i++) {
      for (int j = 1; j < level.gridHeight; j++) {
        canvas.drawCircle(Offset(i * cellWidth, j * cellHeight), 1.5, dotPaint);
      }
    }

    // 2. Draw flight path history (Trail)
    if (pathHistory.length > 1) {
      final trailPaint = Paint()
        ..color = CyberTheme.neonCyan.withValues(alpha: 0.5)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final trailPath = Path();
      final startOffset = Offset(
        (pathHistory.first.dx + 0.5) * cellWidth,
        (pathHistory.first.dy + 0.5) * cellHeight,
      );
      trailPath.moveTo(startOffset.dx, startOffset.dy);

      for (int i = 1; i < pathHistory.length; i++) {
        final pt = pathHistory[i];
        trailPath.lineTo(
          (pt.dx + 0.5) * cellWidth,
          (pt.dy + 0.5) * cellHeight,
        );
      }

      // Glowing trail background blur
      canvas.drawPath(
        trailPath,
        Paint()
          ..color = CyberTheme.neonCyan.withValues(alpha: 0.1)
          ..strokeWidth = 5.0
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
      );
      canvas.drawPath(trailPath, trailPaint);
    }

    // 3. Draw Dotted Guidance Lines (Drone -> Cargo -> Target Pad)
    final droneCenter = Offset((droneX + 0.5) * cellWidth, (droneY + 0.5) * cellHeight);
    final cargoCenter = Offset((level.boxX + 0.5) * cellWidth, (level.boxY + 0.5) * cellHeight);
    final targetCenter = Offset((level.targetX + 0.5) * cellWidth, (level.targetY + 0.5) * cellHeight);

    // Dotted guide line paint
    final guidePaint = Paint()
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    if (!hasCargo) {
      // Guide from Drone to Cargo (Yellow search path)
      guidePaint.color = CyberTheme.neonYellow.withValues(alpha: 0.35);
      _drawDottedLine(canvas, droneCenter, cargoCenter, guidePaint, 6.0, 4.0);

      // Guide from Cargo to Target Pad (Green target path)
      guidePaint.color = CyberTheme.neonGreen.withValues(alpha: 0.2);
      _drawDottedLine(canvas, cargoCenter, targetCenter, guidePaint, 6.0, 4.0);
    } else {
      // Guide from Drone straight to Target Pad (Cyan path)
      guidePaint.color = CyberTheme.neonCyan.withValues(alpha: 0.35);
      _drawDottedLine(canvas, droneCenter, targetCenter, guidePaint, 6.0, 4.0);
    }

    // Landing Zone target pad, obstacles, and energy cells are now drawn as animated 3D widgets in the parent stack.

    // 5. Draw Crash / Wrong Landing Highlight
    if (status == GameStatus.crashed) {
      final crashRect = Rect.fromLTWH(
        droneX * cellWidth + 4.0,
        droneY * cellHeight + 4.0,
        cellWidth - 8.0,
        cellHeight - 8.0,
      );
      final crashRRect = RRect.fromRectAndRadius(crashRect, const Radius.circular(8.0));
      
      final pulse = 0.6 + 0.4 * math.sin(animationValue * 2 * math.pi);
      
      canvas.drawRRect(
        crashRRect,
        Paint()
          ..color = Colors.red.withValues(alpha: 0.15 * pulse)
          ..style = PaintingStyle.fill,
      );
      
      canvas.drawRRect(
        crashRRect,
        Paint()
          ..color = Colors.redAccent
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke,
      );

      final center = Offset((droneX + 0.5) * cellWidth, (droneY + 0.5) * cellHeight);
      final offset = math.min(cellWidth, cellHeight) * 0.22;
      final crossPaint = Paint()
        ..color = Colors.redAccent
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(
        Offset(center.dx - offset, center.dy - offset),
        Offset(center.dx + offset, center.dy + offset),
        crossPaint,
      );
      canvas.drawLine(
        Offset(center.dx + offset, center.dy - offset),
        Offset(center.dx - offset, center.dy + offset),
        crossPaint,
      );
    }


    // Obstacles and energy cells are drawn as volumetric stack widgets in game_screen.dart.
  }

  // Helper method to draw a customized dotted line
  void _drawDottedLine(Canvas canvas, Offset start, Offset end, Paint paint, double dashLength, double gapLength) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    
    final int count = (distance / (dashLength + gapLength)).floor();
    
    for (int i = 0; i < count; i++) {
      final double progress = i / count;
      final double nextProgress = (i + (dashLength / (dashLength + gapLength))) / count;
      
      final currentStart = Offset(start.dx + dx * progress, start.dy + dy * progress);
      final currentEnd = Offset(start.dx + dx * nextProgress, start.dy + dy * nextProgress);
      
      canvas.drawLine(currentStart, currentEnd, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GameGridPainter oldDelegate) {
    return oldDelegate.droneX != droneX ||
        oldDelegate.droneY != droneY ||
        oldDelegate.droneHeight != droneHeight ||
        oldDelegate.remainingEnergyCells.length != remainingEnergyCells.length ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.hasCargo != hasCargo ||
        oldDelegate.pathHistory.length != pathHistory.length;
  }
}

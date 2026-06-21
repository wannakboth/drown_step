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

    // 1. Draw Grid Background
    final bgPaint = Paint()..color = CyberTheme.gridBg;
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

    // 4. Draw Landing Zone (Target Pad)
    final padRadius = math.min(cellWidth, cellHeight) * 0.38;
    final pulseScale = 1.0 + 0.08 * math.sin(animationValue * 2 * math.pi);

    final padGlowPaint = Paint()
      ..color = status == GameStatus.success
          ? CyberTheme.neonGreen.withValues(alpha: 0.25)
          : CyberTheme.neonGreen.withValues(alpha: 0.06 * (2.0 - pulseScale))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(targetCenter, padRadius * (status == GameStatus.success ? 1.0 : pulseScale), padGlowPaint);

    final ringPaint = Paint()
      ..color = status == GameStatus.success
          ? CyberTheme.neonGreen
          : CyberTheme.neonGreen.withValues(alpha: 0.75)
      ..strokeWidth = status == GameStatus.success ? 2.5 : 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(targetCenter, padRadius, ringPaint);

    // Draw corner brackets
    final bracketLength = padRadius * 0.35;
    final bracketOffset = padRadius * 0.75;
    final bracketPaint = Paint()
      ..color = status == GameStatus.success ? CyberTheme.neonGreen : CyberTheme.neonGreen.withValues(alpha: 0.8)
      ..strokeWidth = status == GameStatus.success ? 2.5 : 1.8
      ..style = PaintingStyle.stroke;

    canvas.drawPath(
      Path()
        ..moveTo(targetCenter.dx - bracketOffset, targetCenter.dy - bracketOffset + bracketLength)
        ..lineTo(targetCenter.dx - bracketOffset, targetCenter.dy - bracketOffset)
        ..lineTo(targetCenter.dx - bracketOffset + bracketLength, targetCenter.dy - bracketOffset),
      bracketPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(targetCenter.dx + bracketOffset - bracketLength, targetCenter.dy - bracketOffset)
        ..lineTo(targetCenter.dx + bracketOffset, targetCenter.dy - bracketOffset)
        ..lineTo(targetCenter.dx + bracketOffset, targetCenter.dy - bracketOffset + bracketLength),
      bracketPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(targetCenter.dx - bracketOffset, targetCenter.dy + bracketOffset - bracketLength)
        ..lineTo(targetCenter.dx - bracketOffset, targetCenter.dy + bracketOffset)
        ..lineTo(targetCenter.dx - bracketOffset + bracketLength, targetCenter.dy + bracketOffset),
      bracketPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(targetCenter.dx + bracketOffset - bracketLength, targetCenter.dy + bracketOffset)
        ..lineTo(targetCenter.dx + bracketOffset, targetCenter.dy + bracketOffset)
        ..lineTo(targetCenter.dx + bracketOffset, targetCenter.dy + bracketOffset - bracketLength),
      bracketPaint,
    );

    // Target Text "DROP" or "DELIVERED"
    final textPainter = TextPainter(
      text: TextSpan(
        text: status == GameStatus.success ? 'SECURED' : 'DROP',
        style: TextStyle(
          color: CyberTheme.neonGreen,
          fontSize: 10.5,
          fontFamily: 'ShareTechMono',
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(targetCenter.dx - textPainter.width / 2, targetCenter.dy - textPainter.height / 2),
    );

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


    // 6. Draw Obstacles (Buildings)
    for (final obs in level.obstacles) {
      final obsLeft = obs.x * cellWidth + 6.0;
      final obsTop = obs.y * cellHeight + 6.0;
      final obsWidth = cellWidth - 12.0;
      final obsHeightDim = cellHeight - 12.0;
      final rect = Rect.fromLTWH(obsLeft, obsTop, obsWidth, obsHeightDim);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8.0));

      final obstacleGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          CyberTheme.neonPink.withValues(alpha: 0.15),
          CyberTheme.neonPink.withValues(alpha: 0.02),
        ],
      );

      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = obstacleGradient.createShader(rect)
          ..style = PaintingStyle.fill,
      );

      final borderPaint = Paint()
        ..color = CyberTheme.neonPink.withValues(alpha: 0.8)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(rrect, borderPaint);

      final stripePaint = Paint()
        ..color = CyberTheme.neonPink.withValues(alpha: 0.25)
        ..strokeWidth = 1.0;
      
      for (int h = 1; h < obs.height; h++) {
        final double lineY = obsTop + (obsHeightDim * (h / obs.height));
        canvas.drawLine(Offset(obsLeft + 4, lineY), Offset(obsLeft + obsWidth - 4, lineY), stripePaint);
      }

      final obsTextPainter = TextPainter(
        text: TextSpan(
          text: 'H:${obs.height}',
          style: TextStyle(
            color: CyberTheme.neonPink,
            fontSize: 12.0,
            fontFamily: 'ShareTechMono',
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      obsTextPainter.layout();
      obsTextPainter.paint(
        canvas,
        Offset(rect.center.dx - obsTextPainter.width / 2, rect.center.dy - obsTextPainter.height / 2),
      );
    }

    // 7. Draw Collectibles (Energy Cells)
    final floatOffset = 3.0 * math.sin(animationValue * 2 * math.pi);
    for (final cell in remainingEnergyCells) {
      final cellCenterX = (cell.x + 0.5) * cellWidth;
      final cellCenterY = (cell.y + 0.5) * cellHeight + floatOffset;
      final radius = math.min(cellWidth, cellHeight) * 0.18;

      final diamondPath = Path()
        ..moveTo(cellCenterX, cellCenterY - radius)
        ..lineTo(cellCenterX + radius, cellCenterY)
        ..lineTo(cellCenterX, cellCenterY + radius)
        ..lineTo(cellCenterX - radius, cellCenterY)
        ..close();

      final cellPaint = Paint()
        ..color = CyberTheme.neonYellow.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawPath(diamondPath, cellPaint);

      final cellBorderPaint = Paint()
        ..color = CyberTheme.neonYellow.withValues(alpha: 0.9)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawPath(diamondPath, cellBorderPaint);

      final corePaint = Paint()
        ..color = CyberTheme.neonYellow
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cellCenterX, cellCenterY), 3.0, corePaint);

      final cellTextPainter = TextPainter(
        text: TextSpan(
          text: 'ALT ${cell.height}',
          style: TextStyle(
            color: CyberTheme.neonYellow,
            fontSize: 10.0,
            fontFamily: 'ShareTechMono',
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      cellTextPainter.layout();
      cellTextPainter.paint(
        canvas,
        Offset(cellCenterX - cellTextPainter.width / 2, cellCenterY + radius + 3.0),
      );
    }
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

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/level.dart';
import '../theme/colors.dart';
import '../providers/game_state.dart';
import 'cyber_card.dart';

class RadarSweeper extends StatefulWidget {
  const RadarSweeper({super.key});

  @override
  State<RadarSweeper> createState() => _RadarSweeperState();
}

class _RadarSweeperState extends State<RadarSweeper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(painter: RadarSweepPainter(_controller.value));
      },
    );
  }
}

class RadarSweepPainter extends CustomPainter {
  final double progress;
  RadarSweepPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi * 2,
        colors: [
          CyberTheme.neonCyan.withValues(alpha: 0.15),
          CyberTheme.neonCyan.withValues(alpha: 0.0),
        ],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(rect);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant RadarSweepPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class GridLinesPainter extends CustomPainter {
  final int cols;
  final int rows;
  final Color color;

  GridLinesPainter({
    required this.cols,
    required this.rows,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;

    // Draw vertical lines
    for (int i = 1; i < cols; i++) {
      final x = i * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (int i = 1; i < rows; i++) {
      final y = i * cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridLinesPainter oldDelegate) =>
      oldDelegate.cols != cols ||
      oldDelegate.rows != rows ||
      oldDelegate.color != color;
}

class MissionPreviewMap extends StatelessWidget {
  final Level level;
  final Color themeColor;
  final bool isLocked;
  final DroneGameState? liveState;

  const MissionPreviewMap({
    super.key,
    required this.level,
    required this.themeColor,
    required this.isLocked,
    this.liveState,
  });

  @override
  Widget build(BuildContext context) {
    final state = liveState;
    final isCrashed = state?.status == GameStatus.crashed;
    final isSuccess = state?.status == GameStatus.success;

    final currentDroneX = state?.droneX ?? level.startX;
    final currentDroneY = state?.droneY ?? level.startY;
    final currentDroneDir = state?.droneDirection ?? level.startDirection;
    final hasCargo = state?.hasCargo ?? false;
    final energyCells = state?.remainingEnergyCells ?? level.energyCells;

    return AspectRatio(
      aspectRatio: 1.0,
      child: CyberCard(
        borderColor: isLocked
            ? CyberTheme.textMuted.withValues(alpha: 0.2)
            : (isCrashed
                  ? CyberTheme.neonPink.withValues(alpha: 0.6)
                  : (isSuccess
                        ? CyberTheme.neonGreen.withValues(alpha: 0.6)
                        : themeColor.withValues(alpha: 0.4))),
        backgroundColor: const Color(0xFF070913),
        borderWidth: 1.2,
        chamferSize: 10.0,
        showAccents: false,
        child: ClipPath(
          clipper: CyberCardClipper(chamferSize: 10.0),
          child: Stack(
            children: [
              // Radar Sweeper in background
              if (!isLocked && !isCrashed)
                const Positioned.fill(child: RadarSweeper()),

              // Grid lines
              Positioned.fill(
                child: CustomPaint(
                  painter: GridLinesPainter(
                    cols: level.gridWidth,
                    rows: level.gridHeight,
                    color: isLocked
                        ? CyberTheme.textMuted.withValues(alpha: 0.04)
                        : (isCrashed
                              ? CyberTheme.neonPink.withValues(alpha: 0.06)
                              : themeColor.withValues(alpha: 0.08)),
                  ),
                ),
              ),

              // Elements Layout
              if (!isLocked)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cellWidth = constraints.maxWidth / level.gridWidth;
                      final cellHeight =
                          constraints.maxHeight / level.gridHeight;

                      // Drone
                      final droneSize = math.min(cellWidth, cellHeight) * 0.7;
                      final droneLeft =
                          currentDroneX * cellWidth +
                          (cellWidth - droneSize) / 2;
                      final droneTop =
                          currentDroneY * cellHeight +
                          (cellHeight - droneSize) / 2;

                      // Cargo Box
                      final cargoSize = math.min(cellWidth, cellHeight) * 0.45;
                      final cargoX = hasCargo ? currentDroneX : level.boxX;
                      final cargoY = hasCargo ? currentDroneY : level.boxY;
                      final cargoLeft =
                          cargoX * cellWidth + (cellWidth - cargoSize) / 2;
                      final cargoTop =
                          cargoY * cellHeight + (cellHeight - cargoSize) / 2;

                      // Target Pad
                      final targetSize = math.min(cellWidth, cellHeight) * 0.75;
                      final targetLeft =
                          level.targetX * cellWidth +
                          (cellWidth - targetSize) / 2;
                      final targetTop =
                          level.targetY * cellHeight +
                          (cellHeight - targetSize) / 2;

                      // Obstacles
                      final List<Widget> obstacleWidgets = [];
                      for (int i = 0; i < level.obstacles.length; i++) {
                        final obs = level.obstacles[i];
                        final obsSize = math.min(cellWidth, cellHeight) * 0.75;
                        final obsLeft =
                            obs.x * cellWidth + (cellWidth - obsSize) / 2;
                        final obsTop =
                            obs.y * cellHeight + (cellHeight - obsSize) / 2;

                        obstacleWidgets.add(
                          Positioned(
                            key: ValueKey('obs_${level.id}_$i'),
                            left: obsLeft,
                            top: obsTop,
                            width: obsSize,
                            height: obsSize,
                            child:
                                Icon(
                                      Icons.grid_goldenratio,
                                      color: CyberTheme.neonPink.withValues(
                                        alpha: 0.8,
                                      ),
                                      size: obsSize * 0.9,
                                    )
                                    .animate(
                                      onPlay: (c) => c.repeat(reverse: true),
                                    )
                                    .shimmer(duration: 2.seconds),
                          ),
                        );
                      }

                      // Energy Cells
                      final List<Widget> energyWidgets = [];
                      for (int i = 0; i < energyCells.length; i++) {
                        final ec = energyCells[i];
                        final ecSize = math.min(cellWidth, cellHeight) * 0.5;
                        final ecLeft =
                            ec.x * cellWidth + (cellWidth - ecSize) / 2;
                        final ecTop =
                            ec.y * cellHeight + (cellHeight - ecSize) / 2;

                        energyWidgets.add(
                          Positioned(
                            key: ValueKey('ec_${level.id}_$i'),
                            left: ecLeft,
                            top: ecTop,
                            width: ecSize,
                            height: ecSize,
                            child:
                                Icon(
                                      Icons.bolt,
                                      color: CyberTheme.neonYellow,
                                      size: ecSize,
                                    )
                                    .animate(
                                      onPlay: (c) => c.repeat(reverse: true),
                                    )
                                    .scale(
                                      duration: 1000.ms,
                                      begin: const Offset(0.9, 0.9),
                                      end: const Offset(1.1, 1.1),
                                    ),
                          ),
                        );
                      }

                      return Stack(
                        children: [
                          // Target Pad (rendered below drone and cargo)
                          Positioned(
                            key: ValueKey('target_${level.id}'),
                            left: targetLeft,
                            top: targetTop,
                            width: targetSize,
                            height: targetSize,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                      width: targetSize,
                                      height: targetSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: CyberTheme.neonGreen
                                              .withValues(alpha: 0.6),
                                          width: 1.5,
                                        ),
                                      ),
                                    )
                                    .animate(
                                      onPlay: (c) => c.repeat(reverse: true),
                                    )
                                    .scale(
                                      duration: 1500.ms,
                                      begin: const Offset(0.85, 0.85),
                                      end: const Offset(1.05, 1.05),
                                    ),
                                Icon(
                                  Icons.my_location,
                                  color: CyberTheme.neonGreen,
                                  size: targetSize * 0.75,
                                ),
                              ],
                            ),
                          ),

                          // Obstacles
                          ...obstacleWidgets,

                          // Energy cells
                          ...energyWidgets,

                          // Cargo Box
                          Positioned(
                            key: ValueKey('box_${level.id}'),
                            left: cargoLeft,
                            top: cargoTop,
                            width: cargoSize,
                            height: cargoSize,
                            child:
                                Container(
                                      decoration: BoxDecoration(
                                        color: CyberTheme.neonCyan.withValues(
                                          alpha: 0.15,
                                        ),
                                        border: Border.all(
                                          color: CyberTheme.neonCyan,
                                          width: 1.2,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          4.0,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.inventory_2,
                                        color: CyberTheme.neonCyan,
                                        size: cargoSize * 0.7,
                                      ),
                                    )
                                    .animate(
                                      onPlay: (c) => c.repeat(reverse: true),
                                    )
                                    .scale(
                                      duration: 1200.ms,
                                      begin: const Offset(0.9, 0.9),
                                      end: const Offset(1.1, 1.1),
                                    ),
                          ),

                          // Drone
                          Positioned(
                            key: ValueKey('drone_${level.id}'),
                            left: droneLeft,
                            top: droneTop,
                            width: droneSize,
                            height: droneSize,
                            child:
                                Transform.rotate(
                                      angle: currentDroneDir.angleInRadians,
                                      child: Icon(
                                        Icons.navigation,
                                        color: isCrashed
                                            ? CyberTheme.neonPink
                                            : (isSuccess
                                                  ? CyberTheme.neonGreen
                                                  : themeColor),
                                        size: droneSize,
                                      ),
                                    )
                                    .animate(
                                      onPlay: (c) => c.repeat(reverse: true),
                                    )
                                    .scale(
                                      duration: 800.ms,
                                      begin: const Offset(0.95, 0.95),
                                      end: const Offset(1.05, 1.05),
                                    ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

              // Telemetry scanning state HUD indicators
              if (state != null && !isLocked)
                Positioned(
                  top: 6.0,
                  left: 6.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5.0,
                      vertical: 2.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      border: Border.all(
                        color: isCrashed
                            ? CyberTheme.neonPink.withValues(alpha: 0.5)
                            : CyberTheme.neonCyan.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                              width: 4.0,
                              height: 4.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCrashed
                                    ? CyberTheme.neonPink
                                    : (isSuccess
                                          ? CyberTheme.neonGreen
                                          : CyberTheme.neonCyan),
                              ),
                            )
                            .animate(onPlay: (c) => c.repeat())
                            .scale(
                              end: const Offset(1.5, 1.5),
                              duration: 800.ms,
                            )
                            .then()
                            .fadeOut(duration: 200.ms),
                        const SizedBox(width: 4.0),
                        Text(
                          isCrashed
                              ? 'TELEMETRY CORRUPTED'
                              : (isSuccess
                                    ? 'MISSION COMPLETE'
                                    : 'LIVE SCANNING'),
                          style: CyberTheme.fontCode(
                            size: 7.5,
                            color: isCrashed
                                ? CyberTheme.neonPink
                                : (isSuccess
                                      ? CyberTheme.neonGreen
                                      : CyberTheme.neonCyan),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Encrypted locked overlay
              if (isLocked)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.8),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 8.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          border: Border.all(
                            color: CyberTheme.textMuted.withValues(alpha: 0.5),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock_outline_rounded,
                              color: CyberTheme.textMuted,
                              size: 14.0,
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              'ENCRYPTED',
                              style: CyberTheme.fontCode(
                                size: 10.0,
                                color: CyberTheme.textMuted,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/level.dart';
import '../theme/colors.dart';
import '../providers/game_state.dart';
import 'drone_sprite.dart';
import 'helipad_widget.dart';

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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 3D holographic projection of the tactical map
          Positioned.fill(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // Perspective tilt
                ..rotateX(0.55) // Tilt backward
                ..rotateZ(-0.45) // Rotate slightly
                ..multiply(
                  Matrix4.diagonal3Values(0.85, 0.85, 1.0),
                ), // Scale slightly larger since card borders are removed
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 3D Land Base (extruded floating plate using Z-translation)
                  ...List.generate(9, (i) {
                    final index = 8 - i;
                    if (index == 8) {
                      // Underglow shadow layer
                      return Transform(
                        transform: Matrix4.translationValues(0, 0, -24.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (isLocked
                                            ? CyberTheme.textMuted
                                            : (isCrashed
                                                  ? CyberTheme.neonPink
                                                  : themeColor))
                                        .withValues(alpha: 0.25),
                                blurRadius: 16.0,
                                spreadRadius: 4.0,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final zOffset = -index * 2.5;
                    final opacity = 0.95 - (index * 0.05);
                    return Transform(
                      transform: Matrix4.translationValues(0, 0, zOffset),
                      child: Container(
                        decoration: BoxDecoration(
                          color: index == 0
                              ? const Color(0xFF0F172A)
                              : const Color(
                                  0xFF070B14,
                                ).withValues(alpha: opacity),
                          border: index == 0
                              ? Border.all(
                                  color: isLocked
                                      ? CyberTheme.textMuted.withValues(
                                          alpha: 0.4,
                                        )
                                      : (isCrashed
                                            ? CyberTheme.neonPink.withValues(
                                                alpha: 0.8,
                                              )
                                            : themeColor.withValues(
                                                alpha: 0.8,
                                              )),
                                  width: 1.5,
                                )
                              : Border.all(
                                  color: isLocked
                                      ? CyberTheme.textMuted.withValues(
                                          alpha: 0.08,
                                        )
                                      : (isCrashed
                                            ? CyberTheme.neonPink.withValues(
                                                alpha: 0.15,
                                              )
                                            : themeColor.withValues(
                                                alpha: 0.15,
                                              )),
                                  width: 1.0,
                                ),
                        ),
                      ),
                    );
                  }),

                  // Radar Sweeper (tilted in 3D, sweeping on the land surface)
                  if (!isLocked && !isCrashed)
                    const Positioned.fill(child: RadarSweeper()),

                  // Grid lines (Tilted in 3D)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: GridLinesPainter(
                        cols: level.gridWidth,
                        rows: level.gridHeight,
                        color: isLocked
                            ? CyberTheme.textMuted.withValues(alpha: 0.05)
                            : (isCrashed
                                  ? CyberTheme.neonPink.withValues(alpha: 0.08)
                                  : themeColor.withValues(alpha: 0.1)),
                      ),
                    ),
                  ),

                  // Elements Layout (Tilted in 3D)
                  if (!isLocked)
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final cellWidth =
                              constraints.maxWidth / level.gridWidth;
                          final cellHeight =
                              constraints.maxHeight / level.gridHeight;

                          final cellSize = math.min(cellWidth, cellHeight);
                          final hUnit = cellSize * 0.5625;

                          // Drone dimensions
                          final droneSize = cellSize * 0.90;
                          final droneLeft =
                              currentDroneX * cellWidth +
                              (cellWidth - droneSize) / 2;
                          final droneTop =
                              currentDroneY * cellHeight +
                              (cellHeight - droneSize) / 2;

                          final droneHeightValue =
                              state?.droneHeight ??
                              1; // Default to 1 for visual premium float when idle

                          // Cargo Box dimensions
                          final cargoSize = cellSize * 0.45;
                          final cargoLeft =
                              level.boxX * cellWidth +
                              (cellWidth - cargoSize) / 2;
                          final cargoTop =
                              level.boxY * cellHeight +
                              (cellHeight - cargoSize) / 2;

                          // Target Pad dimensions
                          final targetSize = cellSize * 0.55;
                          final targetLeft =
                              level.targetX * cellWidth +
                              (cellWidth - targetSize) / 2;
                          final targetTop =
                              level.targetY * cellHeight +
                              (cellHeight - targetSize) / 2;

                          // Obstacles (drawn as 3D holographic pillars using Z-translation)
                          final List<Widget> obstacleWidgets = [];
                          for (int i = 0; i < level.obstacles.length; i++) {
                            final obs = level.obstacles[i];
                            final obsSize = cellSize * 0.75;
                            final obsLeft =
                                obs.x * cellWidth + (cellWidth - obsSize) / 2;
                            final obsTop =
                                obs.y * cellHeight + (cellHeight - obsSize) / 2;

                            final numLayers = obs.height * 10;
                            final totalHeight = obs.height * hUnit;
                            final step = totalHeight / (numLayers - 1);

                            obstacleWidgets.add(
                              Stack(
                                children: List.generate(numLayers, (
                                  layerIndex,
                                ) {
                                  final zVal = layerIndex * step;
                                  final isTop = layerIndex == (numLayers - 1);
                                  return Positioned(
                                    key: ValueKey(
                                      'obs_${level.id}_${i}_$layerIndex',
                                    ),
                                    left: obsLeft,
                                    top: obsTop,
                                    width: obsSize,
                                    height: obsSize,
                                    child: Transform(
                                      transform: Matrix4.translationValues(
                                        0,
                                        0,
                                        zVal,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isTop
                                              ? CyberTheme.neonPink.withValues(
                                                  alpha: 0.3,
                                                )
                                              : const Color(
                                                  0xFF6B123C,
                                                ).withValues(alpha: 0.9),
                                          border: Border.all(
                                            color: isTop
                                                ? CyberTheme.neonPink
                                                : CyberTheme.neonPink
                                                      .withValues(alpha: 0.3),
                                            width: 1.0,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4.0,
                                          ),
                                        ),
                                        child: isTop
                                            ? Center(
                                                child: Text(
                                                  'H:${obs.height}',
                                                  style:
                                                      CyberTheme.fontCode(
                                                        size: math.max(
                                                          6.0,
                                                          obsSize * 0.28,
                                                        ),
                                                        color:
                                                            CyberTheme.neonPink,
                                                      ).copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            );
                          }

                          // Energy Cells (floating at their specified Z-height)
                          final List<Widget> energyWidgets = [];
                          for (int i = 0; i < energyCells.length; i++) {
                            final ec = energyCells[i];
                            final ecSize = cellSize * 0.5;
                            final ecOffset = ec.height * hUnit;
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
                                child: Stack(
                                  alignment: Alignment.center,
                                  clipBehavior: Clip.none,
                                  children: [
                                    Center(
                                      child: Container(
                                        width: ecSize * 0.4,
                                        height: ecSize * 0.15,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.black45,
                                        ),
                                      ),
                                    ),
                                    Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.translationValues(
                                        0,
                                        0,
                                        ecOffset,
                                      ),
                                      child:
                                          Icon(
                                                Icons.bolt,
                                                color: CyberTheme.neonYellow,
                                                size: ecSize,
                                              )
                                              .animate(
                                                onPlay: (c) =>
                                                    c.repeat(reverse: true),
                                              )
                                              .scale(
                                                duration: 1000.ms,
                                                begin: const Offset(0.9, 0.9),
                                                end: const Offset(1.1, 1.1),
                                              ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return Stack(
                            children: [
                              // 3D Target Pad (Volumetric 3D Helipad Widget)
                              Positioned(
                                key: ValueKey('target_${level.id}'),
                                left: targetLeft,
                                top: targetTop,
                                width: targetSize,
                                height: targetSize,
                                child:
                                    Stack(
                                          alignment: Alignment.center,
                                          clipBehavior: Clip.none,
                                          children: [
                                            HelipadWidget(size: targetSize),
                                          ],
                                        )
                                        .animate(
                                          onPlay: (c) =>
                                              c.repeat(reverse: true),
                                        )
                                        .scale(
                                          duration: 1500.ms,
                                          begin: const Offset(0.9, 0.9),
                                          end: const Offset(1.05, 1.05),
                                        ),
                              ),

                              // Obstacles (3D pillars)
                              ...obstacleWidgets,

                              // Energy cells (floating in 3D)
                              ...energyWidgets,

                              // Volumetric 3D Cargo Crate
                              if (!hasCargo)
                                Positioned(
                                  key: ValueKey('box_${level.id}'),
                                  left: cargoLeft,
                                  top: cargoTop,
                                  width: cargoSize,
                                  height: cargoSize,
                                  child:
                                      Stack(
                                            children: List.generate(8, (
                                              layerIndex,
                                            ) {
                                              final zVal =
                                                  layerIndex *
                                                  (cargoSize * 0.85 / 7);
                                              final isTop = layerIndex == 7;
                                              return Transform(
                                                transform:
                                                    Matrix4.translationValues(
                                                      0,
                                                      0,
                                                      zVal,
                                                    ),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: isTop
                                                        ? Colors.transparent
                                                        : const Color(
                                                            0xFFB4703C,
                                                          ).withValues(
                                                            alpha: 0.95,
                                                          ),
                                                    border: isTop
                                                        ? null
                                                        : Border.all(
                                                            color:
                                                                const Color(
                                                                  0xFF8B4F21,
                                                                ).withValues(
                                                                  alpha: 0.4,
                                                                ),
                                                            width: 1.0,
                                                          ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          2.0,
                                                        ),
                                                  ),
                                                  child: isTop
                                                      ? CustomPaint(
                                                          size: Size(
                                                            cargoSize,
                                                            cargoSize,
                                                          ),
                                                          painter:
                                                              PreviewCargoTopPainter(),
                                                        )
                                                      : null,
                                                ),
                                              );
                                            }),
                                          )
                                          .animate(
                                            onPlay: (c) =>
                                                c.repeat(reverse: true),
                                          )
                                          .scale(
                                            duration: 1200.ms,
                                            begin: const Offset(0.9, 0.9),
                                            end: const Offset(1.1, 1.1),
                                          ),
                                ),

                              // Single Grouped Drone Stack on the preview map (perpendicular Z-translation)
                              AnimatedPositioned(
                                key: ValueKey('drone_preview_${level.id}'),
                                duration:
                                    (state != null &&
                                        state.status == GameStatus.running)
                                    ? Duration(
                                        milliseconds:
                                            (1600 / state.speedMultiplier)
                                                .round(),
                                      )
                                    : Duration.zero,
                                curve: Curves.easeInOutCubic,
                                left: droneLeft,
                                top: droneTop,
                                width: droneSize,
                                height: droneSize,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(
                                    end: droneHeightValue.toDouble(),
                                  ),
                                  duration:
                                      (state != null &&
                                          state.status == GameStatus.running)
                                      ? Duration(
                                          milliseconds:
                                              (1600 / state.speedMultiplier)
                                                  .round(),
                                        )
                                      : Duration.zero,
                                  curve: Curves.easeInOutCubic,
                                  builder: (context, animHeight, child) {
                                    final currentZ = animHeight * hUnit;
                                    final shadowOpacity = math.max(
                                      0.0,
                                      math.min(0.4, 0.4 * animHeight),
                                    );

                                    return Stack(
                                      alignment: Alignment.center,
                                      clipBehavior: Clip.none,
                                      children: [
                                        // 1. Drone Shadow (always at z = 0)
                                        if (animHeight > 0.05)
                                          Center(
                                            child: Opacity(
                                              opacity: shadowOpacity,
                                              child: Container(
                                                width: droneSize * 0.5,
                                                height: droneSize * 0.5,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.black,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black,
                                                      blurRadius: 4,
                                                      spreadRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),

                                        // 2. Drone Vertical Connector Line (stacked dots in Z-axis)
                                        if (animHeight > 0.05)
                                          ...List.generate(5, (index) {
                                            final zVal = (index / 4) * currentZ;
                                            return Transform(
                                              alignment: Alignment.center,
                                              transform:
                                                  Matrix4.translationValues(
                                                    0,
                                                    0,
                                                    zVal,
                                                  ),
                                              child: Center(
                                                child: Container(
                                                  width: 2.0,
                                                  height: 2.0,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color:
                                                        (isCrashed
                                                                ? CyberTheme
                                                                      .neonPink
                                                                : (isSuccess
                                                                      ? CyberTheme
                                                                            .neonGreen
                                                                      : themeColor))
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),

                                        // 3. Elevated Drone Sprite (Z-translated)
                                        Transform(
                                          alignment: Alignment.center,
                                          transform: Matrix4.translationValues(
                                            0,
                                            0,
                                            currentZ,
                                          ),
                                          child: Center(
                                            child:
                                                DroneSprite(
                                                      size: droneSize,
                                                      height: droneHeightValue
                                                          .round(),
                                                      direction:
                                                          currentDroneDir,
                                                      isFlying:
                                                          state != null &&
                                                          droneHeightValue >
                                                              0 &&
                                                          state.status ==
                                                              GameStatus
                                                                  .running,
                                                      hasCargo: hasCargo,
                                                      status: isCrashed
                                                          ? GameStatus.crashed
                                                          : (isSuccess
                                                                ? GameStatus
                                                                      .success
                                                                : GameStatus
                                                                      .running),
                                                      speedMultiplier:
                                                          state
                                                              ?.speedMultiplier ??
                                                          1.0,
                                                    )
                                                    .animate(
                                                      onPlay: (c) => c.repeat(
                                                        reverse: true,
                                                      ),
                                                    )
                                                    .scale(
                                                      duration: 800.ms,
                                                      begin: const Offset(
                                                        0.95,
                                                        0.95,
                                                      ),
                                                      end: const Offset(
                                                        1.05,
                                                        1.05,
                                                      ),
                                                    ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
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
                        .scale(end: const Offset(1.5, 1.5), duration: 800.ms)
                        .then()
                        .fadeOut(duration: 200.ms),
                    const SizedBox(width: 4.0),
                    Text(
                      isCrashed
                          ? 'TELEMETRY CORRUPTED'
                          : (isSuccess ? 'MISSION COMPLETE' : 'LIVE SCANNING'),
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
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
                    border: Border.all(
                      color: CyberTheme.textMuted.withValues(alpha: 0.4),
                      width: 1.0,
                    ),
                    borderRadius: BorderRadius.circular(4.0),
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
        ],
      ),
    );
  }
}

class PreviewCargoTopPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Warm cardboard color
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2.0)),
      Paint()
        ..color = const Color(0xFFE5A96C)
        ..style = PaintingStyle.fill,
    );

    // Cardboard borders (darker brown)
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2.0)),
      Paint()
        ..color = const Color(0xFF8B4F21)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke,
    );

    // Central white packaging tape line
    final tapeWidth = size.width * 0.16;
    canvas.drawRect(
      Rect.fromLTWH(cx - tapeWidth / 2, 0, tapeWidth, size.height),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );

    // Division line
    canvas.drawLine(
      Offset(0, cy),
      Offset(size.width, cy),
      Paint()
        ..color = const Color(0xFF8B4F21).withValues(alpha: 0.5)
        ..strokeWidth = 0.6,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

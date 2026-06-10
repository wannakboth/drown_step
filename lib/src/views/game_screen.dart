import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/level.dart';
import '../providers/game_state.dart';
import '../theme/colors.dart';
import 'grid_painter.dart';
import 'drone_sprite.dart';
import 'command_panel.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _gridAnimationController;
  GameStatus _delayedStatus = GameStatus.idle;

  @override
  void initState() {
    super.initState();
    _gridAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _delayedStatus = ref.read(gameStateProvider).status;
        });
      }
    });
  }

  @override
  void dispose() {
    _gridAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeLevel = ref.watch(currentLevelProvider);
    final state = ref.watch(gameStateProvider);

    ref.listen<DroneGameState>(gameStateProvider, (previous, next) {
      if (next.status == GameStatus.success || next.status == GameStatus.crashed) {
        if (previous?.status == GameStatus.running) {
          final delayMs = math.max(1200, (1500 / next.speedMultiplier).round());
          Future.delayed(Duration(milliseconds: delayMs), () {
            if (mounted) {
              setState(() {
                _delayedStatus = next.status;
              });
            }
          });
        } else {
          if (_delayedStatus != next.status) {
            setState(() {
              _delayedStatus = next.status;
            });
          }
        }
      } else {
        if (_delayedStatus != next.status) {
          setState(() {
            _delayedStatus = next.status;
          });
        }
      }
    });

    return Scaffold(
      backgroundColor: CyberTheme.darkBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > 850;

            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header (Level Selector & Brand Info)
                  _buildHeader(context, activeLevel, state),
                  const SizedBox(height: 20.0),

                  // 2. Main Game Area
                  Expanded(
                    child: isLandscape
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Grid Arena
                              Expanded(flex: 7, child: _buildGridArena(state)),
                              const SizedBox(width: 24.0),
                              // Sidebar HUD and Command Console
                              Expanded(
                                flex: 5,
                                child: Column(
                                  children: [
                                    _buildHudPanel(state),
                                    const SizedBox(height: 16.0),
                                    const Expanded(child: CommandPanel()),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              // Grid Arena
                              Expanded(flex: 9, child: _buildGridArena(state)),
                              const SizedBox(height: 16.0),
                              // HUD Statistics
                              _buildHudPanel(state),
                              const SizedBox(height: 16.0),
                              // Command Panel
                              const Expanded(flex: 7, child: CommandPanel()),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Level activeLevel,
    DroneGameState state,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Brand Title
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                      width: 6.0,
                      height: 6.0,
                      decoration: const BoxDecoration(
                        color: CyberTheme.neonCyan,
                        shape: BoxShape.circle,
                      ),
                    )
                    .animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .scale(end: const Offset(1.5, 1.5), duration: 1000.ms),
                const SizedBox(width: 8.0),
                Text(
                  'DRONESTEP //',
                  style: CyberTheme.fontHeading(
                    size: 15.0,
                    color: CyberTheme.textMain,
                  ),
                ),
                const SizedBox(width: 6.0),
                Text(
                  'GRID PILOT',
                  style: CyberTheme.fontHeading(
                    size: 15.0,
                    color: CyberTheme.neonCyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4.0),
            Text(
              'FLIGHT SIMULATION SYSTEM ACTIVE',
              style: CyberTheme.fontCode(
                size: 8.5,
                color: CyberTheme.textMuted,
              ),
            ),
          ],
        ),
        // Minimalist Level Selector Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 2.0),
          decoration: BoxDecoration(
            color: CyberTheme.cardBg,
            borderRadius: BorderRadius.circular(100.0),
            border: Border.all(color: CyberTheme.borderTranslucent, width: 1.0),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Level>(
              value: activeLevel,
              dropdownColor: CyberTheme.cardBg,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                size: 18.0,
                color: CyberTheme.neonCyan,
              ),
              onChanged: (newLevel) {
                if (newLevel != null) {
                  ref.read(currentLevelProvider.notifier).setLevel(newLevel);
                }
              },
              items: Level.predefinedLevels.map((lvl) {
                return DropdownMenuItem<Level>(
                  value: lvl,
                  child: Text(
                    'LEVEL ${lvl.id}: ${lvl.title}',
                    style: CyberTheme.fontCode(
                      size: 11.5,
                      color: CyberTheme.neonCyan,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridArena(DroneGameState state) {
    return Container(
      decoration: BoxDecoration(
        color: CyberTheme.gridBg,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: CyberTheme.borderTranslucent, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30.0,
            spreadRadius: -10.0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.0),
        child: LayoutBuilder(
          builder: (context, gridConstraints) {
            final level = state.level;
            final gridAspect = level.gridWidth / level.gridHeight;
            final containerAspect =
                gridConstraints.maxWidth / gridConstraints.maxHeight;

            double width, height;
            if (gridAspect > containerAspect) {
              width = gridConstraints.maxWidth;
              height = width / gridAspect;
            } else {
              height = gridConstraints.maxHeight;
              width = height * gridAspect;
            }

            final cellWidth = width / level.gridWidth;
            final cellHeight = height / level.gridHeight;
            final droneSize = math.min(cellWidth, cellHeight) * 0.65;

            final droneLeft =
                state.droneX * cellWidth + (cellWidth - droneSize) / 2;
            final droneTop =
                state.droneY * cellHeight + (cellHeight - droneSize) / 2;

            final double cargoBoxSize = math.min(cellWidth, cellHeight) * 0.22;
            final cargoLeft =
                level.boxX * cellWidth + (cellWidth - cargoBoxSize) / 2;
            final cargoTop =
                level.boxY * cellHeight + (cellHeight - cargoBoxSize) / 2;

            return Center(
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Grid Painter & Cargo Overlay
                    AnimatedBuilder(
                      animation: _gridAnimationController,
                      builder: (context, child) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CustomPaint(
                              size: Size(width, height),
                              painter: GameGridPainter(
                                level: level,
                                droneX: state.droneX,
                                droneY: state.droneY,
                                droneHeight: state.droneHeight,
                                remainingEnergyCells: state.remainingEnergyCells,
                                pathHistory: state.pathHistory,
                                animationValue: _gridAnimationController.value,
                                hasCargo: state.hasCargo,
                              ),
                            ),
                            CargoBoxWidget(
                              left: cargoLeft,
                              top: cargoTop,
                              size: cargoBoxSize,
                              hasCargo: state.hasCargo,
                              speedMultiplier: state.speedMultiplier,
                              animationValue: _gridAnimationController.value,
                            ),
                          ],
                        );
                      },
                    ),

                    // Custom Animated Drone Sprite
                    AnimatedPositioned(
                      duration: state.status == GameStatus.running
                          ? Duration(
                              milliseconds: (700 / state.speedMultiplier)
                                  .round(),
                            )
                          : Duration.zero,
                      curve: Curves.easeInOutCubic,
                      left: droneLeft,
                      top: droneTop,
                      width: droneSize,
                      height: droneSize,
                      child: Center(
                        child: DroneSprite(
                          size: droneSize,
                          height: state.droneHeight,
                          direction: state.droneDirection,
                          isFlying:
                              state.droneHeight > 0 &&
                              state.status == GameStatus.running,
                          hasCargo: state.hasCargo,
                          status: state.status,
                          speedMultiplier: state.speedMultiplier,
                        ),
                      ),
                    ),

                    // Game Success Overlay
                    if (_delayedStatus == GameStatus.success)
                      _buildSuccessOverlay(state),

                    // Game Crash Overlay
                    if (_delayedStatus == GameStatus.crashed)
                      _buildCrashOverlay(state),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHudPanel(DroneGameState state) {
    final batteryPercentage = (state.battery / state.level.initialBattery)
        .clamp(0.0, 1.0);
    Color batteryColor = CyberTheme.neonGreen;
    if (batteryPercentage < 0.3) {
      batteryColor = CyberTheme.neonPink;
    } else if (batteryPercentage < 0.6) {
      batteryColor = CyberTheme.neonYellow;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: CyberTheme.cardBg,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: CyberTheme.borderTranslucent, width: 1.0),
      ),
      child: Row(
        children: [
          // Battery HUD
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BATTERY POWER',
                      style: CyberTheme.fontCode(
                        size: 9.0,
                        color: CyberTheme.textMuted,
                      ),
                    ),
                    Text(
                      '${state.battery}/${state.level.initialBattery} WH',
                      style: CyberTheme.fontCode(
                        size: 10.5,
                        color: batteryColor,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                // Ultra-thin minimalist battery progress line
                Stack(
                  children: [
                    Container(
                      height: 3.0,
                      decoration: BoxDecoration(
                        color: CyberTheme.darkBg,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 3.0,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: batteryColor,
                            borderRadius: BorderRadius.circular(10.0),
                            boxShadow: CyberTheme.neonGlow(
                              batteryColor,
                              radius: 6.0,
                            ),
                          ),
                        )
                        .animate(target: batteryPercentage)
                        .scaleXY(alignment: Alignment.centerLeft),
                  ],
                ),
              ],
            ),
          ),

          // Custom vertical dividers for clean dashboards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
              width: 1.0,
              height: 28.0,
              color: CyberTheme.borderTranslucent,
            ),
          ),

          // Altitude Status
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALTITUDE',
                  style: CyberTheme.fontCode(
                    size: 9.0,
                    color: CyberTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  '${state.droneHeight}m',
                  style: CyberTheme.fontCode(
                    size: 13.0,
                    color: state.droneHeight > 0
                        ? CyberTheme.neonCyan
                        : CyberTheme.textMuted,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Custom vertical dividers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              width: 1.0,
              height: 28.0,
              color: CyberTheme.borderTranslucent,
            ),
          ),

          // Optimal command target ratio
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RATIO',
                  style: CyberTheme.fontCode(
                    size: 9.0,
                    color: CyberTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  '${state.commandQueue.length}/${state.level.star3Target}',
                  style: CyberTheme.fontCode(
                    size: 13.0,
                    color: state.commandQueue.length <= state.level.star3Target
                        ? CyberTheme.neonGreen
                        : CyberTheme.neonYellow,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessOverlay(DroneGameState state) {
    int stars = 1;
    if (state.commandQueue.length <= state.level.star3Target) {
      stars = 3;
    } else if (state.commandQueue.length <= state.level.star3Target + 3) {
      stars = 2;
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          color: CyberTheme.darkBg.withValues(alpha: 0.75),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: CyberTheme.neonGreen.withValues(alpha: 0.1),
                    border: Border.all(
                      color: CyberTheme.neonGreen.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: CyberTheme.neonGreen,
                    size: 44.0,
                  ),
                ).animate().scale(
                  delay: 100.ms,
                  duration: 400.ms,
                  curve: Curves.elasticOut,
                ),
                const SizedBox(height: 16.0),
                Text(
                  'MISSION COMPLETED',
                  style: CyberTheme.fontHeading(
                    size: 20.0,
                    color: CyberTheme.neonGreen,
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0.0),
                const SizedBox(height: 6.0),
                Text(
                  'Target platform reached successfully.',
                  style: CyberTheme.fontBody(
                    size: 13.0,
                    color: CyberTheme.textMuted,
                  ),
                ).animate().fadeIn(delay: 350.ms),
                const SizedBox(height: 20.0),
                // Premium flat Star display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    final isLit = index < stars;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child:
                          Icon(
                            isLit ? Icons.star : Icons.star_border,
                            size: 28.0,
                            color: isLit
                                ? CyberTheme.neonYellow
                                : CyberTheme.textMuted.withValues(alpha: 0.2),
                          ).animate().scale(
                            delay: (450 + index * 100).ms,
                            duration: 350.ms,
                            curve: Curves.easeOutBack,
                          ),
                    );
                  }),
                ),
                const SizedBox(height: 28.0),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CyberTheme.textMain,
                        side: const BorderSide(
                          color: CyberTheme.textMuted,
                          width: 1.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100.0),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22.0,
                          vertical: 12.0,
                        ),
                      ),
                      onPressed: () {
                        ref.read(gameStateProvider.notifier).resetSimulation();
                      },
                      child: Text(
                        'REPLAY',
                        style: CyberTheme.fontCode(
                          size: 11.0,
                          color: CyberTheme.textMain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    if (state.level.id < Level.predefinedLevels.length)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CyberTheme.neonGreen,
                          foregroundColor: CyberTheme.darkBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100.0),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22.0,
                            vertical: 12.0,
                          ),
                          elevation: 0.0,
                        ),
                        onPressed: () {
                          final nextLvl = Level.predefinedLevels.firstWhere(
                            (l) => l.id == state.level.id + 1,
                          );
                          ref
                              .read(currentLevelProvider.notifier)
                              .setLevel(nextLvl);
                        },
                        child: Text(
                          'NEXT MISSION',
                          style: CyberTheme.fontCode(
                            size: 11.0,
                            color: CyberTheme.darkBg,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ).animate().fadeIn(delay: 800.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCrashOverlay(DroneGameState state) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          color: CyberTheme.darkBg.withValues(alpha: 0.75),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: CyberTheme.neonPink.withValues(alpha: 0.1),
                      border: Border.all(
                        color: CyberTheme.neonPink.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: CyberTheme.neonPink,
                      size: 44.0,
                    ),
                  ).animate().shake(duration: 400.ms),
                  const SizedBox(height: 16.0),
                  Text(
                    'MISSION CRASHED',
                    style: CyberTheme.fontHeading(
                      size: 20.0,
                      color: CyberTheme.neonPink,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    state.message ?? 'Unknown flight failure encountered.',
                    style: CyberTheme.fontBody(
                      size: 13.0,
                      color: CyberTheme.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 24.0),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CyberTheme.neonPink,
                      foregroundColor: CyberTheme.textMain,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100.0),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 12.0,
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      ref.read(gameStateProvider.notifier).resetSimulation();
                    },
                    child: Text(
                      'RESET SYSTEM & RETRY',
                      style: CyberTheme.fontCode(
                        size: 11.0,
                        color: CyberTheme.textMain,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CargoBoxWidget extends StatefulWidget {
  final double left;
  final double top;
  final double size;
  final bool hasCargo;
  final double speedMultiplier;
  final double animationValue;

  const CargoBoxWidget({
    super.key,
    required this.left,
    required this.top,
    required this.size,
    required this.hasCargo,
    required this.speedMultiplier,
    required this.animationValue,
  });

  @override
  State<CargoBoxWidget> createState() => _CargoBoxWidgetState();
}

class _CargoBoxWidgetState extends State<CargoBoxWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInBack),
    );
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    if (widget.hasCargo) {
      _controller.value = 1.0; // Already picked up
    }
  }

  @override
  void didUpdateWidget(covariant CargoBoxWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasCargo && !oldWidget.hasCargo) {
      // Delay the shrink/fade until the drone claw reaches the box
      final delayMs = (700 / widget.speedMultiplier).round();
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (mounted) {
          _controller.forward();
        }
      });
    } else if (!widget.hasCargo && oldWidget.hasCargo) {
      _controller.reset(); // Instant reset to visible!
    }
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
        final scale = _scaleAnimation.value;
        final opacity = _opacityAnimation.value;

        if (opacity <= 0.0) return const SizedBox.shrink();

        return Positioned(
          left: widget.left,
          top: widget.top,
          width: widget.size,
          height: widget.size,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: CustomPaint(
        size: Size(widget.size, widget.size),
        painter: CargoBoxPainter(animationValue: widget.animationValue),
      ),
    );
  }
}

class CargoBoxPainter extends CustomPainter {
  final double animationValue;

  CargoBoxPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final double cargoBoxSize = size.width;

    // 1. Pulse highlight ring around cargo
    final cargoPulse = 1.0 + 0.1 * math.sin((animationValue + 0.5) * 2 * math.pi);
    final cargoPulsePaint = Paint()
      ..color = CyberTheme.neonYellow.withValues(alpha: 0.25 * (2.0 - cargoPulse))
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, cargoBoxSize * 1.6 * cargoPulse, cargoPulsePaint);

    // 2. Draw Crate body
    final cargoRect = Rect.fromCenter(
      center: center,
      width: cargoBoxSize,
      height: cargoBoxSize,
    );
    final cargoPaint = Paint()
      ..color = CyberTheme.neonYellow.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(cargoRect, const Radius.circular(5.0)), cargoPaint);

    final cargoBorder = Paint()
      ..color = CyberTheme.neonYellow
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(cargoRect, const Radius.circular(5.0)), cargoBorder);

    // 3. Warning stripe patterns inside crate
    final stripePaint = Paint()
      ..color = CyberTheme.neonYellow.withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    canvas.drawLine(cargoRect.topLeft, cargoRect.bottomRight, stripePaint);
    canvas.drawLine(cargoRect.bottomLeft, cargoRect.topRight, stripePaint);

    // 4. Text Label "CARGO"
    final cargoTextPainter = TextPainter(
      text: const TextSpan(
        text: 'CARGO',
        style: TextStyle(
          color: CyberTheme.neonYellow,
          fontSize: 8.0,
          fontFamily: 'ShareTechMono',
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    cargoTextPainter.layout();
    cargoTextPainter.paint(
      canvas,
      Offset(cx - cargoTextPainter.width / 2, cy + cargoBoxSize / 2 + 3.0),
    );
  }

  @override
  bool shouldRepaint(covariant CargoBoxPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

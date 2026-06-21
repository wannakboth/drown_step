import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/audio_provider.dart';
import '../models/level.dart';
import '../models/program_block.dart';
import '../providers/game_state.dart';
import '../theme/colors.dart';
import 'grid_painter.dart';
import 'drone_sprite.dart';
import 'command_panel.dart';
import 'cockpit_tab_painter.dart';
import 'cyber_card.dart';
import 'cyber_dialog.dart';
import 'mission_preview_map.dart';
import '../models/tutorial_keys.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _gridAnimationController;
  late final ScrollController _stepScrollController;
  GameStatus _delayedStatus = GameStatus.idle;
  bool _showCongratsSplash = false;
  bool _earnedDiamondThisRun = false;

  @override
  void initState() {
    super.initState();
    _stepScrollController = ScrollController();
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
    _stepScrollController.dispose();
    super.dispose();
  }

  void _playSound(String assetPath) {
    if (assetPath.contains('click')) {
      ref.read(audioControllerProvider).playClick();
    } else if (assetPath.contains('pickup') || assetPath.contains('success')) {
      ref.read(audioControllerProvider).playPickup();
    } else if (assetPath.contains('crash')) {
      ref.read(audioControllerProvider).playCrash();
    }
  }

  void _updateFlyingSound() {
    final gameState = ref.read(gameStateProvider);
    final isSoundOn = ref.read(soundOnProvider);
    final shouldFly =
        isSoundOn &&
        gameState.status == GameStatus.running &&
        gameState.droneHeight > 0;
    ref.read(audioControllerProvider).updateFlyingState(shouldFly);
  }

  @override
  Widget build(BuildContext context) {
    final activeLevel = ref.watch(currentLevelProvider);
    final state = ref.watch(gameStateProvider);

    ref.listen<bool>(soundOnProvider, (previous, next) {
      _updateFlyingSound();
    });

    ref.listen<DroneGameState>(gameStateProvider, (previous, next) {
      if (previous?.status != next.status ||
          previous?.droneHeight != next.droneHeight) {
        _updateFlyingSound();
      }
      // Play sound effects based on game state changes
      if (next.hasCargo && !(previous?.hasCargo ?? false)) {
        _playSound('audio/pickup.wav');
      } else if (next.status == GameStatus.crashed &&
          previous?.status == GameStatus.running) {
        _playSound('audio/crash.wav');
      } else if (next.pc != previous?.pc && next.status == GameStatus.running) {
        _playSound('audio/click.wav');
      }

      if (next.pc != previous?.pc) {
        _scrollToActiveStep(next.pc);
      }

      if (next.status == GameStatus.running &&
          previous?.status != GameStatus.running) {
        _earnedDiamondThisRun = false;
      }

      if (next.status == GameStatus.success) {
        if (previous?.status == GameStatus.running) {
          int stars = 1;
          if (next.totalBlockCount < next.level.star3Target) {
            stars = 4;
          } else if (next.totalBlockCount <= next.level.star3Target) {
            stars = 3;
          } else if (next.totalBlockCount <= next.level.star3Target + 3) {
            stars = 2;
          }
          // Tutorial levels guarantee at least 3 stars
          if (next.level.id.startsWith('T') && stars < 3) stars = 3;
          stars = math.min(stars, next.level.maxStars);

          final previousStars =
              ref.read(levelStarsProvider)[next.level.id] ?? 0;
          ref.read(levelStarsProvider.notifier).setStars(next.level.id, stars);

          if (next.level.id.startsWith('T')) {
            ref
                .read(maxUnlockedTutorialLevelProvider.notifier)
                .unlockTutorialLevel(next.level.id);
          } else {
            ref
                .read(maxUnlockedLevelProvider.notifier)
                .unlockLevel(next.level.id);
          }

          final mode = ref.read(gameModeProvider);
          if (mode == GameMode.daily) {
            ref.read(pilotBatteryProvider.notifier).rewardBattery(10);
          }

          if (stars == 4 && previousStars < 4) {
            ref.read(pilotBatteryProvider.notifier).rewardBattery(5);
            _earnedDiamondThisRun = true;
          } else {
            _earnedDiamondThisRun = false;
          }

          final stepDelayMs = (1500 / next.speedMultiplier).round();
          Future.delayed(Duration(milliseconds: stepDelayMs), () {
            if (mounted) {
              _playSound('audio/success.wav');
              setState(() {
                _showCongratsSplash = true;
                _delayedStatus = GameStatus.idle;
              });
              Future.delayed(const Duration(milliseconds: 2500), () {
                if (mounted) {
                  setState(() {
                    _showCongratsSplash = false;
                    _delayedStatus = GameStatus.success;
                  });
                }
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
      } else if (next.status == GameStatus.crashed) {
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
        if (_showCongratsSplash) {
          setState(() {
            _showCongratsSplash = false;
          });
        }
        if (_delayedStatus != next.status) {
          setState(() {
            _delayedStatus = next.status;
          });
        }
      }
    });

    final isFlyingFullscreen = state.status != GameStatus.idle;

    return Scaffold(
      backgroundColor: CyberTheme.darkBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > 850;

            final isExpanded =
                ref.watch(consoleExpandedProvider) || isLandscape;

            return Stack(
              children: [
                AnimatedPadding(
                  padding: isFlyingFullscreen
                      ? EdgeInsets.zero
                      : EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth < 500 ? 6.0 : 16.0,
                          vertical: 8.0,
                        ),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Header (Level Selector & Brand Info) - animates height and fades out during flight
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOutCubic,
                        height: isFlyingFullscreen ? 0.0 : 75.0,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: isFlyingFullscreen ? 0.0 : 1.0,
                          child: OverflowBox(
                            maxHeight: 75.0,
                            alignment: Alignment.center,
                            child: _buildHeader(context, activeLevel, state),
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOutCubic,
                        height: isFlyingFullscreen ? 0.0 : 10.0,
                      ),

                      // 2. Main Game Area
                      Expanded(
                        child: isLandscape
                            ? (isFlyingFullscreen
                                  ? Stack(
                                      children: [
                                        _buildGridArena(state),
                                        // Floating HUD on top
                                        Positioned(
                                          top: 16.0,
                                          left: 16.0,
                                          right: 16.0,
                                          child: _buildUnifiedHud(
                                            context,
                                            activeLevel,
                                            state,
                                            isFloating: true,
                                          ),
                                        ),
                                        // Floating controls at the bottom
                                        Positioned(
                                          bottom: 16.0,
                                          left: 16.0,
                                          right: 16.0,
                                          child: _buildFloatingControls(
                                            context,
                                            state,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Grid Arena
                                        Expanded(
                                          flex: 7,
                                          child: _buildGridArena(state),
                                        ),
                                        const SizedBox(width: 24.0),
                                        // Sidebar HUD and Command Console
                                        Expanded(
                                          flex: 5,
                                          child: Column(
                                            children: [
                                              _buildUnifiedHud(
                                                context,
                                                activeLevel,
                                                state,
                                              ),
                                              const SizedBox(height: 10.0),
                                              const Expanded(
                                                child: CommandPanel(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ))
                            : LayoutBuilder(
                                builder: (context, paddedConstraints) {
                                  final height = paddedConstraints.maxHeight;

                                  const toggleHeight = 36.0;
                                  const double hudHeight = 82.0;

                                  final targetPanelHeight = isExpanded
                                      ? (height * 0.70)
                                      : 66.0;

                                  // Compute dynamic grid height in editor mode
                                  final double gridHeight = math.max(
                                    isExpanded ? 50.0 : 100.0,
                                    height -
                                        toggleHeight -
                                        hudHeight -
                                        targetPanelHeight -
                                        24.0,
                                  );

                                  // Ensure panelHeight adjusts to fit exactly within screen height limit
                                  final double panelHeight = math.min(
                                    targetPanelHeight,
                                    math.max(
                                      66.0,
                                      height -
                                          gridHeight -
                                          toggleHeight -
                                          hudHeight -
                                          24.0,
                                    ),
                                  );

                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // 1. Grid Arena (slides to fill full height)
                                      AnimatedPositioned(
                                        duration: const Duration(
                                          milliseconds: 350,
                                        ),
                                        curve: Curves.easeInOutCubic,
                                        left: 0,
                                        right: 0,
                                        top: isFlyingFullscreen
                                            ? 0
                                            : (hudHeight + 10.0),
                                        height: isFlyingFullscreen
                                            ? height
                                            : gridHeight,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 350,
                                          ),
                                          child:
                                              (!isFlyingFullscreen &&
                                                  isExpanded)
                                              ? Center(
                                                  key: const ValueKey(
                                                    'mini_map',
                                                  ),
                                                  child: MissionPreviewMap(
                                                    level: activeLevel,
                                                    themeColor:
                                                        CyberTheme.neonCyan,
                                                    isLocked: false,
                                                    liveState: state,
                                                  ),
                                                )
                                              : KeyedSubtree(
                                                  key: const ValueKey(
                                                    'grid_arena',
                                                  ),
                                                  child: _buildGridArena(state),
                                                ),
                                        ),
                                      ),

                                      // 2. Console Toggle (slides down offscreen and fades)
                                      AnimatedPositioned(
                                        duration: const Duration(
                                          milliseconds: 350,
                                        ),
                                        curve: Curves.easeInOutCubic,
                                        left: 0,
                                        right: 0,
                                        top: isFlyingFullscreen
                                            ? height
                                            : (hudHeight +
                                                  10.0 +
                                                  gridHeight +
                                                  2.0),
                                        height: toggleHeight,
                                        child: AnimatedOpacity(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          opacity: isFlyingFullscreen
                                              ? 0.0
                                              : 1.0,
                                          child: _buildConsoleToggle(
                                            context,
                                            isExpanded,
                                          ),
                                        ),
                                      ),

                                      // 3. Unified HUD (slides to top/middle, transitions styling)
                                      AnimatedPositioned(
                                        duration: const Duration(
                                          milliseconds: 350,
                                        ),
                                        curve: Curves.easeInOutCubic,
                                        left: 0,
                                        right: 0,
                                        top: isFlyingFullscreen ? 10.0 : 0.0,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 350,
                                          ),
                                          child: KeyedSubtree(
                                            key: ValueKey(
                                              'hud_$isFlyingFullscreen',
                                            ),
                                            child: _buildUnifiedHud(
                                              context,
                                              activeLevel,
                                              state,
                                              isFloating: isFlyingFullscreen,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // 4. Command Panel / Controls (slides to bottom overlay, cross-fades)
                                      AnimatedPositioned(
                                        duration: const Duration(
                                          milliseconds: 350,
                                        ),
                                        curve: Curves.easeInOutCubic,
                                        left: 0,
                                        right: 0,
                                        top: isFlyingFullscreen
                                            ? (height - 138.0 - 10.0)
                                            : (gridHeight +
                                                  toggleHeight +
                                                  hudHeight +
                                                  24.0),
                                        height: isFlyingFullscreen
                                            ? 138.0
                                            : panelHeight,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 350,
                                          ),
                                          child: KeyedSubtree(
                                            key: ValueKey(
                                              'controls_$isFlyingFullscreen',
                                            ),
                                            child: isFlyingFullscreen
                                                ? _buildFloatingControls(
                                                    context,
                                                    state,
                                                  )
                                                : const CommandPanel(),
                                          ),
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
                if (_showCongratsSplash)
                  Positioned.fill(child: _buildCongratsSplash()),
                if (_delayedStatus == GameStatus.success)
                  Positioned.fill(child: _buildSuccessOverlay(state)),
                if (_delayedStatus == GameStatus.crashed)
                  Positioned.fill(child: _buildCrashOverlay(state)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildConsoleToggle(BuildContext context, bool isExpanded) {
    final isNarrow = MediaQuery.sizeOf(context).width < 500;
    final String statusText = isExpanded
        ? (isNarrow ? 'FLIGHT TELEMETRY' : 'ENGAGE FLIGHT TELEMETRY')
        : (isNarrow ? 'PROGRAM CONSOLE' : 'ACCESS PROGRAM CONSOLE');

    bool isHovered = false;
    bool isPressed = false;

    return Center(
      child: StatefulBuilder(
        builder: (context, setStateBuilder) {
          return MouseRegion(
            onEnter: (_) => setStateBuilder(() => isHovered = true),
            onExit: (_) => setStateBuilder(() => isHovered = false),
            child: AnimatedScale(
              scale: isPressed ? 0.95 : (isHovered ? 1.04 : 1.0),
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOutCubic,
              child: CustomPaint(
                painter: CockpitTabPainter(
                  backgroundColor: Colors.black.withValues(alpha: 0.9),
                  borderColor: CyberTheme.neonCyan.withValues(
                    alpha: isHovered ? 0.9 : 0.55,
                  ),
                  borderWidth: 1.5,
                ),
                child: GestureDetector(
                  onTapDown: (_) => setStateBuilder(() => isPressed = true),
                  onTapUp: (_) => setStateBuilder(() => isPressed = false),
                  onTapCancel: () => setStateBuilder(() => isPressed = false),
                  onTap: () {
                    _playSound('audio/click.wav');
                    ref
                        .read(consoleExpandedProvider.notifier)
                        .setExpanded(!isExpanded);
                  },
                  child: Container(
                    key: TutorialKeys.console,
                    padding: EdgeInsets.only(
                      left: isNarrow ? 12.0 : 28.0,
                      right: isNarrow ? 12.0 : 28.0,
                      top: 7.0,
                      bottom: 8.0,
                    ),
                    color: Colors.transparent, // Ensure full hit test area
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pulsing System Link LED Status Light
                          Container(
                                width: 5.0,
                                height: 5.0,
                                decoration: BoxDecoration(
                                  color: CyberTheme.neonCyan,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: CyberTheme.neonCyan.withValues(
                                        alpha: 0.8,
                                      ),
                                      blurRadius: 4.0,
                                    ),
                                  ],
                                ),
                              )
                              .animate(
                                onPlay: (controller) =>
                                    controller.repeat(reverse: true),
                              )
                              .fade(duration: 800.ms, begin: 0.3, end: 1.0)
                              .scaleXY(duration: 800.ms, begin: 0.8, end: 1.2),
                          const SizedBox(width: 8.0),
                          // Cockpit brackets + title
                          Text(
                            '[ $statusText ]',
                            style:
                                CyberTheme.fontCode(
                                  size: 13.5,
                                  color: Colors.white.withValues(
                                    alpha: isHovered ? 1.0 : 0.85,
                                  ),
                                ).copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  shadows: isHovered
                                      ? [
                                          Shadow(
                                            color: CyberTheme.neonCyan.withValues(
                                              alpha: 0.5,
                                            ),
                                            blurRadius: 5.0,
                                          ),
                                        ]
                                      : [],
                                ),
                          ),
                          const SizedBox(width: 8.0),
                          AnimatedRotation(
                            turns: isExpanded ? 0.0 : 0.5,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: CyberTheme.neonCyan.withValues(
                                alpha: isHovered ? 1.0 : 0.7,
                              ),
                              size: 18.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Level activeLevel,
    DroneGameState state,
  ) {
    return CyberCard(
      borderColor: CyberTheme.borderTranslucent,
      backgroundColor: CyberTheme.cardBg,
      borderWidth: 1.0,
      chamferSize: 12.0,
      showAccents: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Brand Title & Dynamic Sector Selection
            _buildLeftTitleSelector(context, activeLevel),

            // Right: Settings Button
            _buildRightSettingsButton(context, activeLevel),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftTitleSelector(BuildContext context, Level activeLevel) {
    final currentSectorText =
        'SECTOR_${activeLevel.id.toString().padLeft(2, '0')}';

    return PopupMenuButton<Level>(
      tooltip: 'Select Sector',
      offset: const Offset(0, 40),
      color: CyberTheme.cardBg,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: CyberTheme.borderTranslucent, width: 1.0),
      ),
      onSelected: (newLevel) {
        _playSound('audio/click.wav');
        ref.read(currentLevelProvider.notifier).setLevel(newLevel);
      },
      itemBuilder: (BuildContext context) {
        final maxUnlocked = ref.read(maxUnlockedLevelProvider);
        return Level.predefinedLevels
            .where((lvl) {
              final lvlNum =
                  int.tryParse(lvl.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
              return lvlNum <= maxUnlocked;
            })
            .map((lvl) {
              final isCurrent = lvl.id == activeLevel.id;
              return PopupMenuItem<Level>(
                value: lvl,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SECTOR ${lvl.id}: ${lvl.title}',
                      style: CyberTheme.fontCode(
                        size: 13.0,
                        color: isCurrent
                            ? CyberTheme.neonCyan
                            : CyberTheme.textMain,
                      ),
                    ),
                    if (isCurrent)
                      const Icon(
                        Icons.check,
                        color: CyberTheme.neonCyan,
                        size: 14.0,
                      ),
                  ],
                ),
              );
            })
            .toList();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DRONESTEP',
              style: CyberTheme.fontHeading(
                size: 18.0,
                color: CyberTheme.textMain,
              ),
            ),
            const SizedBox(height: 2.0),
            Text(
              currentSectorText,
              style: CyberTheme.fontCode(
                size: 14,
                color: CyberTheme.textMuted,
              ).copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightSettingsButton(BuildContext context, Level activeLevel) {
    return InkWell(
      onTap: () {
        _playSound('audio/click.wav');
        _showSettingsDialog(context, activeLevel);
      },
      child: CyberCard(
        borderColor: CyberTheme.neonCyan,
        backgroundColor: Colors.transparent,
        borderWidth: 1.0,
        chamferSize: 6.0,
        showAccents: false,
        child: Container(
          padding: const EdgeInsets.all(8.0),
          child: const Icon(
            Icons.settings,
            color: CyberTheme.neonCyan,
            size: 20.0,
          ),
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, Level activeLevel) {
    showCyberDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isSoundOn = ref.watch(soundOnProvider);
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 24.0,
              ),
              child: CyberCard(
                borderColor: CyberTheme.neonCyan,
                backgroundColor: CyberTheme.cardBg,
                borderWidth: 1.5,
                chamferSize: 16.0,
                showAccents: true,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          const Icon(
                            Icons.settings,
                            color: CyberTheme.neonCyan,
                            size: 22.0,
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            'SYSTEM SETTINGS',
                            style: CyberTheme.fontHeading(
                              size: 16.0,
                              color: CyberTheme.neonCyan,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16.0),

                      // Sound Control
                      InkWell(
                        onTap: () {
                          ref.read(audioControllerProvider).playClick();
                          ref.read(soundOnProvider.notifier).toggle();
                          setDialogState(() {});
                        },
                        child: CyberCard(
                          borderColor: isSoundOn
                              ? CyberTheme.neonGreen
                              : CyberTheme.borderTranslucent,
                          backgroundColor: isSoundOn
                              ? CyberTheme.neonGreen.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderWidth: 1.0,
                          chamferSize: 8.0,
                          showAccents: false,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Icon(
                                  isSoundOn
                                      ? Icons.volume_up
                                      : Icons.volume_off,
                                  color: isSoundOn
                                      ? CyberTheme.neonGreen
                                      : CyberTheme.textMuted,
                                  size: 20.0,
                                ),
                                const SizedBox(width: 12.0),
                                Expanded(
                                  child: Text(
                                    isSoundOn
                                        ? 'AUDIO FEEDBACK: ACTIVE'
                                        : 'AUDIO FEEDBACK: MUTED',
                                    style: CyberTheme.fontCode(
                                      size: 13.0,
                                      color: isSoundOn
                                          ? CyberTheme.neonGreen
                                          : CyberTheme.textMuted,
                                    ).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  width: 8.0,
                                  height: 8.0,
                                  decoration: BoxDecoration(
                                    color: isSoundOn
                                        ? CyberTheme.neonGreen
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSoundOn
                                          ? Colors.transparent
                                          : CyberTheme.textMuted,
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12.0),

                      // Tactical Assistance Section
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(color: CyberTheme.borderTranslucent),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: Text(
                              'TACTICAL ASSISTANCE',
                              style: CyberTheme.fontCode(
                                size: 10.0,
                                color: CyberTheme.textMuted,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: CyberTheme.borderTranslucent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10.0),

                      // Hint & AI Copilot Row
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                _playSound('audio/click.wav');
                                Navigator.pop(context);
                                _showHintDialog(context, activeLevel);
                              },
                              child: CyberCard(
                                borderColor: CyberTheme.neonYellow.withValues(
                                  alpha: 0.7,
                                ),
                                backgroundColor: Colors.transparent,
                                borderWidth: 1.0,
                                chamferSize: 8.0,
                                showAccents: false,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10.0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.lightbulb_outline,
                                        color: CyberTheme.neonYellow,
                                        size: 16.0,
                                      ),
                                      const SizedBox(width: 6.0),
                                      Text(
                                        'HINT BRIEF',
                                        style: CyberTheme.fontCode(
                                          size: 11.5,
                                          color: CyberTheme.neonYellow,
                                        ).copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                _playSound('audio/click.wav');
                                Navigator.pop(context);
                                _showAiCopilotDialog(context, activeLevel);
                              },
                              child: CyberCard(
                                borderColor: CyberTheme.neonPurple.withValues(
                                  alpha: 0.7,
                                ),
                                backgroundColor: Colors.transparent,
                                borderWidth: 1.0,
                                chamferSize: 8.0,
                                showAccents: false,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10.0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.psychology,
                                        color: CyberTheme.neonPurple,
                                        size: 16.0,
                                      ),
                                      const SizedBox(width: 6.0),
                                      Text(
                                        'AI COPILOT',
                                        style: CyberTheme.fontCode(
                                          size: 11.5,
                                          color: CyberTheme.neonPurple,
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
                      const SizedBox(height: 12.0),

                      // System Actions Section
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(color: CyberTheme.borderTranslucent),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: Text(
                              'SYSTEM ACTIONS',
                              style: CyberTheme.fontCode(
                                size: 10.0,
                                color: CyberTheme.textMuted,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: CyberTheme.borderTranslucent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10.0),

                      // Restart Mission
                      InkWell(
                        onTap: () {
                          _playSound('audio/click.wav');
                          _showConfirmDialog(
                            context,
                            title: 'RETRY SIMULATION',
                            message:
                                'Are you sure you want to restart the flight simulation?',
                            onConfirm: () {
                              ref
                                  .read(gameStateProvider.notifier)
                                  .clearProgram();
                              ref
                                  .read(gameStateProvider.notifier)
                                  .resetSimulation();
                              Navigator.pop(context);
                            },
                          );
                        },
                        child: CyberCard(
                          borderColor: CyberTheme.neonPink,
                          backgroundColor: Colors.transparent,
                          borderWidth: 1.0,
                          chamferSize: 8.0,
                          showAccents: false,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.refresh,
                                  color: CyberTheme.neonPink,
                                  size: 20.0,
                                ),
                                const SizedBox(width: 12.0),
                                Text(
                                  'RETRY MISSION',
                                  style: CyberTheme.fontCode(
                                    size: 13.0,
                                    color: CyberTheme.neonPink,
                                  ).copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12.0),

                      // Return to Missions / Home
                      InkWell(
                        onTap: () {
                          _playSound('audio/click.wav');
                          _showConfirmDialog(
                            context,
                            title: 'EXIT TO MISSIONS',
                            message:
                                'Are you sure you want to exit the mission? Unsaved simulation progress will be lost.',
                            onConfirm: () {
                              ref
                                  .read(gameStateProvider.notifier)
                                  .resetSimulation();
                              Navigator.pop(context);
                              ref
                                  .read(appScreenProvider.notifier)
                                  .toScreen(AppScreen.home);
                            },
                          );
                        },
                        child: CyberCard(
                          borderColor: CyberTheme.neonCyan,
                          backgroundColor: Colors.transparent,
                          borderWidth: 1.0,
                          chamferSize: 8.0,
                          showAccents: false,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.home,
                                  color: CyberTheme.neonCyan,
                                  size: 20.0,
                                ),
                                const SizedBox(width: 12.0),
                                Text(
                                  'RETURN TO MISSION LIST',
                                  style: CyberTheme.fontCode(
                                    size: 13.0,
                                    color: CyberTheme.neonCyan,
                                  ).copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20.0),

                      // Close button
                      Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: () {
                            _playSound('audio/click.wav');
                            Navigator.pop(context);
                          },
                          child: CyberCard(
                            borderColor: CyberTheme.neonCyan,
                            backgroundColor: CyberTheme.neonCyan,
                            borderWidth: 0.0,
                            chamferSize: 6.0,
                            showAccents: false,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 10.0,
                              ),
                              child: Text(
                                'CLOSE',
                                style: CyberTheme.fontCode(
                                  size: 12.0,
                                  color: CyberTheme.darkBg,
                                ).copyWith(fontWeight: FontWeight.bold),
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
          },
        );
      },
    );
  }

  void _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showCyberDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24.0,
            vertical: 24.0,
          ),
          child: CyberCard(
            borderColor: CyberTheme.neonPink,
            backgroundColor: CyberTheme.cardBg,
            borderWidth: 1.5,
            chamferSize: 16.0,
            showAccents: true,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: CyberTheme.neonPink,
                          size: 24.0,
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          title,
                          style: CyberTheme.fontHeading(
                            size: 16.0,
                            color: CyberTheme.neonPink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    message,
                    style: CyberTheme.fontBody(
                      size: 14.0,
                      color: CyberTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        InkWell(
                          onTap: () {
                            _playSound('audio/click.wav');
                            Navigator.pop(dialogContext);
                          },
                          child: CyberCard(
                            borderColor: CyberTheme.textMuted,
                            backgroundColor: Colors.transparent,
                            borderWidth: 1.0,
                            chamferSize: 6.0,
                            showAccents: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 10.0,
                              ),
                              child: Text(
                                'CANCEL',
                                style: CyberTheme.fontCode(
                                  size: 12.0,
                                  color: CyberTheme.textMuted,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        InkWell(
                          onTap: () {
                            _playSound('audio/click.wav');
                            Navigator.pop(dialogContext);
                            onConfirm();
                          },
                          child: CyberCard(
                            borderColor: CyberTheme.neonPink,
                            backgroundColor: CyberTheme.neonPink,
                            borderWidth: 0.0,
                            chamferSize: 6.0,
                            showAccents: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 10.0),
                              child: Text(
                                'CONFIRM',
                                style: CyberTheme.fontCode(
                                  size: 12.0,
                                  color: CyberTheme.darkBg,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridArena(DroneGameState state) {
    return LayoutBuilder(
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
          child: CyberCard(
            key: TutorialKeys.gridArena,
            borderColor: CyberTheme.borderTranslucent,
            backgroundColor: CyberTheme.gridBg,
            borderWidth: 1.0,
            chamferSize: 16.0,
            showAccents: false,
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 30.0,
                spreadRadius: -10.0,
              ),
            ],
            child: SizedBox(
              width: width,
              height: height,
              child: ClipPath(
                clipper: CyberCardClipper(chamferSize: 16.0),
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
                                remainingEnergyCells:
                                    state.remainingEnergyCells,
                                pathHistory: state.pathHistory,
                                animationValue: _gridAnimationController.value,
                                hasCargo: state.hasCargo,
                                status: state.status,
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAiCopilotDialog(BuildContext context, Level activeLevel) {
    showCyberDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24.0,
            vertical: 24.0,
          ),
          child: CyberCard(
            borderColor: CyberTheme.neonPurple,
            backgroundColor: CyberTheme.cardBg,
            borderWidth: 1.5,
            chamferSize: 16.0,
            showAccents: true,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.psychology,
                        color: CyberTheme.neonPurple,
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        'AI COPILOT FLIGHT ASSIST',
                        style: CyberTheme.fontHeading(
                          size: 14.5,
                          color: CyberTheme.neonPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    'Analyzing flight matrix for level "${activeLevel.title}"...',
                    style: CyberTheme.fontCode(
                      size: 12.0,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  CyberCard(
                    borderColor: CyberTheme.borderTranslucent,
                    backgroundColor: CyberTheme.darkBg,
                    borderWidth: 1.0,
                    chamferSize: 8.0,
                    showAccents: false,
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        activeLevel.hint ??
                            "No telemetry recommendations available for this zone. Proceed with manual flight program.",
                        style: CyberTheme.fontBody(
                          size: 13.5,
                          color: CyberTheme.textMain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        _playSound('audio/click.wav');
                        Navigator.pop(context);
                      },
                      child: Text(
                        'DISMISS',
                        style: CyberTheme.fontCode(
                          size: 13.0,
                          color: CyberTheme.neonPink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showHintDialog(BuildContext context, Level level) {
    showCyberDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24.0,
            vertical: 24.0,
          ),
          child: CyberCard(
            borderColor: CyberTheme.neonYellow,
            backgroundColor: CyberTheme.cardBg,
            borderWidth: 1.5,
            chamferSize: 16.0,
            showAccents: true,
            child: Consumer(
              builder: (context, ref, child) {
                final unlockedHints = ref.watch(unlockedHintsProvider);
                final remainingKeys = ref.watch(remainingHintsProvider);
                final isUnlocked =
                    unlockedHints.contains(level.id) ||
                    level.id.startsWith('T') ||
                    ((level.id.startsWith('N') || level.id.startsWith('H')) &&
                        (int.tryParse(
                                  level.id.replaceAll(RegExp(r'[^0-9]'), ''),
                                ) ??
                                1) <=
                            5);
                final hasHint = level.hint != null && level.hint!.isNotEmpty;

                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                        Icons.lightbulb,
                                        color: CyberTheme.neonYellow,
                                        size: 22.0,
                                      )
                                      .animate(
                                        onPlay: (c) => c.repeat(reverse: true),
                                      )
                                      .scale(
                                        duration: 800.ms,
                                        end: const Offset(1.1, 1.1),
                                      ),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    'TACTICAL BRIEFING',
                                    style: CyberTheme.fontHeading(
                                      size: 16.0,
                                      color: CyberTheme.neonYellow,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'KEYS: $remainingKeys',
                              style: CyberTheme.fontCode(
                                size: 12.0,
                                color: CyberTheme.neonYellow,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16.0),
                      // Objective Section
                      Text(
                        'MISSION OBJECTIVE',
                        style:
                            CyberTheme.fontCode(
                              size: 11.0,
                              color: CyberTheme.neonPink,
                            ).copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                      ),
                      const SizedBox(height: 6.0),
                      CyberCard(
                        borderColor: CyberTheme.neonPink.withValues(
                          alpha: 0.15,
                        ),
                        backgroundColor: Colors.black26,
                        borderWidth: 1.0,
                        chamferSize: 8.0,
                        showAccents: false,
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Text(
                            level.description.toUpperCase(),
                            style: CyberTheme.fontBody(
                              size: 13.0,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      // Tactical Hint Section
                      Text(
                        'TACTICAL TELEMETRY HINT',
                        style:
                            CyberTheme.fontCode(
                              size: 11.0,
                              color: CyberTheme.neonCyan,
                            ).copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                      ),
                      const SizedBox(height: 6.0),
                      if (!hasHint)
                        CyberCard(
                          borderColor: CyberTheme.borderTranslucent,
                          backgroundColor: CyberTheme.darkBg,
                          borderWidth: 1.0,
                          chamferSize: 8.0,
                          showAccents: false,
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Text(
                              "No telemetry recommendations available for this zone. Proceed with manual flight program.",
                              style: CyberTheme.fontBody(
                                size: 13.0,
                                color: CyberTheme.textMain,
                              ),
                            ),
                          ),
                        )
                      else if (isUnlocked)
                        CyberCard(
                          borderColor: CyberTheme.neonCyan,
                          backgroundColor: CyberTheme.darkBg,
                          borderWidth: 1.0,
                          chamferSize: 8.0,
                          showAccents: false,
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Text(
                              level.hint!,
                              style: CyberTheme.fontBody(
                                size: 13.0,
                                color: CyberTheme.textMain,
                              ),
                            ),
                          ),
                        ).animate().fadeIn(duration: 400.ms)
                      else
                        CyberCard(
                          borderColor: CyberTheme.neonPink.withValues(
                            alpha: 0.5,
                          ),
                          backgroundColor: Colors.black38,
                          borderWidth: 1.0,
                          chamferSize: 8.0,
                          showAccents: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 16.0,
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.lock,
                                      color: CyberTheme.neonPink,
                                      size: 18.0,
                                    ),
                                    const SizedBox(width: 8.0),
                                    Text(
                                      'ENCRYPTED FLIGHT PATH',
                                      style: CyberTheme.fontCode(
                                        size: 12.0,
                                        color: CyberTheme.neonPink,
                                      ).copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12.0),
                                InkWell(
                                  onTap: remainingKeys > 0
                                      ? () {
                                          _playSound('audio/click.wav');
                                          ref
                                              .read(
                                                unlockedHintsProvider.notifier,
                                              )
                                              .unlockHint(level.id);
                                        }
                                      : null,
                                  child: CyberCard(
                                    borderColor: remainingKeys > 0
                                        ? CyberTheme.neonGreen
                                        : CyberTheme.textMuted,
                                    backgroundColor: remainingKeys > 0
                                        ? CyberTheme.neonGreen.withValues(
                                            alpha: 0.1,
                                          )
                                        : Colors.transparent,
                                    borderWidth: 1.0,
                                    chamferSize: 6.0,
                                    showAccents: false,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                        vertical: 8.0,
                                      ),
                                      child: Text(
                                        remainingKeys > 0
                                            ? 'DECRYPT HINT (COST: 1 KEY)'
                                            : 'DECRYPT LOCKED (1 KEY REQUIRED)',
                                        style: CyberTheme.fontCode(
                                          size: 12.0,
                                          color: remainingKeys > 0
                                              ? CyberTheme.neonGreen
                                              : CyberTheme.textMuted,
                                        ).copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20.0),
                      // Close button
                      Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: () {
                            _playSound('audio/click.wav');
                            Navigator.pop(context);
                          },
                          child: CyberCard(
                            borderColor: CyberTheme.neonYellow,
                            backgroundColor: CyberTheme.neonYellow,
                            borderWidth: 0.0,
                            chamferSize: 6.0,
                            showAccents: false,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 10.0,
                              ),
                              child: Text(
                                'DISMISS',
                                style: CyberTheme.fontCode(
                                  size: 12.0,
                                  color: Colors.black,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnifiedHud(
    BuildContext context,
    Level activeLevel,
    DroneGameState state, {
    bool isFloating = false,
  }) {
    final batteryPercentage = (state.battery / activeLevel.initialBattery)
        .clamp(0.0, 1.0);
    Color batteryColor = CyberTheme.neonGreen;
    if (batteryPercentage < 0.3) {
      batteryColor = CyberTheme.neonPink;
    } else if (batteryPercentage < 0.6) {
      batteryColor = CyberTheme.neonYellow;
    }

    final isNarrow = MediaQuery.sizeOf(context).width < 500;
    Widget hudContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Telemetry Readout Grid
        Row(
          children: [
            Expanded(
              child: _buildHudTelemetryItem(
                context,
                'POWER.SYS',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 5-segment LED Cyberpunk Power Bar
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (index) {
                            final double threshold = (index + 1) / 5.0;
                            final bool active = batteryPercentage >= threshold;
                            Color segColor = active
                                ? batteryColor
                                : Colors.white12;
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 0.5,
                              ),
                              width: 5.5,
                              height: 15.0,
                              decoration: BoxDecoration(
                                color: segColor,
                                boxShadow: active
                                    ? [
                                        BoxShadow(
                                          color: segColor.withValues(
                                            alpha: 0.4,
                                          ),
                                          blurRadius: 1.5,
                                        ),
                                      ]
                                    : [],
                              ),
                            );
                          }),
                        ),
                        const SizedBox(width: 6.0),
                        Text(
                          '${(batteryPercentage * 100).round()}%',
                          style: CyberTheme.fontCode(
                            size: 15.0,
                            color: batteryColor,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      state.status == GameStatus.crashed ? 'OFFLINE' : 'ACTIVE',
                      style: CyberTheme.fontCode(
                        size: 13,
                        color: state.status == GameStatus.crashed
                            ? CyberTheme.neonPink
                            : CyberTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                isNarrow: isNarrow,
                accentColor: batteryColor,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _buildHudTelemetryItem(
                context,
                'ALTITUDE.TEL',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.height,
                          color: CyberTheme.neonCyan,
                          size: isNarrow ? 16.0 : 18.0,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          '${state.droneHeight}m',
                          style: CyberTheme.fontCode(
                            size: 15.0,
                            color: CyberTheme.textMain,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      '0 - 8m',
                      style: CyberTheme.fontCode(
                        size: 13.0,
                        color: CyberTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                isNarrow: isNarrow,
                accentColor: CyberTheme.neonCyan,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _buildHudTelemetryItem(
                context,
                'MEM.RATIO',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.grid_view,
                          color: CyberTheme.neonYellow,
                          size: isNarrow ? 16.0 : 18.0,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          '${state.totalBlockCount}/${activeLevel.star3Target}',
                          style: CyberTheme.fontCode(
                            size: 15.0,
                            color: CyberTheme.neonYellow,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      state.totalBlockCount <= activeLevel.star3Target
                          ? 'NOMINAL'
                          : 'WARNING',
                      style: CyberTheme.fontCode(
                        size: 13.0,
                        color: state.totalBlockCount <= activeLevel.star3Target
                            ? CyberTheme.neonYellow
                            : CyberTheme.neonPink,
                      ),
                    ),
                  ],
                ),
                isNarrow: isNarrow,
                accentColor: CyberTheme.neonYellow,
              ),
            ),
          ],
        ),
      ],
    );

    if (isFloating) {
      hudContent = ClipPath(
        clipper: CyberCardClipper(chamferSize: 12.0),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: hudContent,
        ),
      );
    }

    return CyberCard(
      key: isFloating ? null : TutorialKeys.telemetry,
      borderColor: isFloating
          ? CyberTheme.neonCyan.withValues(alpha: 0.3)
          : CyberTheme.borderTranslucent,
      backgroundColor: isFloating
          ? Colors.black.withValues(alpha: 0.65)
          : CyberTheme.cardBg,
      borderWidth: 1.2,
      chamferSize: 12.0,
      showAccents: false,
      shadows: [
        BoxShadow(
          color: (isFloating ? CyberTheme.neonCyan : Colors.black).withValues(
            alpha: 0.08,
          ),
          blurRadius: 10.0,
        ),
      ],
      child: hudContent,
    );
  }

  Widget _buildHudTelemetryItem(
    BuildContext context,
    String tag,
    Widget valueWidget, {
    required bool isNarrow,
    required Color accentColor,
  }) {
    return CyberCard(
      borderColor: accentColor.withValues(alpha: 0.6),
      backgroundColor: Colors.black.withValues(alpha: 0.45),
      borderWidth: 1.2,
      chamferSize: 8.0,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isNarrow ? 8.0 : 10.0,
          vertical: 6.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                tag,
                style: CyberTheme.fontCode(
                  size: isNarrow ? 13 : 15,
                  color: CyberTheme.textMuted,
                ).copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(height: 3.0),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: valueWidget,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepProcess(DroneGameState state) {
    if (state.vmInstructions.isEmpty) return const SizedBox.shrink();

    IconData getIcon(VMInstruction inst) {
      if (inst.type == InstructionType.executeAction && inst.action != null) {
        return inst.action!.icon;
      } else if (inst.type == InstructionType.jumpIfNot) {
        return Icons.help_outline;
      } else {
        return Icons.loop;
      }
    }

    String getLabel(VMInstruction inst) {
      if (inst.type == InstructionType.executeAction && inst.action != null) {
        return inst.action!.shortLabel;
      } else if (inst.type == InstructionType.jumpIfNot &&
          inst.condition != null) {
        return 'IF: ${inst.condition!.shortLabel}';
      } else {
        return 'LOOP';
      }
    }

    return Container(
      height: 48.0,
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: ListView.builder(
        controller: _stepScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: state.vmInstructions.length,
        itemBuilder: (context, index) {
          final inst = state.vmInstructions[index];
          final isActive = index == state.pc;
          final isExecuted = index < state.pc;
          final isFailed = isActive && state.status == GameStatus.crashed;

          final icon = getIcon(inst);
          final label = getLabel(inst);

          Color cardBg;
          Color contentColor;
          Border? border;

          if (isFailed) {
            cardBg = CyberTheme.neonPink.withValues(alpha: 0.18);
            contentColor = CyberTheme.neonPink;
            border = Border.all(color: CyberTheme.neonPink, width: 1.0);
          } else if (isActive) {
            cardBg = CyberTheme.neonGreen.withValues(alpha: 0.18);
            contentColor = CyberTheme.neonGreen;
            border = Border.all(color: CyberTheme.neonGreen, width: 1.0);
          } else if (isExecuted) {
            cardBg = CyberTheme.neonGreen.withValues(alpha: 0.05);
            contentColor = CyberTheme.neonGreen.withValues(alpha: 0.6);
            border = Border.all(
              color: CyberTheme.neonGreen.withValues(alpha: 0.25),
              width: 0.5,
            );
          } else {
            cardBg = Colors.white.withValues(alpha: 0.05);
            contentColor = CyberTheme.textMain;
            border = Border.all(
              color: CyberTheme.borderTranslucent.withValues(alpha: 0.3),
              width: 0.5,
            );
          }

          final stepCard = AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 8.0,
            ),
            decoration: BoxDecoration(
              color: cardBg,
              border: border,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color:
                            (isFailed
                                    ? CyberTheme.neonPink
                                    : CyberTheme.neonGreen)
                                .withValues(alpha: 0.4),
                        blurRadius: 8.0,
                        spreadRadius: -1.0,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4.0,
                    vertical: 1.0,
                  ),
                  decoration: BoxDecoration(
                    color: contentColor.withValues(alpha: 0.15),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: CyberTheme.fontCode(
                      size: 12.0,
                      color: contentColor,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 5.0),
                Icon(icon, size: 15.0, color: contentColor),
                const SizedBox(width: 4.0),
                Text(
                  label,
                  style: CyberTheme.fontCode(size: 13.0, color: contentColor)
                      .copyWith(
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                ),
                if (inst.loopIteration != null && inst.loopTotal != null) ...[
                  const SizedBox(width: 5.0),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4.0,
                      vertical: 1.0,
                    ),
                    decoration: BoxDecoration(
                      color: (isActive ? CyberTheme.neonYellow : contentColor)
                          .withValues(alpha: 0.15),
                      border: Border.all(
                        color: (isActive ? CyberTheme.neonYellow : contentColor)
                            .withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(3.0),
                    ),
                    child: Text(
                      '${inst.loopIteration}/${inst.loopTotal}',
                      style: CyberTheme.fontCode(
                        size: 9.5,
                        color: isActive ? CyberTheme.neonYellow : contentColor,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          );

          if (index < state.vmInstructions.length - 1) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                stepCard,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
                  child: Icon(
                    Icons.chevron_right,
                    size: 16.0,
                    color: isActive || isExecuted
                        ? CyberTheme.neonGreen.withValues(alpha: 0.6)
                        : CyberTheme.textMuted.withValues(alpha: 0.3),
                  ),
                ),
              ],
            );
          } else {
            return stepCard;
          }
        },
      ),
    );
  }

  void _scrollToActiveStep(int pc) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_stepScrollController.hasClients) return;
      final double itemWidth = 115.0;
      final int targetPc = math.max(0, pc);
      final double position = targetPc * itemWidth;
      final double viewportWidth =
          _stepScrollController.position.viewportDimension;
      final double targetOffset =
          position - (viewportWidth / 2.0) + (itemWidth / 2.0);
      final double maxScroll = _stepScrollController.position.maxScrollExtent;

      _stepScrollController.animateTo(
        math.max(0.0, math.min(targetOffset, maxScroll)),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Widget _buildFloatingControls(BuildContext context, DroneGameState state) {
    final notifier = ref.read(gameStateProvider.notifier);
    final isRunning = state.status == GameStatus.running;
    final isNarrow = MediaQuery.sizeOf(context).width < 500;

    return CyberCard(
      borderColor: CyberTheme.borderTranslucent.withValues(alpha: 0.3),
      backgroundColor: Colors.black.withValues(alpha: 0.45),
      borderWidth: 1.0,
      chamferSize: 16.0,
      showAccents: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStepProcess(state),
            const SizedBox(height: 10.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Play/Pause button
                    InkWell(
                      onTap: () {
                        _playSound('audio/click.wav');
                        if (isRunning) {
                          notifier.pauseSimulation();
                        } else {
                          notifier.runSimulation();
                        }
                      },
                      child: CyberCard(
                        borderColor: isRunning
                            ? CyberTheme.neonPink
                            : CyberTheme.neonCyan,
                        backgroundColor: isRunning
                            ? CyberTheme.neonPink
                            : CyberTheme.neonCyan,
                        borderWidth: 0.0,
                        chamferSize: 6.0,
                        showAccents: false,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isNarrow ? 8.0 : 18.0,
                            vertical: isNarrow ? 8.0 : 12.0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isRunning ? Icons.pause : Icons.play_arrow,
                                size: isNarrow ? 18.0 : 20.0,
                                color: CyberTheme.darkBg,
                              ),
                              const SizedBox(width: 4.0),
                              Text(
                                isRunning ? 'PAUSE' : 'RESUME',
                                style: CyberTheme.fontCode(
                                  size: isNarrow ? 12.0 : 14.0,
                                  color: CyberTheme.darkBg,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isNarrow ? 6.0 : 10.0),
                    // Reset/Stop button
                    InkWell(
                      onTap: () {
                        _playSound('audio/click.wav');
                        notifier.resetSimulation();
                      },
                      child: CyberCard(
                        borderColor: Colors.white.withValues(alpha: 0.15),
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        borderWidth: 1.0,
                        chamferSize: 6.0,
                        showAccents: false,
                        child: Padding(
                          padding: EdgeInsets.all(isNarrow ? 8.0 : 10.0),
                          child: Icon(
                            Icons.stop,
                            size: isNarrow ? 20.0 : 22.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Speed controls
                CyberCard(
                  borderColor: CyberTheme.borderTranslucent.withValues(
                    alpha: 0.2,
                  ),
                  backgroundColor: Colors.black.withValues(alpha: 0.3),
                  borderWidth: 1.0,
                  chamferSize: 6.0,
                  showAccents: false,
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFloatingSpeedSegment(
                          context,
                          notifier,
                          1.0,
                          '1X',
                          state.speedMultiplier,
                        ),
                        _buildFloatingSpeedSegment(
                          context,
                          notifier,
                          2.0,
                          '2X',
                          state.speedMultiplier,
                        ),
                        _buildFloatingSpeedSegment(
                          context,
                          notifier,
                          4.0,
                          '4X',
                          state.speedMultiplier,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingSpeedSegment(
    BuildContext context,
    GameStateNotifier notifier,
    double speed,
    String label,
    double activeSpeed,
  ) {
    final isActive = activeSpeed == speed;
    final isNarrow = MediaQuery.sizeOf(context).width < 500;

    return GestureDetector(
      onTap: () {
        _playSound('audio/click.wav');
        notifier.setSpeed(speed);
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isNarrow ? 8.0 : 12.0,
          vertical: 8.0,
        ),
        decoration: BoxDecoration(
          color: isActive ? CyberTheme.neonCyan : Colors.transparent,
        ),
        child: Text(
          label,
          style: CyberTheme.fontCode(
            size: isNarrow ? 11.5 : 13.0,
            color: isActive ? CyberTheme.darkBg : CyberTheme.textMuted,
          ).copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildCongratsSplash() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          color: CyberTheme.darkBg.withValues(alpha: 0.8),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                              width: 160.0,
                              height: 160.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: CyberTheme.neonGreen.withValues(
                                    alpha: 0.2,
                                  ),
                                  width: 1.5,
                                ),
                              ),
                            )
                            .animate(onPlay: (controller) => controller.repeat())
                            .scale(duration: 800.ms, curve: Curves.elasticOut)
                            .rotate(duration: 6.seconds, end: 1.0),

                        Container(
                              width: 140.0,
                              height: 140.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: CyberTheme.neonCyan.withValues(
                                    alpha: 0.25,
                                  ),
                                  width: 1.0,
                                  style: BorderStyle.solid,
                                ),
                              ),
                            )
                            .animate(onPlay: (controller) => controller.repeat())
                            .scale(duration: 600.ms, curve: Curves.elasticOut)
                            .rotate(duration: 4.seconds, end: -1.0),

                        Container(
                              padding: const EdgeInsets.all(20.0),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: CyberTheme.neonGreen.withValues(alpha: 0.15),
                                boxShadow: [
                                  BoxShadow(
                                    color: CyberTheme.neonGreen.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 24.0,
                                    spreadRadius: 2.0,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.emoji_events_outlined,
                                color: CyberTheme.neonGreen,
                                size: 56.0,
                              ),
                            )
                            .animate()
                            .scale(duration: 500.ms, curve: Curves.elasticOut)
                            .then(delay: 200.ms)
                            .shake(hz: 3, curve: Curves.easeInOut),
                      ],
                    ),
                    const SizedBox(height: 32.0),
                    Text(
                          'CONGRATULATIONS!',
                          textAlign: TextAlign.center,
                          style:
                              CyberTheme.fontHeading(
                                size: 24.0,
                                color: CyberTheme.neonGreen,
                              ).copyWith(
                                letterSpacing: 4.0,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: CyberTheme.neonGreen.withValues(
                                      alpha: 0.8,
                                    ),
                                    blurRadius: 20.0,
                                  ),
                                  Shadow(
                                    color: CyberTheme.neonCyan.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 40.0,
                                  ),
                                ],
                              ),
                        )
                        .animate()
                        .scale(duration: 600.ms, curve: Curves.elasticOut)
                        .then(delay: 300.ms)
                        .shimmer(duration: 1.2.seconds, color: CyberTheme.neonCyan),

                    const SizedBox(height: 12.0),
                    Text(
                          'MISSION GOAL ACCOMPLISHED',
                          style:
                              CyberTheme.fontCode(
                                size: 15.0,
                                color: CyberTheme.neonCyan,
                              ).copyWith(
                                letterSpacing: 2.0,
                                fontWeight: FontWeight.bold,
                              ),
                        )
                        .animate()
                        .fadeIn(delay: 350.ms, duration: 450.ms)
                        .slideY(
                          begin: 0.5,
                          end: 0.0,
                          duration: 400.ms,
                          curve: Curves.easeOutQuad,
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Level? _findNextLevel(Level current) {
    final prefix = current.id.replaceAll(RegExp(r'[0-9]'), '');
    final numStr = current.id.replaceAll(RegExp(r'[^0-9]'), '');
    final currentNum = int.tryParse(numStr) ?? 1;
    final nextId = '$prefix${currentNum + 1}';

    if (prefix == 'T') {
      for (final l in Level.tutorialMissions) {
        if (l.id == nextId) return l;
      }
      if (current.id == 'T3') {
        for (final l in Level.predefinedLevels) {
          if (l.id == 'N1') return l;
        }
      }
    } else {
      for (final l in Level.predefinedLevels) {
        if (l.id == nextId) return l;
      }
    }
    return null;
  }

  Widget _buildSuccessOverlay(DroneGameState state) {
    int stars = 1;
    if (state.totalBlockCount < state.level.star3Target) {
      stars = 4;
    } else if (state.totalBlockCount <= state.level.star3Target) {
      stars = 3;
    } else if (state.totalBlockCount <= state.level.star3Target + 3) {
      stars = 2;
    }
    // Tutorial levels guarantee at least 3 stars
    if (state.level.tutorialSteps != null && stars < 3) stars = 3;
    stars = math.min(stars, state.level.maxStars);

    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          color: CyberTheme.darkBg.withValues(alpha: 0.75),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                vertical: 24.0,
                horizontal: 16.0,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
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
                            size: 24.0,
                            color: CyberTheme.neonGreen,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 200.ms)
                        .slideY(begin: 0.2, end: 0.0),
                    const SizedBox(height: 6.0),
                    Text(
                      'Target platform reached successfully.',
                      style: CyberTheme.fontBody(
                        size: 15.0,
                        color: CyberTheme.textMuted,
                      ),
                    ).animate().fadeIn(delay: 350.ms),
                    const SizedBox(height: 20.0),
                    // Premium flat Star display (4th star is special cyan diamond)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(state.level.maxStars, (index) {
                        final isLit = index < stars;
                        final isFourthStar = index == 3;
                        final litColor = isFourthStar
                            ? CyberTheme
                                  .neonCyan // 4th star = special cyan
                            : CyberTheme.neonYellow; // 1-3 stars = gold
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child:
                              Icon(
                                isLit
                                    ? (isFourthStar ? Icons.diamond : Icons.star)
                                    : (isFourthStar
                                          ? Icons.diamond_outlined
                                          : Icons.star_border),
                                size: isFourthStar ? 30.0 : 28.0,
                                color: isLit
                                    ? litColor
                                    : CyberTheme.textMuted.withValues(alpha: 0.2),
                                shadows: isLit && isFourthStar
                                    ? [
                                        Shadow(
                                          color: CyberTheme.neonCyan.withValues(
                                            alpha: 0.7,
                                          ),
                                          blurRadius: 12,
                                        ),
                                      ]
                                    : null,
                              ).animate().scale(
                                delay: (450 + index * 100).ms,
                                duration: 350.ms,
                                curve: Curves.easeOutBack,
                              ),
                        );
                      }),
                    ),
                    if (ref.watch(gameModeProvider) == GameMode.daily) ...[
                      const SizedBox(height: 16.0),
                      CyberCard(
                        borderColor: CyberTheme.neonYellow,
                        backgroundColor: CyberTheme.neonYellow.withValues(
                          alpha: 0.05,
                        ),
                        borderWidth: 1.0,
                        chamferSize: 6.0,
                        showAccents: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 8.0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.battery_charging_full,
                                color: CyberTheme.neonYellow,
                                size: 16.0,
                              ),
                              const SizedBox(width: 6.0),
                              Text(
                                '+10 PILOT ENERGY RECLAIMED',
                                style: CyberTheme.fontCode(
                                  size: 12.0,
                                  color: CyberTheme.neonYellow,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 600.ms).scale(),
                    ],
                    if (_earnedDiamondThisRun) ...[
                      const SizedBox(height: 12.0),
                      CyberCard(
                        borderColor: CyberTheme.neonCyan,
                        backgroundColor: CyberTheme.neonCyan.withValues(
                          alpha: 0.05,
                        ),
                        borderWidth: 1.0,
                        chamferSize: 6.0,
                        showAccents: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 8.0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.diamond,
                                color: CyberTheme.neonCyan,
                                size: 16.0,
                              ),
                              const SizedBox(width: 6.0),
                              Text(
                                '+5 OPTIMAL FLOW RECLAIMED',
                                style: CyberTheme.fontCode(
                                  size: 12.0,
                                  color: CyberTheme.neonCyan,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 700.ms).scale(),
                    ],
                    const SizedBox(height: 28.0),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InkWell(
                              onTap: () {
                                _playSound('audio/click.wav');
                                ref.read(gameStateProvider.notifier).clearProgram();
                                ref
                                    .read(gameStateProvider.notifier)
                                    .resetSimulation();
                              },
                              child: CyberCard(
                                borderColor: CyberTheme.textMuted,
                                backgroundColor: Colors.transparent,
                                borderWidth: 1.0,
                                chamferSize: 8.0,
                                showAccents: false,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 12.0,
                                  ),
                                  child: Text(
                                    'REPLAY',
                                    style: CyberTheme.fontCode(
                                      size: 13.0,
                                      color: CyberTheme.textMain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10.0),
                            InkWell(
                              onTap: () {
                                _playSound('audio/click.wav');
                                if (state.level.id == 'T3') {
                                  ref
                                      .read(seenTutorialMissionsProvider.notifier)
                                      .markAsSeen();
                                }
                                ref
                                    .read(gameStateProvider.notifier)
                                    .resetSimulation();
                                ref
                                    .read(appScreenProvider.notifier)
                                    .toScreen(AppScreen.home);
                              },
                              child: CyberCard(
                                borderColor: CyberTheme.neonCyan,
                                backgroundColor: Colors.transparent,
                                borderWidth: 1.0,
                                chamferSize: 8.0,
                                showAccents: false,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 12.0,
                                  ),
                                  child: Text(
                                    'MISSIONS',
                                    style: CyberTheme.fontCode(
                                      size: 13.0,
                                      color: CyberTheme.neonCyan,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_findNextLevel(state.level) != null) ...[
                          const SizedBox(height: 12.0),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              InkWell(
                                onTap: () {
                                  _playSound('audio/click.wav');
                                  final nextLvl = _findNextLevel(state.level);
                                  if (nextLvl == null) return;

                                  if (state.level.id == 'T3') {
                                    ref
                                        .read(seenTutorialMissionsProvider.notifier)
                                        .markAsSeen();
                                    ref
                                        .read(gameModeProvider.notifier)
                                        .setMode(GameMode.normal);
                                    ref
                                        .read(currentLevelProvider.notifier)
                                        .setLevel(nextLvl);
                                    ref.read(gameStateProvider.notifier).clearProgram();
                                    ref
                                        .read(gameStateProvider.notifier)
                                        .resetSimulation();
                                    ref
                                        .read(appScreenProvider.notifier)
                                        .toScreen(AppScreen.home);
                                  } else {
                                    ref
                                        .read(currentLevelProvider.notifier)
                                        .setLevel(nextLvl);
                                    ref.read(gameStateProvider.notifier).clearProgram();
                                    ref
                                        .read(gameStateProvider.notifier)
                                        .resetSimulation();
                                  }
                                },
                                child: CyberCard(
                                  borderColor: CyberTheme.neonGreen,
                                  backgroundColor: CyberTheme.neonGreen,
                                  borderWidth: 0.0,
                                  chamferSize: 8.0,
                                  showAccents: false,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24.0,
                                      vertical: 12.0,
                                    ),
                                    child: Text(
                                      'NEXT MISSION',
                                      style: CyberTheme.fontCode(
                                        size: 13.0,
                                        color: CyberTheme.darkBg,
                                      ).copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ).animate().fadeIn(delay: 800.ms),
                  ],
                ),
              ),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                vertical: 24.0,
                horizontal: 24.0,
              ),
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
                      size: 24.0,
                      color: CyberTheme.neonPink,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    state.message ?? 'Unknown flight failure encountered.',
                    style: CyberTheme.fontBody(
                      size: 15.0,
                      color: CyberTheme.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 24.0),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          _playSound('audio/click.wav');
                          ref
                              .read(gameStateProvider.notifier)
                              .resetSimulation();
                          ref
                              .read(appScreenProvider.notifier)
                              .toScreen(AppScreen.home);
                        },
                        child: CyberCard(
                          borderColor: CyberTheme.neonCyan,
                          backgroundColor: Colors.transparent,
                          borderWidth: 1.0,
                          chamferSize: 8.0,
                          showAccents: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 12.0,
                            ),
                            child: Text(
                              'MISSIONS',
                              style: CyberTheme.fontCode(
                                size: 13.0,
                                color: CyberTheme.neonCyan,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      InkWell(
                        onTap: () {
                          _playSound('audio/click.wav');
                          ref.read(gameStateProvider.notifier).clearProgram();
                          ref
                              .read(gameStateProvider.notifier)
                              .resetSimulation();
                        },
                        child: CyberCard(
                          borderColor: CyberTheme.neonPink,
                          backgroundColor: CyberTheme.neonPink,
                          borderWidth: 0.0,
                          chamferSize: 8.0,
                          showAccents: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18.0,
                              vertical: 12.0,
                            ),
                            child: Text(
                              'RESET & RETRY',
                              style: CyberTheme.fontCode(
                                size: 13.0,
                                color: CyberTheme.darkBg,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _CargoBoxWidgetState extends State<CargoBoxWidget>
    with SingleTickerProviderStateMixin {
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
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInBack));
    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

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
            child: Transform.scale(scale: scale, child: child),
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
    final cargoPulse =
        1.0 + 0.1 * math.sin((animationValue + 0.5) * 2 * math.pi);
    final cargoPulsePaint = Paint()
      ..color = CyberTheme.neonYellow.withValues(
        alpha: 0.25 * (2.0 - cargoPulse),
      )
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
    canvas.drawRRect(
      RRect.fromRectAndRadius(cargoRect, const Radius.circular(5.0)),
      cargoPaint,
    );

    final cargoBorder = Paint()
      ..color = CyberTheme.neonYellow
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(cargoRect, const Radius.circular(5.0)),
      cargoBorder,
    );

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

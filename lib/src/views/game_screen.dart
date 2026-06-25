import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:async';
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
import 'helipad_widget.dart';
import 'command_panel.dart';
import 'cockpit_tab_painter.dart';
import 'cyber_card.dart';
import 'cyber_dialog.dart';
import 'mission_preview_map.dart';
import '../models/tutorial_keys.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'banner_ad_widget.dart';
import '../providers/ad_helper.dart';

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

  RewardedInterstitialAd? _rewardedInterstitialAd;
  bool _isRewardedInterstitialAdLoaded = false;

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoaded = false;

  int _adCountdownSeconds = 3;
  bool _showAdCountdown = false;
  Timer? _adCountdownTimer;

  @override
  void initState() {
    super.initState();
    _stepScrollController = ScrollController();
    _gridAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _loadRewardedInterstitialAd();
    _loadRewardedAd();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _delayedStatus = ref.read(gameStateProvider).status;
        });
      }
    });
  }

  void _loadRewardedInterstitialAd() {
    RewardedInterstitialAd.load(
      adUnitId: AdHelper.rewardedInterstitialAdUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedInterstitialAd = ad;
          _isRewardedInterstitialAdLoaded = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              if (mounted) {
                ref.read(audioControllerProvider).pauseForAd();
              }
            },
            onAdDismissedFullScreenContent: (ad) {
              if (mounted) {
                ref.read(audioControllerProvider).resumeAfterAd();
                ad.dispose();
                _loadRewardedInterstitialAd();
              } else {
                ad.dispose();
              }
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              if (mounted) {
                ref.read(audioControllerProvider).resumeAfterAd();
                ad.dispose();
                _loadRewardedInterstitialAd();
              } else {
                ad.dispose();
              }
            },
          );
        },
        onAdFailedToLoad: (err) {
          debugPrint('RewardedInterstitialAd failed to load: $err');
          _isRewardedInterstitialAdLoaded = false;
        },
      ),
    );
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: AdHelper.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('RewardedAd loaded successfully.');
          _rewardedAd = ad;
          _isRewardedAdLoaded = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              if (mounted) {
                ref.read(audioControllerProvider).pauseForAd();
              }
            },
            onAdDismissedFullScreenContent: (ad) {
              if (mounted) {
                ref.read(audioControllerProvider).resumeAfterAd();
                ad.dispose();
                _loadRewardedAd();
              } else {
                ad.dispose();
              }
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              if (mounted) {
                ref.read(audioControllerProvider).resumeAfterAd();
                ad.dispose();
                _loadRewardedAd();
              } else {
                ad.dispose();
              }
            },
          );
        },
        onAdFailedToLoad: (err) {
          debugPrint(
            'RewardedAd failed to load: ${err.message} (code: ${err.code})',
          );
          _isRewardedAdLoaded = false;
        },
      ),
    );
  }

  void _showHintRewardDialog() {
    showCyberDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: CyberCard(
            borderColor: CyberTheme.neonYellow,
            backgroundColor: CyberTheme.darkBg,
            chamferSize: 16.0,
            showAccents: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'HINT REWARD',
                    style: CyberTheme.fontHeading(
                      size: 18.0,
                      color: CyberTheme.neonYellow,
                    ).copyWith(letterSpacing: 2.0),
                  ),
                  const SizedBox(height: 24.0),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CyberTheme.neonYellow.withValues(alpha: 0.1),
                          boxShadow: [
                            BoxShadow(
                              color: CyberTheme.neonYellow.withValues(
                                alpha: 0.2,
                              ),
                              blurRadius: 20.0,
                              spreadRadius: 5.0,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.lightbulb_outline,
                        color: CyberTheme.neonYellow,
                        size: 48,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    '+1',
                    style: CyberTheme.fontHeading(
                      size: 32.0,
                      color: CyberTheme.neonYellow,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24.0),
                  SizedBox(
                    width: 140,
                    child: InkWell(
                      onTap: () {
                        _playSound('audio/click.wav');
                        Navigator.pop(dialogContext);
                      },
                      child: CyberCard(
                        borderColor: CyberTheme.neonYellow,
                        backgroundColor: CyberTheme.neonYellow.withValues(
                          alpha: 0.1,
                        ),
                        chamferSize: 8.0,
                        showAccents: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Center(
                            child: Text(
                              'CLAIM',
                              style: CyberTheme.fontCode(
                                size: 12.0,
                                color: CyberTheme.neonYellow,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
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
  }

  void _showRewardedInterstitialAd() {
    if (_isRewardedInterstitialAdLoaded && _rewardedInterstitialAd != null) {
      _rewardedInterstitialAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          debugPrint('User earned reward: ${reward.amount} ${reward.type}');
        },
      );
    } else {
      debugPrint('RewardedInterstitialAd not loaded yet.');
    }
  }

  void _startAdCountdown() {
    _adCountdownTimer?.cancel();
    setState(() {
      _showAdCountdown = true;
      _adCountdownSeconds = 3;
    });

    _adCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_adCountdownSeconds > 1) {
        setState(() {
          _adCountdownSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _showAdCountdown = false;
          _delayedStatus = GameStatus.success;
        });
        _showRewardedInterstitialAd();
      }
    });
  }

  @override
  void dispose() {
    _gridAnimationController.dispose();
    _stepScrollController.dispose();
    _rewardedInterstitialAd?.dispose();
    _rewardedAd?.dispose();
    _adCountdownTimer?.cancel();
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

    ref.listen<bool>(humOnProvider, (previous, next) {
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
          } else if (!next.level.id.startsWith('S')) {
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
                  });
                  if (_isRewardedInterstitialAdLoaded &&
                      _rewardedInterstitialAd != null) {
                    _startAdCountdown();
                  } else {
                    setState(() {
                      _delayedStatus = GameStatus.success;
                    });
                  }
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
                                  final double currentHudHeight = isExpanded
                                      ? 80.0
                                      : 128.0;

                                  final targetPanelHeight = isExpanded
                                      ? (height * 0.58)
                                      : 66.0;

                                  // Compute dynamic grid height in editor mode
                                  final double gridHeight = isExpanded
                                      ? 100.0
                                      : math.max(
                                          140.0,
                                          height -
                                              toggleHeight -
                                              currentHudHeight -
                                              targetPanelHeight -
                                              24.0,
                                        );

                                  // Ensure panelHeight adjusts to fit exactly within screen height limit
                                  final double panelHeight = isExpanded
                                      ? (height -
                                            gridHeight -
                                            toggleHeight -
                                            currentHudHeight -
                                            24.0)
                                      : math.min(
                                          targetPanelHeight,
                                          math.max(
                                            66.0,
                                            height -
                                                gridHeight -
                                                toggleHeight -
                                                currentHudHeight -
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
                                            : (currentHudHeight + 10.0),
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
                                            : (currentHudHeight +
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
                                                  currentHudHeight +
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
                      if (!isFlyingFullscreen) ...[
                        const SizedBox(height: 4.0),
                        BannerAdWidget(adSize: AdSize(width: 320, height: 36)),
                      ],
                    ],
                  ),
                ),
                if (_showCongratsSplash)
                  Positioned.fill(child: _buildCongratsSplash()),
                if (_showAdCountdown)
                  Positioned.fill(child: _buildAdCountdownOverlay()),
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
                                            color: CyberTheme.neonCyan
                                                .withValues(alpha: 0.5),
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
                            child: SizedBox(
                              width: 14.0,
                              height: 14.0,
                              child: CustomPaint(
                                painter: CyberExpandIconPainter(
                                  color: CyberTheme.neonCyan,
                                  hoverVal: isHovered ? 1.0 : 0.0,
                                ),
                              ),
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

            // Right: Hint Button & Settings Button
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHintButton(context, activeLevel),
                const SizedBox(width: 8.0),
                _buildRightSettingsButton(context, activeLevel),
              ],
            ),
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

  Widget _buildHintButton(BuildContext context, Level activeLevel) {
    return Consumer(
      builder: (context, ref, child) {
        final remainingKeys = ref.watch(remainingHintsProvider);
        return InkWell(
          key: TutorialKeys.hint,
          onTap: () {
            _playSound('audio/click.wav');
            final isShown = ref.read(showHintGuidanceProvider);
            if (isShown) {
              // If already open, just toggle it closed without deducting keys
              ref.read(showHintGuidanceProvider.notifier).set(false);
            } else {
              // If closed, we want to open it. Check deduction rules:
              final gameState = ref.read(gameStateProvider);
              final startState = simulateProgramToState(
                activeLevel,
                gameState.program,
              );
              final path = solveLevelBFS(activeLevel, startState: startState);
              final hasMoreSteps = path != null && path.isNotEmpty;

              if (!hasMoreSteps) {
                // No more steps (already solved or crashed), just open for free
                ref.read(showHintGuidanceProvider.notifier).set(true);
              } else if (activeLevel.id.startsWith('T')) {
                // Tutorial levels are free
                ref.read(showHintGuidanceProvider.notifier).set(true);
              } else {
                // Regular levels deduct keys when opening
                if (remainingKeys > 0) {
                  ref
                      .read(unlockedHintsProvider.notifier)
                      .unlockHint(activeLevel.id);
                  ref.read(showHintGuidanceProvider.notifier).set(true);
                } else {
                  _showHintPurchaseDialog(context, activeLevel);
                }
              }
            }
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CyberCard(
                borderColor: CyberTheme.neonYellow,
                backgroundColor: Colors.transparent,
                borderWidth: 1.0,
                chamferSize: 6.0,
                showAccents: false,
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: CyberTheme.neonYellow,
                    size: 20.0,
                  ),
                ),
              ),
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5.0,
                    vertical: 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: CyberTheme.neonYellow,
                    borderRadius: BorderRadius.circular(10.0),
                    boxShadow: [
                      BoxShadow(
                        color: CyberTheme.neonYellow.withValues(alpha: 0.4),
                        blurRadius: 4.0,
                        spreadRadius: 1.0,
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      '$remainingKeys',
                      style: CyberTheme.fontCode(
                        size: 9.0,
                        color: CyberTheme.darkBg,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHintPurchaseDialog(BuildContext context, Level activeLevel) {
    showCyberDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Consumer(
              builder: (context, ref, child) {
                final remainingKeys = ref.watch(remainingHintsProvider);
                final diamonds = ref.watch(diamondProvider);

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
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.lightbulb,
                                color: CyberTheme.neonYellow,
                                size: 22.0,
                              ),
                              const SizedBox(width: 8.0),
                              Text(
                                'DECRYPTOR OUT OF HINTS',
                                style: CyberTheme.fontHeading(
                                  size: 15.0,
                                  color: CyberTheme.neonYellow,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'KEYS AVAILABLE',
                                    style: CyberTheme.fontCode(
                                      size: 10.0,
                                      color: CyberTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 4.0),
                                  Text(
                                    '$remainingKeys',
                                    style: CyberTheme.fontHeading(
                                      size: 18.0,
                                      color: CyberTheme.neonYellow,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'DIAMONDS BALANCE',
                                    style: CyberTheme.fontCode(
                                      size: 10.0,
                                      color: CyberTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 4.0),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.diamond,
                                        color: CyberTheme.neonCyan,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4.0),
                                      Text(
                                        '$diamonds',
                                        style: CyberTheme.fontHeading(
                                          size: 18.0,
                                          color: CyberTheme.neonCyan,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          Text(
                            'Decrypting sector telemetry paths requires Hint Keys. Choose a recharge protocol:',
                            style: CyberTheme.fontBody(
                              size: 12.0,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 20.0),
                          InkWell(
                            onTap: () async {
                              _playSound('audio/click.wav');
                              final boughtHintsNotifier = ref.read(
                                boughtHintsProvider.notifier,
                              );
                              final audioController = ref.read(
                                audioControllerProvider,
                              );

                              // Show a connecting loading spinner dialog
                              showCyberDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (dialogContext) {
                                  return Dialog(
                                    backgroundColor: Colors.transparent,
                                    child: CyberCard(
                                      borderColor: CyberTheme.neonYellow,
                                      backgroundColor: CyberTheme.darkBg,
                                      chamferSize: 12.0,
                                      showAccents: false,
                                      child: Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                    CyberTheme.neonYellow,
                                                  ),
                                            ),
                                            const SizedBox(height: 16.0),
                                            Text(
                                              'CONNECTING TO AD NETWORK...',
                                              style: CyberTheme.fontCode(
                                                size: 12.0,
                                                color: CyberTheme.neonYellow,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );

                              // If the ad is not loaded, start loading it now
                              if (!_isRewardedAdLoaded || _rewardedAd == null) {
                                _loadRewardedAd();
                              }

                              // Wait up to 3 seconds (30 * 100ms) for the ad to finish loading
                              int checkCount = 0;
                              while (!_isRewardedAdLoaded && checkCount < 30) {
                                await Future.delayed(
                                  const Duration(milliseconds: 100),
                                );
                                checkCount++;
                              }

                              // Dismiss the connecting spinner dialog
                              if (context.mounted) {
                                Navigator.pop(context);
                              }

                              // Check if the ad loaded successfully
                              if (_isRewardedAdLoaded && _rewardedAd != null) {
                                // Dismiss the Hint Purchase Dialog
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                                _rewardedAd!.show(
                                  onUserEarnedReward:
                                      (
                                        AdWithoutView ad,
                                        RewardItem reward,
                                      ) async {
                                        await boughtHintsNotifier
                                            .addBoughtHints(1);

                                        if (mounted) {
                                          audioController.playPickup();
                                          _showHintRewardDialog();
                                        }
                                      },
                                );
                              } else {
                                // Fallback to simulated ad stream if it failed or timed out
                                int secondsLeft =
                                    30 + math.Random().nextInt(31);
                                Timer? countdownTimer;

                                showCyberDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (dialogContext) {
                                    return StatefulBuilder(
                                      builder: (context, setDialogState) {
                                        countdownTimer ??= Timer.periodic(
                                          const Duration(seconds: 1),
                                          (timer) async {
                                            if (secondsLeft > 1) {
                                              if (dialogContext.mounted) {
                                                setDialogState(() {
                                                  secondsLeft--;
                                                });
                                              }
                                            } else {
                                              timer.cancel();
                                              if (dialogContext.mounted) {
                                                Navigator.pop(
                                                  dialogContext,
                                                ); // Close simulated ad dialog
                                                Navigator.pop(
                                                  context,
                                                ); // Close Hint Purchase Dialog

                                                await boughtHintsNotifier
                                                    .addBoughtHints(1);

                                                if (mounted) {
                                                  audioController.playPickup();
                                                  _showHintRewardDialog();
                                                }
                                              }
                                            }
                                          },
                                        );

                                        return Dialog(
                                          backgroundColor: Colors.transparent,
                                          child: CyberCard(
                                            borderColor: CyberTheme.neonYellow,
                                            backgroundColor: CyberTheme.darkBg,
                                            chamferSize: 12.0,
                                            showAccents: false,
                                            child: Padding(
                                              padding: const EdgeInsets.all(
                                                24.0,
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    '$secondsLeft',
                                                    style:
                                                        CyberTheme.fontHeading(
                                                          size: 48.0,
                                                          color: CyberTheme
                                                              .neonYellow,
                                                        ).copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          shadows: [
                                                            Shadow(
                                                              color: CyberTheme
                                                                  .neonYellow
                                                                  .withValues(
                                                                    alpha: 0.5,
                                                                  ),
                                                              blurRadius: 12.0,
                                                            ),
                                                          ],
                                                        ),
                                                  ),
                                                  const SizedBox(height: 16.0),
                                                  Text(
                                                    'STREAMING AD DATA LINK...',
                                                    style: CyberTheme.fontCode(
                                                      size: 12.0,
                                                      color:
                                                          CyberTheme.neonYellow,
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
                                ).then((_) {
                                  countdownTimer?.cancel();
                                });
                              }
                            },
                            child: CyberCard(
                              borderColor: CyberTheme.neonYellow,
                              backgroundColor: Colors.transparent,
                              borderWidth: 1.0,
                              chamferSize: 8.0,
                              showAccents: false,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.ondemand_video,
                                      color: CyberTheme.neonYellow,
                                    ),
                                    const SizedBox(width: 12.0),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'STREAM TELEMETRY AD',
                                            style:
                                                CyberTheme.fontCode(
                                                  size: 13.0,
                                                  color: CyberTheme.neonYellow,
                                                ).copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 2.0),
                                          Text(
                                            'Free: Watch 1 Ad to receive 1 Hint Key',
                                            style: CyberTheme.fontCode(
                                              size: 10.0,
                                              color: CyberTheme.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14.0,
                                      color: CyberTheme.neonYellow,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          InkWell(
                            onTap: diamonds >= 100
                                ? () async {
                                    _playSound('audio/click.wav');
                                    Navigator.pop(context);

                                    final success = await ref
                                        .read(diamondProvider.notifier)
                                        .spendDiamonds(100);
                                    if (success) {
                                      await ref
                                          .read(boughtHintsProvider.notifier)
                                          .addBoughtHints(5);
                                      _playSound('audio/success.wav');

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          backgroundColor: CyberTheme.cardBg,
                                          content: Text(
                                            'EXCHANGED: 100 DIAMONDS FOR +5 HINT KEYS',
                                            style: CyberTheme.fontCode(
                                              color: CyberTheme.neonCyan,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                            child: CyberCard(
                              borderColor: diamonds >= 100
                                  ? CyberTheme.neonCyan
                                  : CyberTheme.borderTranslucent,
                              backgroundColor: Colors.transparent,
                              borderWidth: 1.0,
                              chamferSize: 8.0,
                              showAccents: false,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Opacity(
                                  opacity: diamonds >= 100 ? 1.0 : 0.5,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.diamond,
                                        color: CyberTheme.neonCyan,
                                      ),
                                      const SizedBox(width: 12.0),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'EXCHANGE DIAMONDS',
                                              style:
                                                  CyberTheme.fontCode(
                                                    size: 13.0,
                                                    color: CyberTheme.neonCyan,
                                                  ).copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(height: 2.0),
                                            Text(
                                              'Cost: 100 Diamonds to receive 5 Hint Keys',
                                              style: CyberTheme.fontCode(
                                                size: 10.0,
                                                color: CyberTheme.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 14.0,
                                        color: diamonds >= 100
                                            ? CyberTheme.neonCyan
                                            : CyberTheme.textMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20.0),
                          GestureDetector(
                            onTap: () {
                              _playSound('audio/click.wav');
                              Navigator.pop(context);
                            },
                            child: Center(
                              child: Text(
                                'DISMISS',
                                style: CyberTheme.fontCode(
                                  size: 12.0,
                                  color: CyberTheme.textMuted,
                                ).copyWith(fontWeight: FontWeight.bold),
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
      },
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
                                        ? 'MASTER AUDIO: ACTIVE'
                                        : 'MASTER AUDIO: MUTED',
                                    style: CyberTheme.fontCode(
                                      size: 13.0,
                                      color: isSoundOn
                                          ? CyberTheme.neonGreen
                                          : CyberTheme.textMuted,
                                    ).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (isSoundOn) ...[
                        const SizedBox(height: 12.0),
                        Text(
                          'SFX VOLUME: ${(ref.watch(sfxVolumeProvider) * 100).round()}%',
                          style: CyberTheme.fontCode(
                            size: 11.0,
                            color: CyberTheme.neonGreen,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                        Slider(
                          value: ref.watch(sfxVolumeProvider),
                          activeColor: CyberTheme.neonGreen,
                          inactiveColor: Colors.white10,
                          onChanged: (v) {
                            ref.read(sfxVolumeProvider.notifier).setVolume(v);
                            setDialogState(() {});
                          },
                        ),
                        const SizedBox(height: 6.0),
                        Row(
                          children: [
                            Icon(
                              ref.watch(bgmOnProvider)
                                  ? Icons.music_note
                                  : Icons.music_off,
                              size: 18.0,
                              color: ref.watch(bgmOnProvider)
                                  ? CyberTheme.neonCyan
                                  : CyberTheme.textMuted,
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              'AMBIENT BGM',
                              style: CyberTheme.fontCode(
                                size: 12.0,
                                color: ref.watch(bgmOnProvider)
                                    ? CyberTheme.neonCyan
                                    : CyberTheme.textMuted,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Switch(
                              value: ref.watch(bgmOnProvider),
                              activeThumbColor: CyberTheme.neonCyan,
                              activeTrackColor: CyberTheme.neonCyan.withValues(
                                alpha: 0.3,
                              ),
                              inactiveThumbColor: CyberTheme.textMuted,
                              inactiveTrackColor: Colors.white10,
                              onChanged: (v) {
                                ref.read(audioControllerProvider).playClick();
                                ref.read(bgmOnProvider.notifier).toggle();
                                setDialogState(() {});
                              },
                            ),
                          ],
                        ),
                        if (ref.watch(bgmOnProvider)) ...[
                          Slider(
                            value: ref.watch(bgmVolumeProvider),
                            activeColor: CyberTheme.neonCyan,
                            inactiveColor: Colors.white10,
                            onChanged: (v) {
                              ref.read(bgmVolumeProvider.notifier).setVolume(v);
                              setDialogState(() {});
                            },
                          ),
                        ],
                        const SizedBox(height: 6.0),
                        Row(
                          children: [
                            Icon(
                              ref.watch(humOnProvider)
                                  ? Icons.waves
                                  : Icons.blur_off,
                              size: 18.0,
                              color: ref.watch(humOnProvider)
                                  ? CyberTheme.neonYellow
                                  : CyberTheme.textMuted,
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              'REACTOR COCKPIT HUM',
                              style: CyberTheme.fontCode(
                                size: 12.0,
                                color: ref.watch(humOnProvider)
                                    ? CyberTheme.neonYellow
                                    : CyberTheme.textMuted,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Switch(
                              value: ref.watch(humOnProvider),
                              activeThumbColor: CyberTheme.neonYellow,
                              activeTrackColor: CyberTheme.neonYellow
                                  .withValues(alpha: 0.3),
                              inactiveThumbColor: CyberTheme.textMuted,
                              inactiveTrackColor: Colors.white10,
                              onChanged: (v) {
                                ref.read(audioControllerProvider).playClick();
                                ref.read(humOnProvider.notifier).toggle();
                                setDialogState(() {});
                              },
                            ),
                          ],
                        ),
                        if (ref.watch(humOnProvider)) ...[
                          Slider(
                            value: ref.watch(humVolumeProvider),
                            activeColor: CyberTheme.neonYellow,
                            inactiveColor: Colors.white10,
                            onChanged: (v) {
                              ref.read(humVolumeProvider.notifier).setVolume(v);
                              setDialogState(() {});
                            },
                          ),
                        ],
                      ],
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

                      // AI Copilot Button
                      InkWell(
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
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
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
                                horizontal: 16.0,
                                vertical: 10.0,
                              ),
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
        final cellSize = math.min(cellWidth, cellHeight);
        final hUnit = cellSize * 0.5625;
        final droneSize = cellSize * 0.90;

        final droneLeft =
            state.droneX * cellWidth + (cellWidth - droneSize) / 2;
        final droneTop =
            state.droneY * cellHeight + (cellHeight - droneSize) / 2;

        final double cargoBoxSize = math.min(cellWidth, cellHeight) * 0.22;
        final cargoLeft =
            level.boxX * cellWidth + (cellWidth - cargoBoxSize) / 2;
        final cargoTop =
            level.boxY * cellHeight + (cellHeight - cargoBoxSize) / 2;

        final targetSize = math.min(cellWidth, cellHeight) * 0.55;
        final targetLeft =
            level.targetX * cellWidth + (cellWidth - targetSize) / 2;
        final targetTop =
            level.targetY * cellHeight + (cellHeight - targetSize) / 2;

        return Center(
          child: SizedBox(
            key: TutorialKeys.gridArena,
            width: width,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // Perspective tilt
                      ..rotateX(0.55) // Tilt backward
                      ..rotateZ(-0.45) // Rotate slightly
                      ..multiply(
                        Matrix4.diagonal3Values(0.82, 0.82, 1.0),
                      ), // Scale down slightly to fit beautifully
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 3D Land Base (extruded floating plate using Z-translation)
                        ...List.generate(9, (i) {
                          final index = 8 - i;
                          if (index == 8) {
                            // Underglow shadow layer
                            return Transform(
                              transform: Matrix4.translationValues(0, 0, -32.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (state.status == GameStatus.crashed
                                                  ? CyberTheme.neonPink
                                                  : (state.status ==
                                                            GameStatus.success
                                                        ? CyberTheme.neonGreen
                                                        : CyberTheme.neonCyan))
                                              .withValues(alpha: 0.35),
                                      blurRadius: 30.0,
                                      spreadRadius: 8.0,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          final zOffset = -index * 3.5;
                          final opacity = 0.95 - (index * 0.05);
                          return Transform(
                            transform: Matrix4.translationValues(0, 0, zOffset),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: index == 0
                                    ? const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF0F1527),
                                          Color(0xFF070B16),
                                        ],
                                      )
                                    : null,
                                color: index == 0
                                    ? null
                                    : const Color(
                                        0xFF04060C,
                                      ).withValues(alpha: opacity),
                                border: index == 0
                                    ? Border.all(
                                        color:
                                            state.status == GameStatus.crashed
                                            ? CyberTheme.neonPink.withValues(
                                                alpha: 0.8,
                                              )
                                            : (state.status ==
                                                      GameStatus.success
                                                  ? CyberTheme.neonGreen
                                                        .withValues(alpha: 0.8)
                                                  : CyberTheme.neonCyan
                                                        .withValues(
                                                          alpha: 0.5,
                                                        )),
                                        width: 1.5,
                                      )
                                    : Border(
                                        bottom: BorderSide(
                                          color:
                                              state.status == GameStatus.crashed
                                              ? CyberTheme.neonPink.withValues(
                                                  alpha: 0.25,
                                                )
                                              : (state.status ==
                                                        GameStatus.success
                                                    ? CyberTheme.neonGreen
                                                          .withValues(
                                                            alpha: 0.25,
                                                          )
                                                    : CyberTheme.neonCyan
                                                          .withValues(
                                                            alpha: 0.25,
                                                          )),
                                          width: 1.0,
                                        ),
                                        left: BorderSide(
                                          color:
                                              state.status == GameStatus.crashed
                                              ? CyberTheme.neonPink.withValues(
                                                  alpha: 0.15,
                                                )
                                              : (state.status ==
                                                        GameStatus.success
                                                    ? CyberTheme.neonGreen
                                                          .withValues(
                                                            alpha: 0.15,
                                                          )
                                                    : CyberTheme.neonCyan
                                                          .withValues(
                                                            alpha: 0.15,
                                                          )),
                                          width: 1.0,
                                        ),
                                        right: BorderSide(
                                          color:
                                              state.status == GameStatus.crashed
                                              ? CyberTheme.neonPink.withValues(
                                                  alpha: 0.15,
                                                )
                                              : (state.status ==
                                                        GameStatus.success
                                                    ? CyberTheme.neonGreen
                                                          .withValues(
                                                            alpha: 0.15,
                                                          )
                                                    : CyberTheme.neonCyan
                                                          .withValues(
                                                            alpha: 0.15,
                                                          )),
                                          width: 1.0,
                                        ),
                                      ),
                              ),
                            ),
                          );
                        }),

                        // Radar Sweeper (tilted in 3D, sweeping on the land surface)
                        if (state.status != GameStatus.crashed)
                          const Positioned.fill(child: RadarSweeper()),

                        // 3D Target Pad (Volumetric 3D Helipad Widget)
                        Positioned(
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
                                      Positioned(
                                        bottom: -2,
                                        child: Transform(
                                          transform: Matrix4.translationValues(
                                            0,
                                            0,
                                            16.0,
                                          ),
                                          child: Text(
                                            state.status == GameStatus.success
                                                ? 'SECURED'
                                                : 'DROP',
                                            style:
                                                CyberTheme.fontCode(
                                                  size: 9.0,
                                                  color: CyberTheme.neonGreen,
                                                ).copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                  .animate(
                                    onPlay: (c) => c.repeat(reverse: true),
                                  )
                                  .scale(
                                    duration: 1500.ms,
                                    begin: const Offset(0.9, 0.9),
                                    end: const Offset(1.05, 1.05),
                                  ),
                        ),

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
                                    animationValue:
                                        _gridAnimationController.value,
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
                                  animationValue:
                                      _gridAnimationController.value,
                                ),
                              ],
                            );
                          },
                        ),

                        // Volumetric Obstacles (holographic stacked pillars using Z-translation)
                        ...List.generate(level.obstacles.length, (i) {
                          final obs = level.obstacles[i];
                          final obsSize = cellSize * 0.75;
                          final obsLeft =
                              obs.x * cellWidth + (cellWidth - obsSize) / 2;
                          final obsTop =
                              obs.y * cellHeight + (cellHeight - obsSize) / 2;

                          final numLayers = obs.height * 10;
                          final totalHeight = obs.height * hUnit;
                          final step = totalHeight / (numLayers - 1);

                          return Stack(
                            clipBehavior: Clip.none,
                            children: List.generate(numLayers, (layerIndex) {
                              final zVal = layerIndex * step;
                              final isTop = layerIndex == (numLayers - 1);
                              return Positioned(
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
                                              alpha: 0.25,
                                            )
                                          : const Color(
                                              0xFF6B123C,
                                            ).withValues(alpha: 0.9),
                                      border: Border.all(
                                        color: isTop
                                            ? CyberTheme.neonPink
                                            : CyberTheme.neonPink.withValues(
                                                alpha: 0.3,
                                              ),
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.circular(4.0),
                                    ),
                                    child: isTop
                                        ? Center(
                                            child: Text(
                                              'H:${obs.height}',
                                              style:
                                                  CyberTheme.fontCode(
                                                    size: 11.0,
                                                    color: CyberTheme.neonPink,
                                                  ).copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            }),
                          );
                        }),

                        // Floating Energy Cells
                        ...List.generate(state.remainingEnergyCells.length, (
                          i,
                        ) {
                          final ec = state.remainingEnergyCells[i];
                          final ecSize = cellSize * 0.45;
                          final ecOffset = ec.height * hUnit;
                          final ecLeft =
                              ec.x * cellWidth + (cellWidth - ecSize) / 2;
                          final ecTop =
                              ec.y * cellHeight + (cellHeight - ecSize) / 2;

                          return Positioned(
                            left: ecLeft,
                            top: ecTop,
                            width: ecSize,
                            height: ecSize,
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                // Ground project dot shadow
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
                                // Floating elements (Z-translated together perpendicularly)
                                Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.translationValues(
                                    0,
                                    0,
                                    ecOffset,
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    clipBehavior: Clip.none,
                                    children: [
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
                                          )
                                          .slideY(
                                            begin: -0.1,
                                            end: 0.1,
                                            duration: 1200.ms,
                                            curve: Curves.easeInOut,
                                          ),
                                      Positioned(
                                        bottom: -12.0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4.0,
                                            vertical: 1.0,
                                          ),
                                          color: Colors.black.withValues(
                                            alpha: 0.85,
                                          ),
                                          child: Text(
                                            'ALT ${ec.height}',
                                            style: CyberTheme.fontCode(
                                              size: 7.5,
                                              color: CyberTheme.neonYellow,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        // Grouped and Animated Drone Widget Stack (Smooth 2D + 3D Z-translation)
                        AnimatedPositioned(
                          key: const ValueKey('drone_animated_stack'),
                          duration: state.status == GameStatus.running
                              ? Duration(
                                  milliseconds: (1600 / state.speedMultiplier)
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
                              end: state.droneHeight.toDouble(),
                            ),
                            duration: state.status == GameStatus.running
                                ? Duration(
                                    milliseconds: (1600 / state.speedMultiplier)
                                        .round(),
                                  )
                                : Duration.zero,
                            curve: Curves.easeInOutCubic,
                            builder: (context, animHeight, child) {
                              final currentZ = animHeight * hUnit;
                              final shadowOpacity = math.max(
                                0.0,
                                math.min(0.45, 0.45 * animHeight),
                              );

                              return Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  // 1. Drone Shadow on the ground grid (always at bottom)
                                  if (animHeight > 0.05)
                                    Center(
                                      child: Opacity(
                                        opacity: shadowOpacity,
                                        child: Container(
                                          width: droneSize * 0.4,
                                          height: droneSize * 0.4,
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
                                        transform: Matrix4.translationValues(
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
                                                  (state.status ==
                                                              GameStatus.crashed
                                                          ? CyberTheme.neonPink
                                                          : (state.status ==
                                                                    GameStatus
                                                                        .success
                                                                ? CyberTheme
                                                                      .neonGreen
                                                                : CyberTheme
                                                                      .neonCyan))
                                                      .withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),

                                  // 3. Custom Animated Drone Sprite (Elevated in Z-axis)
                                  Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.translationValues(
                                      0,
                                      0,
                                      currentZ,
                                    ),
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
                              );
                            },
                          ),
                        ),

                        // Holographic corner bracket frame
                        Positioned.fill(
                          child: Transform(
                            transform: Matrix4.translationValues(0, 0, 10.0),
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: HolographicFramePainter(
                                  color:
                                      (state.status == GameStatus.crashed
                                              ? CyberTheme.neonPink
                                              : (state.status ==
                                                        GameStatus.success
                                                    ? CyberTheme.neonGreen
                                                    : CyberTheme.neonCyan))
                                          .withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
        if (isFloating) ...[
          const SizedBox(height: 8.0),
          const Divider(color: CyberTheme.borderTranslucent, height: 1.0),
          const SizedBox(height: 6.0),
          _ScrollingTelemetryChart(
            status: state.status,
            droneHeight: state.droneHeight,
            battery: state.battery,
          ),
        ],
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

  Widget _buildAdCountdownOverlay() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          color: CyberTheme.darkBg.withValues(alpha: 0.85),
          child: Center(
            child: CyberCard(
              borderColor: CyberTheme.neonCyan,
              backgroundColor: CyberTheme.cardBg,
              borderWidth: 1.5,
              chamferSize: 16.0,
              showAccents: true,
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: CyberTheme.neonCyan.withValues(alpha: 0.1),
                            border: Border.all(
                              color: CyberTheme.neonCyan.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.wifi_tethering_rounded,
                            color: CyberTheme.neonCyan,
                            size: 32.0,
                          ),
                        )
                        .animate(
                          onPlay: (controller) =>
                              controller.repeat(reverse: true),
                        )
                        .scale(
                          duration: 800.ms,
                          begin: const Offset(0.9, 0.9),
                          end: const Offset(1.1, 1.1),
                        ),
                    const SizedBox(height: 16.0),
                    Text(
                      'ESTABLISHING TELEMETRY LINK',
                      style: CyberTheme.fontHeading(
                        size: 16.0,
                        color: CyberTheme.neonCyan,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Synchronizing satellite uplink... please hold.',
                      textAlign: TextAlign.center,
                      style: CyberTheme.fontBody(
                        size: 13.0,
                        color: CyberTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: _adCountdownSeconds / 3.0,
                            strokeWidth: 4.0,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              CyberTheme.neonCyan,
                            ),
                            backgroundColor: CyberTheme.borderTranslucent,
                          ),
                        ),
                        Text(
                              '$_adCountdownSeconds',
                              style: CyberTheme.fontHeading(
                                size: 28.0,
                                color: CyberTheme.neonCyan,
                              ),
                            )
                            .animate(key: ValueKey(_adCountdownSeconds))
                            .scale(duration: 200.ms, curve: Curves.easeOutBack)
                            .then(delay: 600.ms)
                            .fadeOut(duration: 200.ms),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      'SECURE CHANNEL INITIATING',
                      style: CyberTheme.fontCode(
                        size: 11.0,
                        color: CyberTheme.textMuted,
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
                            .animate(
                              onPlay: (controller) => controller.repeat(),
                            )
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
                            .animate(
                              onPlay: (controller) => controller.repeat(),
                            )
                            .scale(duration: 600.ms, curve: Curves.elasticOut)
                            .rotate(duration: 4.seconds, end: -1.0),

                        Container(
                              padding: const EdgeInsets.all(20.0),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: CyberTheme.neonGreen.withValues(
                                  alpha: 0.15,
                                ),
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
                        .shimmer(
                          duration: 1.2.seconds,
                          color: CyberTheme.neonCyan,
                        ),

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
    if (current.id.startsWith('S')) {
      final sandboxLevels = ref.read(sandboxLevelsProvider);
      final index = sandboxLevels.indexWhere((l) => l.id == current.id);
      if (index != -1 && index + 1 < sandboxLevels.length) {
        return sandboxLevels[index + 1];
      }
      return null;
    }

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
                                    ? (isFourthStar
                                          ? Icons.diamond
                                          : Icons.star)
                                    : (isFourthStar
                                          ? Icons.diamond_outlined
                                          : Icons.star_border),
                                size: isFourthStar ? 30.0 : 28.0,
                                color: isLit
                                    ? litColor
                                    : CyberTheme.textMuted.withValues(
                                        alpha: 0.2,
                                      ),
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
                                ref
                                    .read(gameStateProvider.notifier)
                                    .clearProgram();
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
                                      .read(
                                        seenTutorialMissionsProvider.notifier,
                                      )
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
                                        .read(
                                          seenTutorialMissionsProvider.notifier,
                                        )
                                        .markAsSeen();
                                    ref
                                        .read(gameModeProvider.notifier)
                                        .setMode(GameMode.normal);
                                    ref
                                        .read(currentLevelProvider.notifier)
                                        .setLevel(nextLvl);
                                    ref
                                        .read(gameStateProvider.notifier)
                                        .clearProgram();
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
                                    ref
                                        .read(gameStateProvider.notifier)
                                        .clearProgram();
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

class HolographicFramePainter extends CustomPainter {
  final Color color;
  HolographicFramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final len = math.min(size.width, size.height) * 0.08;

    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(0, len)
        ..lineTo(0, 0)
        ..lineTo(len, 0),
      paint,
    );
    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, len),
      paint,
    );
    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - len)
        ..lineTo(0, size.height)
        ..lineTo(len, size.height),
      paint,
    );
    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant HolographicFramePainter oldDelegate) =>
      oldDelegate.color != color;
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
      final delayMs = (1600 / widget.speedMultiplier).round();
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
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Ground pulse circle (z = 0)
                    Positioned.fill(
                      child: CustomPaint(
                        size: Size(widget.size, widget.size),
                        painter: CargoPulsePainter(
                          animationValue: widget.animationValue,
                        ),
                      ),
                    ),
                    // 2. Volumetric cargo layers (static child)
                    child!,
                  ],
                ),
              ),
            ),
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(10, (layerIndex) {
          final zVal = layerIndex * (widget.size * 0.85 / 9);
          final isTop = layerIndex == 9;
          return Positioned.fill(
            child: Transform(
              transform: Matrix4.translationValues(0, 0, zVal),
              child: Container(
                decoration: BoxDecoration(
                  color: isTop
                      ? Colors.transparent
                      : const Color(0xFFB4703C).withValues(alpha: 0.95),
                  border: isTop
                      ? null
                      : Border.all(
                          color: const Color(0xFF8B4F21).withValues(alpha: 0.4),
                          width: 1.0,
                        ),
                  borderRadius: BorderRadius.circular(3.0),
                ),
                child: isTop
                    ? CustomPaint(
                        size: Size(widget.size, widget.size),
                        painter: CargoBoxPainter(),
                      )
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class CargoPulsePainter extends CustomPainter {
  final double animationValue;

  CargoPulsePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final double cargoBoxSize = size.width;

    // Pulse highlight outline ring around cargo (subtle cyber aesthetic hint) at z = 0
    final cargoPulse =
        1.0 + 0.1 * math.sin((animationValue + 0.5) * 2 * math.pi);
    final cargoPulsePaint = Paint()
      ..color = CyberTheme.neonYellow.withValues(
        alpha: 0.15 * (2.0 - cargoPulse),
      )
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, cargoBoxSize * 1.5 * cargoPulse, cargoPulsePaint);
  }

  @override
  bool shouldRepaint(covariant CargoPulsePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class CargoBoxPainter extends CustomPainter {
  CargoBoxPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final double cargoBoxSize = size.width;

    // 1. Draw Cardboard Box Top body
    final cargoRect = Rect.fromCenter(
      center: center,
      width: cargoBoxSize,
      height: cargoBoxSize,
    );

    // Warm cardboard color
    final cargoPaint = Paint()
      ..color = const Color(0xFFE5A96C)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(cargoRect, const Radius.circular(3.0)),
      cargoPaint,
    );

    // Cardboard borders (darker brown)
    final cargoBorder = Paint()
      ..color = const Color(0xFF8B4F21)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(cargoRect, const Radius.circular(3.0)),
      cargoBorder,
    );

    // 2. Central white packaging tape line
    final tapePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final tapeWidth = size.width * 0.16;
    final tapeRect = Rect.fromLTWH(
      cx - tapeWidth / 2,
      0,
      tapeWidth,
      size.height,
    );
    canvas.drawRect(tapeRect, tapePaint);

    // Add tape border lines for extra definition
    final tapeBorderPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(tapeRect, tapeBorderPaint);

    // 3. Draw subtle box flap division lines
    final linePaint = Paint()
      ..color = const Color(0xFF8B4F21).withValues(alpha: 0.5)
      ..strokeWidth = 0.8;
    // Horizontal division line across the tape
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), linePaint);
  }

  @override
  bool shouldRepaint(covariant CargoBoxPainter oldDelegate) => false;
}

class _ScrollingTelemetryChart extends StatefulWidget {
  final GameStatus status;
  final int droneHeight;
  final int battery;

  const _ScrollingTelemetryChart({
    required this.status,
    required this.droneHeight,
    required this.battery,
  });

  @override
  State<_ScrollingTelemetryChart> createState() =>
      _ScrollingTelemetryChartState();
}

class _ScrollingTelemetryChartState extends State<_ScrollingTelemetryChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _altitudeHistory = [];
  final List<double> _batteryHistory = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Initialize histories
    for (int i = 0; i < 50; i++) {
      _altitudeHistory.add(widget.droneHeight.toDouble());
      _batteryHistory.add(widget.battery.toDouble());
    }
  }

  @override
  void didUpdateWidget(covariant _ScrollingTelemetryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.droneHeight != oldWidget.droneHeight ||
        widget.battery != oldWidget.battery) {
      setState(() {
        _altitudeHistory.removeAt(0);
        _altitudeHistory.add(widget.droneHeight.toDouble());
        _batteryHistory.removeAt(0);
        _batteryHistory.add(widget.battery.toDouble());
      });
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
        return SizedBox(
          height: 38.0,
          width: double.infinity,
          child: CustomPaint(
            painter: _TelemetryChartPainter(
              status: widget.status,
              altitudeHistory: _altitudeHistory,
              batteryHistory: _batteryHistory,
              phase: _controller.value * 2 * math.pi,
            ),
          ),
        );
      },
    );
  }
}

class _TelemetryChartPainter extends CustomPainter {
  final GameStatus status;
  final List<double> altitudeHistory;
  final List<double> batteryHistory;
  final double phase;

  _TelemetryChartPainter({
    required this.status,
    required this.altitudeHistory,
    required this.batteryHistory,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.clipRect(rect);

    // 1. Draw grid background
    final gridPaint = Paint()
      ..color = CyberTheme.borderTranslucent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Draw horizontal grid lines
    const gridRows = 3;
    for (int i = 1; i < gridRows; i++) {
      final y = size.height * i / gridRows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    // Draw vertical grid lines
    const gridCols = 8;
    for (int i = 1; i < gridCols; i++) {
      final x = size.width * i / gridCols;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // 2. Draw historical altitude trace (Neon Yellow/Orange)
    if (altitudeHistory.isNotEmpty) {
      final altPath = Path();
      final dx = size.width / (altitudeHistory.length - 1);

      // We want to scale altitude (0m to 8m)
      double getAltY(double alt) {
        final norm = (alt / 8.0).clamp(0.0, 1.0);
        return size.height - 4.0 - norm * (size.height - 8.0);
      }

      altPath.moveTo(0, getAltY(altitudeHistory[0]));
      for (int i = 1; i < altitudeHistory.length; i++) {
        altPath.lineTo(dx * i, getAltY(altitudeHistory[i]));
      }

      final altPaint = Paint()
        ..color = CyberTheme.neonYellow.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawPath(altPath, altPaint);
    }

    // 3. Draw real-time System Pulse neon wave (Cyan/Green)
    final pulsePath = Path();
    final step = 2.0;

    // Adjust frequency and amplitude based on status
    double freq = 0.08;
    double amp = 6.0;
    Color pulseColor = CyberTheme.neonCyan;

    switch (status) {
      case GameStatus.running:
        freq = 0.18;
        amp = 12.0;
        pulseColor = CyberTheme.neonCyan;
        break;
      case GameStatus.success:
        freq = 0.12;
        amp = 8.0;
        pulseColor = CyberTheme.neonGreen;
        break;
      case GameStatus.crashed:
        freq = 0.35;
        amp = size.height * 0.45; // high noise!
        pulseColor = CyberTheme.neonPink;
        break;
      case GameStatus.idle:
      case GameStatus.paused:
        freq = 0.05;
        amp = 3.5;
        pulseColor = CyberTheme.neonCyan.withValues(alpha: 0.7);
        break;
    }

    double getPulseY(double x) {
      final centerY = size.height / 2.0;
      if (status == GameStatus.crashed) {
        // static noise Flatline!
        final t = x * freq + phase * 4;
        final noiseVal = math.sin(t) * math.cos(t * 2.3) * math.sin(t * 7.7);
        return centerY + noiseVal * amp * (x < size.width * 0.35 ? 1.0 : 0.1);
      }
      return centerY + math.sin(x * freq - phase) * amp;
    }

    pulsePath.moveTo(0, getPulseY(0));
    for (double x = step; x < size.width; x += step) {
      pulsePath.lineTo(x, getPulseY(x));
    }

    final pulsePaint = Paint()
      ..color = pulseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    // Draw pulse with a glowing shadow
    canvas.drawPath(
      pulsePath,
      Paint()
        ..color = pulseColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
    );
    canvas.drawPath(pulsePath, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant _TelemetryChartPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.status != status ||
        oldDelegate.altitudeHistory != altitudeHistory ||
        oldDelegate.batteryHistory != batteryHistory;
  }
}

class CyberExpandIconPainter extends CustomPainter {
  final Color color;
  final double hoverVal;

  CyberExpandIconPainter({required this.color, required this.hoverVal});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.75 + 0.25 * hoverVal)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Draw double chevrons pointing down
    final path = Path();

    // First Chevron (Top)
    path.moveTo(w * 0.15, h * 0.25);
    path.lineTo(w * 0.5, h * 0.55);
    path.lineTo(w * 0.85, h * 0.25);

    // Second Chevron (Bottom)
    path.moveTo(w * 0.15, h * 0.5);
    path.lineTo(w * 0.5, h * 0.8);
    path.lineTo(w * 0.85, h * 0.5);

    // Add a subtle neon glow shadow
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.3 + 0.35 * hoverVal)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CyberExpandIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.hoverVal != hoverVal;
}

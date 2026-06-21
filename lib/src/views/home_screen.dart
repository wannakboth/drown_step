import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/level.dart';
import '../theme/colors.dart';
import '../providers/game_state.dart';
import '../providers/audio_provider.dart';
import 'cyber_card.dart';
import 'cyber_dialog.dart';
import 'mission_preview_map.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  PageController? _pageController;
  int _currentPageIndex = 0;
  GameMode? _lastMode;
  bool? _lastSeenTutorial;
  Map<String, int>? _lastStarsMap;
  String? _lastLevelId;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _playClick() {
    ref.read(audioControllerProvider).playClick();
  }

  void _nextPage() {
    _playClick();
    if (_pageController != null && _pageController!.hasClients) {
      _pageController!.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevPage() {
    _playClick();
    if (_pageController != null && _pageController!.hasClients) {
      _pageController!.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _showAccountSettingsDialog(BuildContext context) {
    showCyberDialog(
      context: context,
      builder: (context) => const _AccountDialogContent(),
    );
  }

  void _showLowBatteryDialog(BuildContext context) {
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
                  Row(
                    children: [
                      const Icon(
                            Icons.battery_alert,
                            color: CyberTheme.neonPink,
                            size: 22.0,
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(duration: 800.ms, end: const Offset(1.1, 1.1)),
                      const SizedBox(width: 8.0),
                      Text(
                        'POWER DEPLETED',
                        style: CyberTheme.fontHeading(
                          size: 16.0,
                          color: CyberTheme.neonPink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    'INSUFFICIENT PILOT ENERGY',
                    style: CyberTheme.fontCode(
                      size: 11.0,
                      color: CyberTheme.neonCyan,
                    ).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 6.0),
                  CyberCard(
                    borderColor: CyberTheme.neonCyan.withValues(alpha: 0.15),
                    backgroundColor: Colors.black26,
                    borderWidth: 1.0,
                    chamferSize: 8.0,
                    showAccents: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'This mission requires 5 battery energy to initialize flight telemetry. Energy regenerates passively at a rate of 1 unit every 3 minutes.',
                        style: CyberTheme.fontBody(
                          size: 13.0,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () {
                        _playClick();
                        Navigator.pop(context);
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
                            vertical: 8.0,
                          ),
                          child: Text(
                            'CONFIRM',
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeNavigationBar(BuildContext context, GameMode activeMode) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < 500 ? 12.0 : 24.0,
      ),
      child: CyberCard(
        borderColor: CyberTheme.borderTranslucent,
        backgroundColor: const Color(0xFF121424),
        borderWidth: 1.0,
        chamferSize: 8.0,
        showAccents: false,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            children: [
              _buildModeTab(
                mode: GameMode.daily,
                label: 'DAILY MODE',
                icon: Icons.bolt_rounded,
                activeColor: CyberTheme.neonYellow,
                isActive: activeMode == GameMode.daily,
              ),
              _buildModeTab(
                mode: GameMode.normal,
                label: 'NORMAL',
                icon: Icons.explore_rounded,
                activeColor: CyberTheme.neonCyan,
                isActive: activeMode == GameMode.normal,
              ),
              _buildModeTab(
                mode: GameMode.hard,
                label: 'HARD MODE',
                icon: Icons.dangerous_rounded,
                activeColor: CyberTheme.neonPink,
                isActive: activeMode == GameMode.hard,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required GameMode mode,
    required String label,
    required IconData icon,
    required Color activeColor,
    required bool isActive,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          _playClick();
          ref.read(gameModeProvider.notifier).setMode(mode);
        },
        borderRadius: BorderRadius.circular(isActive ? 6.0 : 8.0),
        child: isActive
            ? CyberCard(
                borderColor: activeColor.withValues(alpha: 0.6),
                backgroundColor: activeColor.withValues(alpha: 0.15),
                borderWidth: 1.0,
                chamferSize: 6.0,
                showAccents: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 16.0, color: activeColor),
                        const SizedBox(width: 6.0),
                        Text(
                          label,
                          style:
                              CyberTheme.fontCode(
                                size: 11.0,
                                color: activeColor,
                              ).copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.transparent, width: 1.0),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 16.0, color: CyberTheme.textMuted),
                      const SizedBox(width: 6.0),
                      Text(
                        label,
                        style:
                            CyberTheme.fontCode(
                              size: 11.0,
                              color: CyberTheme.textMuted,
                            ).copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxUnlocked = ref.watch(maxUnlockedLevelProvider);
    final starsMap = ref.watch(levelStarsProvider);
    final gameMode = ref.watch(gameModeProvider);
    final auth = ref.watch(authProvider);
    final seenTutorial = ref.watch(seenTutorialMissionsProvider);
    final maxUnlockedTutorial = ref.watch(maxUnlockedTutorialLevelProvider);

    final levels = seenTutorial
        ? Level.getLevelsForMode(gameMode)
        : Level.tutorialMissions;
    final totalLevels = levels.length;
    final maxUnlockedIndex = seenTutorial ? maxUnlocked : maxUnlockedTutorial;
    final visibleLevelsCount = gameMode == GameMode.daily
        ? 1
        : math.min(totalLevels, maxUnlockedIndex);

    final currentLevel = ref.watch(currentLevelProvider);
    int initialPageIndex = levels.indexWhere(
      (lvl) => lvl.id == currentLevel.id,
    );
    if (initialPageIndex == -1) {
      int lastCompletedIndex = 0;
      for (int i = 0; i < levels.length; i++) {
        final stars = starsMap[levels[i].id] ?? 0;
        if (stars > 0) {
          lastCompletedIndex = i;
        }
      }
      if (lastCompletedIndex >= visibleLevelsCount) {
        lastCompletedIndex = visibleLevelsCount - 1;
      }
      if (lastCompletedIndex < 0) {
        lastCompletedIndex = 0;
      }
      initialPageIndex = lastCompletedIndex;
    }

    if (_pageController == null ||
        _lastMode != gameMode ||
        _lastSeenTutorial != seenTutorial ||
        _lastLevelId != currentLevel.id ||
        !mapEquals(_lastStarsMap, starsMap)) {
      _lastMode = gameMode;
      _lastSeenTutorial = seenTutorial;
      _lastLevelId = currentLevel.id;
      _lastStarsMap = starsMap;
      _pageController?.dispose();
      _currentPageIndex = initialPageIndex;
      _pageController = PageController(
        viewportFraction: 0.85,
        initialPage: initialPageIndex,
      );
    }

    Color themeColor = CyberTheme.neonCyan;
    if (gameMode == GameMode.daily) {
      themeColor = CyberTheme.neonYellow;
    } else if (gameMode == GameMode.hard) {
      themeColor = CyberTheme.neonPink;
    }

    int totalStarsCollected = levels.fold(0, (sum, lvl) {
      final achieved = starsMap[lvl.id] ?? 0;
      return sum + math.min(achieved, lvl.maxStars);
    });
    int maxPossibleStars = levels.fold(0, (sum, lvl) => sum + lvl.maxStars);

    return Scaffold(
      backgroundColor: CyberTheme.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16.0),
            // Header panel
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.sizeOf(context).width < 500
                    ? 12.0
                    : 24.0,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isNarrow = constraints.maxWidth < 460;

                  final titleCol = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                            'DRONESTEP',
                            style: CyberTheme.fontHeading(
                              size: 26.0,
                              color: themeColor,
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .slideX(begin: -0.1, end: 0.0),
                      Text(
                        'COCKPIT MISSION MANAGER',
                        style: CyberTheme.fontCode(
                          size: 11.0,
                          color: CyberTheme.textMuted,
                        ),
                      ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
                    ],
                  );

                  final batteryCard = const _BatteryStatusCard()
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .slideX(begin: 0.1, end: 0.0);

                  final starsCard =
                      CyberCard(
                            borderColor: CyberTheme.neonYellow,
                            backgroundColor: CyberTheme.cardBg,
                            borderWidth: 1.0,
                            chamferSize: 6.0,
                            showAccents: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14.0,
                                vertical: 8.0,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: CyberTheme.neonYellow,
                                      size: 18.0,
                                    ),
                                    const SizedBox(width: 6.0),
                                    Text(
                                      '$totalStarsCollected / $maxPossibleStars',
                                      style: CyberTheme.fontCode(
                                        size: 13.0,
                                        color: CyberTheme.neonYellow,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .slideX(begin: 0.1, end: 0.0);

                  final settingsButton =
                      InkWell(
                            onTap: () {
                              _playClick();
                              _showAccountSettingsDialog(context);
                            },
                            child: CyberCard(
                              borderColor: auth.currentUser != null
                                  ? CyberTheme.neonGreen
                                  : CyberTheme.neonCyan,
                              backgroundColor: CyberTheme.cardBg,
                              borderWidth: 1.0,
                              chamferSize: 6.0,
                              showAccents: false,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  auth.currentUser != null
                                      ? Icons.account_circle
                                      : Icons.account_circle_outlined,
                                  color: auth.currentUser != null
                                      ? CyberTheme.neonGreen
                                      : CyberTheme.neonCyan,
                                  size: 18.0,
                                ),
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .slideX(begin: 0.1, end: 0.0);

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [titleCol, settingsButton],
                        ),
                        const SizedBox(height: 12.0),
                        Row(
                          children: [
                            Expanded(child: batteryCard),
                            const SizedBox(width: 8.0),
                            Expanded(child: starsCard),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      titleCol,
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          batteryCard,
                          const SizedBox(width: 8.0),
                          starsCard,
                          const SizedBox(width: 8.0),
                          settingsButton,
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16.0),

            // Mode Navigation tab bar / Onboarding status
            if (seenTutorial)
              _buildModeNavigationBar(context, gameMode)
                  .animate()
                  .fadeIn(delay: 150.ms, duration: 500.ms)
                  .slideY(begin: 0.1, end: 0.0, curve: Curves.easeOutCubic)
            else
              Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.sizeOf(context).width < 500
                          ? 12.0
                          : 24.0,
                      vertical: 4.0,
                    ),
                    child: CyberCard(
                      borderColor: CyberTheme.neonCyan,
                      backgroundColor: CyberTheme.neonCyan.withValues(
                        alpha: 0.05,
                      ),
                      borderWidth: 1.0,
                      chamferSize: 4.0,
                      showAccents: false,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        alignment: Alignment.center,
                        child: Text(
                          'SYSTEM CALIBRATION REQUIRED: COMPLETE FLIGHT TRAINING',
                          style:
                              CyberTheme.fontCode(
                                size: 10.0,
                                color: CyberTheme.neonCyan,
                              ).copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 150.ms, duration: 500.ms)
                  .slideY(begin: 0.1, end: 0.0, curve: Curves.easeOutCubic),
            const SizedBox(height: 8.0),

            // Main Level Carousel Area
            Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PageView.builder(
                        key: ValueKey(
                          'pageview_${gameMode.name}_${seenTutorial}_${currentLevel.id}',
                        ),
                        controller: _pageController,
                        itemCount: visibleLevelsCount,
                        onPageChanged: (idx) {
                          setState(() {
                            _currentPageIndex = idx;
                          });
                        },
                        itemBuilder: (context, index) {
                          final level = levels[index];
                          final isLocked = gameMode == GameMode.daily
                              ? false
                              : (index >= maxUnlockedIndex);
                          final starsAchieved = starsMap[level.id] ?? 0;

                          return AnimatedScale(
                            scale: _currentPageIndex == index ? 1.0 : 0.93,
                            duration: const Duration(milliseconds: 200),
                            child: AnimatedOpacity(
                              opacity: _currentPageIndex == index ? 1.0 : 0.6,
                              duration: const Duration(milliseconds: 200),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10.0,
                                  vertical: 20.0,
                                ),
                                child: _buildLevelCard(
                                  level,
                                  isLocked,
                                  starsAchieved,
                                  themeColor,
                                  gameMode,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Left navigation arrow
                      if (_currentPageIndex > 0)
                        Positioned(
                          left: 12.0,
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: themeColor,
                              size: 28.0,
                            ),
                            onPressed: _prevPage,
                          ),
                        ),

                      // Right navigation arrow
                      if (_currentPageIndex < visibleLevelsCount - 1)
                        Positioned(
                          right: 12.0,
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: themeColor,
                              size: 28.0,
                            ),
                            onPressed: _nextPage,
                          ),
                        ),
                    ],
                  ),
                )
                .animate()
                .fadeIn(delay: 300.ms, duration: 600.ms)
                .slideY(begin: 0.05, end: 0.0, curve: Curves.easeOutCubic),

            const SizedBox(height: 16.0),
            // Bottom Mission Counter Indicator
            Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      gameMode == GameMode.daily
                          ? 'DAILY SECTOR CHALLENGE'
                          : 'MISSION ${_currentPageIndex + 1} / $totalLevels',
                      style: CyberTheme.fontCode(
                        size: 14.0,
                        color: CyberTheme.textMuted,
                      ),
                    ),
                  ],
                )
                .animate()
                .fadeIn(delay: 450.ms, duration: 500.ms)
                .slideY(begin: 0.1, end: 0.0, curve: Curves.easeOutCubic),
            const SizedBox(height: 24.0),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard(
    Level level,
    bool isLocked,
    int starsAchieved,
    Color themeColor,
    GameMode mode,
  ) {
    return CyberCard(
      borderColor: isLocked
          ? CyberTheme.textMuted.withValues(alpha: 0.3)
          : themeColor,
      backgroundColor: CyberTheme.cardBg,
      borderWidth: 1.5,
      chamferSize: 16.0,
      showAccents: true,
      child: LayoutBuilder(
        builder: (context, cardConstraints) {
          final isNarrowCard = cardConstraints.maxWidth < 360;
          final isWide = cardConstraints.maxWidth > 520;
          final paddingVal = isNarrowCard
              ? 12.0
              : (cardConstraints.maxWidth < 420 ? 16.0 : 24.0);

          final header = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      mode == GameMode.daily
                          ? 'DAILY TELEMETRY'
                          : 'MISSION ID: #${level.id.toString().padLeft(2, '0')}',
                      style: CyberTheme.fontCode(
                        size: isNarrowCard ? 12.0 : 14.0,
                        color: isLocked ? CyberTheme.textMuted : themeColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isNarrowCard ? 6.0 : 10.0,
                      vertical: isNarrowCard ? 2.0 : 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: isLocked
                          ? CyberTheme.textMuted.withValues(alpha: 0.1)
                          : (mode == GameMode.hard
                                    ? CyberTheme.neonPink
                                    : CyberTheme.neonGreen)
                                .withValues(alpha: 0.1),
                      border: Border.all(
                        color: isLocked
                            ? CyberTheme.textMuted.withValues(alpha: 0.3)
                            : (mode == GameMode.hard
                                      ? CyberTheme.neonPink
                                      : CyberTheme.neonGreen)
                                  .withValues(alpha: 0.3),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      isLocked
                          ? 'CLASSIFIED'
                          : (mode == GameMode.hard
                                ? 'HARD SIMULATION'
                                : (mode == GameMode.daily
                                      ? 'DAILY TRIAL'
                                      : 'READY TO DEPLOY')),
                      style: CyberTheme.fontCode(
                        size: isNarrowCard ? 9.5 : 11.0,
                        color: isLocked
                            ? CyberTheme.textMuted
                            : (mode == GameMode.hard
                                  ? CyberTheme.neonPink
                                  : CyberTheme.neonGreen),
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isNarrowCard ? 8.0 : 12.0),
              Text(
                level.title,
                style: CyberTheme.fontHeading(
                  size: isNarrowCard ? 18.0 : 22.0,
                  color: isLocked ? CyberTheme.textMuted : CyberTheme.textMain,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isNarrowCard ? 4.0 : 8.0),
              Row(
                children: List.generate(level.maxStars, (index) {
                  final isLit = !isLocked && index < starsAchieved;
                  final isFourthStar = index == 3;
                  final litColor = isFourthStar
                      ? CyberTheme.neonCyan
                      : CyberTheme.neonYellow;
                  return Icon(
                    isLit
                        ? (isFourthStar ? Icons.diamond : Icons.star)
                        : (isFourthStar
                              ? Icons.diamond_outlined
                              : Icons.star_border),
                    size: isNarrowCard ? 18.0 : 24.0,
                    color: isLit
                        ? litColor
                        : CyberTheme.textMuted.withValues(
                            alpha: isLocked ? 0.1 : 0.3,
                          ),
                  );
                }),
              ),
            ],
          );

          final mapPreview = SizedBox(
            width: isWide ? 170.0 : (isNarrowCard ? 100.0 : 130.0),
            height: isWide ? 170.0 : (isNarrowCard ? 100.0 : 130.0),
            child: MissionPreviewMap(
              level: level,
              themeColor: themeColor,
              isLocked: isLocked,
            ),
          );

          final briefingText = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'MISSION BRIEFING:',
                style: CyberTheme.fontCode(
                  size: isNarrowCard ? 13.0 : 14.0,
                  color: isLocked ? CyberTheme.textMuted : themeColor,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6.0),
              Text(
                isLocked
                    ? 'Classified. Complete previous simulation stages to unlock flight details.'
                    : level.description,
                style: CyberTheme.fontBody(
                  size: isNarrowCard ? 13.5 : 15.0,
                  color: isLocked
                      ? CyberTheme.textMuted.withValues(alpha: 0.7)
                      : CyberTheme.textMain.withValues(alpha: 0.9),
                ),
              ),
            ],
          );

          final targets = isLocked
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CyberCard(
                      borderColor: CyberTheme.neonYellow.withValues(alpha: 0.3),
                      backgroundColor: CyberTheme.neonYellow.withValues(
                        alpha: 0.05,
                      ),
                      borderWidth: 1.0,
                      chamferSize: 8.0,
                      showAccents: false,
                      child: Padding(
                        padding: EdgeInsets.all(isNarrowCard ? 6.0 : 10.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.military_tech_rounded,
                              color: CyberTheme.neonYellow,
                              size: isNarrowCard ? 15.0 : 18.0,
                            ),
                            SizedBox(width: isNarrowCard ? 6.0 : 8.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'STAR 3 EFFICIENCY TARGET',
                                    style: CyberTheme.fontCode(
                                      size: isNarrowCard ? 12.0 : 13.0,
                                      color: CyberTheme.neonYellow,
                                    ).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Finish in <= ${level.star3Target} program blocks',
                                    style: CyberTheme.fontBody(
                                      size: isNarrowCard ? 12.0 : 13.0,
                                      color: CyberTheme.textMain.withValues(
                                        alpha: 0.8,
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
                    if (level.maxStars == 4) ...[
                      const SizedBox(height: 8.0),
                      CyberCard(
                        borderColor: CyberTheme.neonCyan.withValues(alpha: 0.3),
                        backgroundColor: CyberTheme.neonCyan.withValues(
                          alpha: 0.05,
                        ),
                        borderWidth: 1.0,
                        chamferSize: 8.0,
                        showAccents: false,
                        child: Padding(
                          padding: EdgeInsets.all(isNarrowCard ? 6.0 : 10.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.diamond,
                                color: CyberTheme.neonCyan,
                                size: isNarrowCard ? 13.0 : 16.0,
                              ),
                              SizedBox(width: isNarrowCard ? 8.0 : 10.0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'DIAMOND STAR TARGET (+5 ENERGY)',
                                      style: CyberTheme.fontCode(
                                        size: isNarrowCard ? 8.0 : 9.0,
                                        color: CyberTheme.neonCyan,
                                      ).copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Finish in < ${level.star3Target} program blocks',
                                      style: CyberTheme.fontBody(
                                        size: isNarrowCard ? 11.0 : 12.0,
                                        color: CyberTheme.textMain.withValues(
                                          alpha: 0.8,
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
                    ],
                  ],
                );

          final actionButton = isLocked
              ? CyberCard(
                  borderColor: CyberTheme.textMuted.withValues(alpha: 0.2),
                  backgroundColor: CyberTheme.textMuted.withValues(alpha: 0.05),
                  borderWidth: 1.0,
                  chamferSize: 8.0,
                  showAccents: false,
                  child: Container(
                    height: isNarrowCard ? 44.0 : 52.0,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            color: CyberTheme.textMuted,
                            size: isNarrowCard ? 16.0 : 20.0,
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            'CLASSIFIED / SECURE',
                            style: CyberTheme.fontCode(
                              size: isNarrowCard ? 11.5 : 13.0,
                              color: CyberTheme.textMuted,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : InkWell(
                  onTap: () async {
                    _playClick();
                    final curBattery = ref.read(pilotBatteryProvider);
                    if (curBattery < 5) {
                      _showLowBatteryDialog(context);
                      return;
                    }
                    await ref
                        .read(pilotBatteryProvider.notifier)
                        .spendBattery(5);
                    ref.read(currentLevelProvider.notifier).setLevel(level);
                    ref.read(gameStateProvider.notifier).clearProgram();
                    ref.read(gameStateProvider.notifier).resetSimulation();
                    ref
                        .read(appScreenProvider.notifier)
                        .toScreen(AppScreen.game);
                  },
                  child: CyberCard(
                    borderColor: themeColor,
                    backgroundColor: themeColor,
                    borderWidth: 0.0,
                    chamferSize: 8.0,
                    showAccents: false,
                    child: Container(
                      height: isNarrowCard ? 44.0 : 52.0,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.flight_takeoff_rounded,
                              size: isNarrowCard ? 16.0 : 20.0,
                              color: themeColor == CyberTheme.neonYellow
                                  ? CyberTheme.darkBg
                                  : (themeColor == CyberTheme.neonPink
                                        ? Colors.white
                                        : CyberTheme.darkBg),
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              'START LEVEL SIMULATION',
                              style: CyberTheme.fontHeading(
                                size: isNarrowCard ? 11.5 : 14.0,
                                color: themeColor == CyberTheme.neonYellow
                                    ? CyberTheme.darkBg
                                    : (themeColor == CyberTheme.neonPink
                                          ? Colors.white
                                          : CyberTheme.darkBg),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ).animate().shimmer(delay: 1000.ms, duration: 1500.ms);

          return Container(
            padding: EdgeInsets.all(paddingVal),
            child: isWide
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      const SizedBox(height: 16.0),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    briefingText,
                                    const SizedBox(height: 16.0),
                                    targets,
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 20.0),
                            Center(child: mapPreview),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      actionButton,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      const SizedBox(height: 12.0),
                      Center(child: mapPreview),
                      const SizedBox(height: 12.0),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              briefingText,
                              const SizedBox(height: 12.0),
                              targets,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12.0),
                      actionButton,
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _AccountDialogContent extends ConsumerStatefulWidget {
  const _AccountDialogContent();

  @override
  ConsumerState<_AccountDialogContent> createState() =>
      _AccountDialogContentState();
}

class _AccountDialogContentState extends ConsumerState<_AccountDialogContent> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegistering = false;
  String? _localErrorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isLoggedIn = auth.currentUser != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 24.0,
        vertical: 36.0,
      ),
      child: CyberCard(
        borderColor: isLoggedIn ? CyberTheme.neonGreen : CyberTheme.neonCyan,
        backgroundColor: const Color(0xFF0E101A),
        borderWidth: 1.5,
        chamferSize: 12.0,
        showAccents: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isLoggedIn
                            ? Icons.verified_user_rounded
                            : Icons.shield_rounded,
                        color: isLoggedIn
                            ? CyberTheme.neonGreen
                            : CyberTheme.neonCyan,
                        size: 20.0,
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        isLoggedIn ? 'PILOT DATALINK' : 'PILOT AUTHENTICATION',
                        style: CyberTheme.fontHeading(
                          size: 16.0,
                          color: isLoggedIn
                              ? CyberTheme.neonGreen
                              : CyberTheme.neonCyan,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: CyberTheme.textMuted,
                      size: 20.0,
                    ),
                    onPressed: () {
                      ref.read(audioControllerProvider).playClick();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16.0),

              if (isLoggedIn) ...[
                // Logged in UI
                Text(
                  'PILOT PROFILE',
                  style: CyberTheme.fontCode(
                    size: 11.0,
                    color: CyberTheme.neonGreen,
                  ).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                const SizedBox(height: 8.0),
                CyberCard(
                  borderColor: CyberTheme.neonGreen.withValues(alpha: 0.2),
                  backgroundColor: Colors.black38,
                  borderWidth: 1.0,
                  chamferSize: 8.0,
                  showAccents: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.account_circle,
                              color: CyberTheme.neonGreen,
                              size: 40.0,
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    auth.currentUser!.toUpperCase(),
                                    style: CyberTheme.fontHeading(
                                      size: 18.0,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'STATUS: ACTIVE TRANSMISSION SYNC',
                                    style: CyberTheme.fontCode(
                                      size: 10.0,
                                      color: CyberTheme.neonGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16.0),
                        const Divider(
                          color: CyberTheme.borderTranslucent,
                          height: 1.0,
                        ),
                        const SizedBox(height: 16.0),
                        // Stats or extra info
                        Text(
                          'DATA STORAGE STATUS:',
                          style: CyberTheme.fontCode(
                            size: 11.0,
                            color: CyberTheme.textMuted,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'All level stages and stars achieved are automatically saved under this pilot ID.',
                          style: CyberTheme.fontBody(
                            size: 12.0,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),
                // Logout button
                InkWell(
                  onTap: () async {
                    ref.read(audioControllerProvider).playClick();
                    final navigator = Navigator.of(context);
                    final confirm = await showCyberDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF0E101A),
                        title: Text(
                          'CLOSE DATALINK',
                          style: CyberTheme.fontHeading(
                            size: 16.0,
                            color: CyberTheme.neonPink,
                          ),
                        ),
                        content: Text(
                          'Are you sure you want to disconnect telemetry and log out of this pilot profile?',
                          style: CyberTheme.fontBody(
                            size: 13.0,
                            color: Colors.white70,
                          ),
                        ),
                        actions: [
                          TextButton(
                            child: Text(
                              'CANCEL',
                              style: CyberTheme.fontCode(
                                size: 12.0,
                                color: CyberTheme.textMuted,
                              ),
                            ),
                            onPressed: () {
                              ref.read(audioControllerProvider).playClick();
                              Navigator.of(ctx).pop(false);
                            },
                          ),
                          TextButton(
                            child: Text(
                              'LOGOUT',
                              style: CyberTheme.fontCode(
                                size: 12.0,
                                color: CyberTheme.neonPink,
                              ),
                            ),
                            onPressed: () {
                              ref.read(audioControllerProvider).playClick();
                              Navigator.of(ctx).pop(true);
                            },
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await ref.read(authProvider.notifier).logout();
                      if (mounted) {
                        navigator.pop();
                      }
                    }
                  },
                  child: CyberCard(
                    borderColor: CyberTheme.neonPink,
                    backgroundColor: Colors.transparent,
                    borderWidth: 1.0,
                    chamferSize: 8.0,
                    showAccents: false,
                    child: Container(
                      height: 46.0,
                      alignment: Alignment.center,
                      child: Text(
                        'DISCONNECT PILOT PROFILE',
                        style: CyberTheme.fontHeading(
                          size: 13.0,
                          color: CyberTheme.neonPink,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Guest / Login Form
                Text(
                  'STATUS: UNREGISTERED PILOT (OFFLINE GUEST)',
                  style: CyberTheme.fontCode(
                    size: 10.0,
                    color: CyberTheme.neonCyan,
                  ),
                ),
                const SizedBox(height: 16.0),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PILOT ID / USERNAME',
                        style: CyberTheme.fontCode(
                          size: 10.0,
                          color: CyberTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      TextFormField(
                        controller: _usernameController,
                        style: CyberTheme.fontBody(
                          size: 14.0,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter pilot designation',
                          hintStyle: CyberTheme.fontBody(
                            size: 14.0,
                            color: Colors.white30,
                          ),
                          filled: true,
                          fillColor: Colors.black38,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide(
                              color: CyberTheme.neonCyan.withValues(alpha: 0.3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide(
                              color: CyberTheme.neonCyan.withValues(alpha: 0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(
                              color: CyberTheme.neonCyan,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14.0,
                            vertical: 12.0,
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 16.0),
                      Text(
                        'SECURITY PASSKEY',
                        style: CyberTheme.fontCode(
                          size: 10.0,
                          color: CyberTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: CyberTheme.fontBody(
                          size: 14.0,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter security passkey',
                          hintStyle: CyberTheme.fontBody(
                            size: 14.0,
                            color: Colors.white30,
                          ),
                          filled: true,
                          fillColor: Colors.black38,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide(
                              color: CyberTheme.neonCyan.withValues(alpha: 0.3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide(
                              color: CyberTheme.neonCyan.withValues(alpha: 0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(
                              color: CyberTheme.neonCyan,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14.0,
                            vertical: 12.0,
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12.0),
                if (_localErrorMessage != null || auth.message != null)
                  Text(
                    _localErrorMessage ?? auth.message!,
                    style: CyberTheme.fontCode(
                      size: 12.0,
                      color: CyberTheme.neonPink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 16.0),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _isLoading
                            ? null
                            : () async {
                                ref.read(audioControllerProvider).playClick();
                                if (!_formKey.currentState!.validate()) return;
                                setState(() {
                                  _isLoading = true;
                                  _localErrorMessage = null;
                                });
                                final navigator = Navigator.of(context);
                                final success = await ref
                                    .read(authProvider.notifier)
                                    .login(
                                      _usernameController.text,
                                      _passwordController.text,
                                    );
                                setState(() {
                                  _isLoading = false;
                                });
                                if (success && mounted) {
                                  navigator.pop();
                                }
                              },
                        child: CyberCard(
                          borderColor: CyberTheme.neonCyan,
                          backgroundColor: CyberTheme.neonCyan.withValues(
                            alpha: 0.1,
                          ),
                          borderWidth: 1.0,
                          chamferSize: 8.0,
                          showAccents: false,
                          child: Container(
                            height: 46.0,
                            alignment: Alignment.center,
                            child: _isLoading && !_isRegistering
                                ? const SizedBox(
                                    height: 18.0,
                                    width: 18.0,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0,
                                      color: CyberTheme.neonCyan,
                                    ),
                                  )
                                : Text(
                                    'ESTABLISH LINK',
                                    style: CyberTheme.fontHeading(
                                      size: 12.0,
                                      color: CyberTheme.neonCyan,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: InkWell(
                        onTap: _isLoading
                            ? null
                            : () async {
                                ref.read(audioControllerProvider).playClick();
                                if (!_formKey.currentState!.validate()) return;
                                setState(() {
                                  _isLoading = true;
                                  _localErrorMessage = null;
                                  _isRegistering = true;
                                });
                                final navigator = Navigator.of(context);
                                final success = await ref
                                    .read(authProvider.notifier)
                                    .register(
                                      _usernameController.text,
                                      _passwordController.text,
                                    );
                                setState(() {
                                  _isLoading = false;
                                  _isRegistering = false;
                                });
                                if (success && mounted) {
                                  navigator.pop();
                                }
                              },
                        child: CyberCard(
                          borderColor: CyberTheme.neonGreen,
                          backgroundColor: CyberTheme.neonGreen,
                          borderWidth: 0.0,
                          chamferSize: 8.0,
                          showAccents: false,
                          child: Container(
                            height: 46.0,
                            alignment: Alignment.center,
                            child: _isLoading && _isRegistering
                                ? const SizedBox(
                                    height: 18.0,
                                    width: 18.0,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0,
                                      color: CyberTheme.darkBg,
                                    ),
                                  )
                                : Text(
                                    'NEW PILOT',
                                    style: CyberTheme.fontHeading(
                                      size: 12.0,
                                      color: CyberTheme.darkBg,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BatteryCooldownDialogContent extends ConsumerStatefulWidget {
  const _BatteryCooldownDialogContent();

  @override
  ConsumerState<_BatteryCooldownDialogContent> createState() =>
      _BatteryCooldownDialogContentState();
}

class _BatteryCooldownDialogContentState
    extends ConsumerState<_BatteryCooldownDialogContent> {
  Timer? _dialogTimer;

  @override
  void initState() {
    super.initState();
    _dialogTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _dialogTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final mStr = m.toString().padLeft(2, '0');
    final sStr = s.toString().padLeft(2, '0');
    return '$mStr:$sStr';
  }

  String _formatLongDuration(int seconds) {
    if (seconds <= 0) return '00:00:00';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final hStr = h.toString().padLeft(2, '0');
    final mStr = m.toString().padLeft(2, '0');
    final sStr = s.toString().padLeft(2, '0');
    return '$hStr:$mStr:$sStr';
  }

  @override
  Widget build(BuildContext context) {
    final battery = ref.watch(pilotBatteryProvider);
    final batteryNotifier = ref.read(pilotBatteryProvider.notifier);
    final isFull = battery >= PilotBatteryNotifier.maxBattery;

    final secondsRemaining = batteryNotifier.getSecondsRemaining();
    final totalSecondsRemaining = batteryNotifier.getTotalSecondsRemaining();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 24.0,
        vertical: 36.0,
      ),
      child: CyberCard(
        borderColor: isFull ? CyberTheme.neonGreen : CyberTheme.neonCyan,
        backgroundColor: const Color(0xFF0E101A),
        borderWidth: 1.5,
        chamferSize: 12.0,
        showAccents: true,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                            Icons.battery_charging_full,
                            color: isFull
                                ? CyberTheme.neonGreen
                                : CyberTheme.neonCyan,
                            size: 20.0,
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(
                            duration: 1.seconds,
                            end: const Offset(1.15, 1.15),
                          ),
                      const SizedBox(width: 8.0),
                      Text(
                        'PILOT POWER SYS',
                        style: CyberTheme.fontHeading(
                          size: 16.0,
                          color: isFull
                              ? CyberTheme.neonGreen
                              : CyberTheme.neonCyan,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: CyberTheme.textMuted,
                      size: 20.0,
                    ),
                    onPressed: () {
                      ref.read(audioControllerProvider).playClick();
                      Navigator.pop(context);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),

              // Battery Status card
              CyberCard(
                borderColor:
                    (isFull ? CyberTheme.neonGreen : CyberTheme.neonCyan)
                        .withValues(alpha: 0.15),
                backgroundColor: Colors.black38,
                borderWidth: 1.0,
                chamferSize: 8.0,
                showAccents: false,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CURRENT CELLS',
                            style: CyberTheme.fontCode(
                              size: 11.0,
                              color: CyberTheme.textMuted,
                            ),
                          ),
                          Text(
                            '$battery / ${PilotBatteryNotifier.maxBattery} PWR',
                            style: CyberTheme.fontCode(
                              size: 13.0,
                              color: isFull
                                  ? CyberTheme.neonGreen
                                  : CyberTheme.neonCyan,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12.0),
                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4.0),
                        child: Container(
                          height: 10.0,
                          color: Colors.black54,
                          child: Stack(
                            children: [
                              LayoutBuilder(
                                builder: (ctx, constraints) {
                                  final double progress =
                                      battery / PilotBatteryNotifier.maxBattery;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: constraints.maxWidth * progress,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isFull
                                            ? [
                                                CyberTheme.neonGreen.withValues(
                                                  alpha: 0.5,
                                                ),
                                                CyberTheme.neonGreen,
                                              ]
                                            : [
                                                CyberTheme.neonCyan.withValues(
                                                  alpha: 0.5,
                                                ),
                                                CyberTheme.neonCyan,
                                              ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20.0),

              // Countdown timers
              if (!isFull) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'NEXT CHARGE UNIT',
                      style: CyberTheme.fontCode(
                        size: 12.0,
                        color: CyberTheme.textMuted,
                      ),
                    ),
                    Text(
                          _formatDuration(secondsRemaining),
                          style: CyberTheme.fontCode(
                            size: 14.0,
                            color: CyberTheme.neonCyan,
                          ).copyWith(fontWeight: FontWeight.bold),
                        )
                        .animate(key: ValueKey(secondsRemaining))
                        .custom(
                          duration: 400.ms,
                          builder: (context, val, child) {
                            return Opacity(opacity: val, child: child);
                          },
                        ),
                  ],
                ),
                const SizedBox(height: 12.0),
                const Divider(color: Colors.white12),
                const SizedBox(height: 12.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'FULL CAPACITOR CHARGE',
                      style: CyberTheme.fontCode(
                        size: 12.0,
                        color: CyberTheme.textMuted,
                      ),
                    ),
                    Text(
                      _formatLongDuration(totalSecondsRemaining),
                      style: CyberTheme.fontCode(
                        size: 14.0,
                        color: CyberTheme.neonYellow,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  alignment: Alignment.center,
                  child:
                      Text(
                            'ALL ENERGY CAPACITORS ONLINE',
                            style: CyberTheme.fontHeading(
                              size: 12.0,
                              color: CyberTheme.neonGreen,
                            ).copyWith(letterSpacing: 1.0),
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .fadeIn(duration: 1.seconds),
                ),
              ],
              const SizedBox(height: 24.0),

              // Developer Actions Section
              CyberCard(
                borderColor: CyberTheme.neonYellow.withValues(alpha: 0.2),
                backgroundColor: const Color(0xFF161311),
                borderWidth: 1.0,
                chamferSize: 6.0,
                showAccents: false,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'SIMULATOR CONTROLS',
                        style: CyberTheme.fontCode(
                          size: 10.0,
                          color: CyberTheme.neonYellow,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                ref.read(audioControllerProvider).playClick();
                                ref
                                    .read(pilotBatteryProvider.notifier)
                                    .spendBattery(10);
                              },
                              child: CyberCard(
                                borderColor: CyberTheme.neonPink,
                                backgroundColor: Colors.transparent,
                                borderWidth: 1.0,
                                chamferSize: 4.0,
                                showAccents: false,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6.0,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'DRAIN 10',
                                      style: CyberTheme.fontCode(
                                        size: 10.0,
                                        color: CyberTheme.neonPink,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                ref.read(audioControllerProvider).playClick();
                                ref
                                    .read(pilotBatteryProvider.notifier)
                                    .rewardBattery(10);
                              },
                              child: CyberCard(
                                borderColor: CyberTheme.neonGreen,
                                backgroundColor: Colors.transparent,
                                borderWidth: 1.0,
                                chamferSize: 4.0,
                                showAccents: false,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6.0,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'RELOAD 10',
                                      style: CyberTheme.fontCode(
                                        size: 10.0,
                                        color: CyberTheme.neonGreen,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20.0),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () {
                    ref.read(audioControllerProvider).playClick();
                    Navigator.pop(context);
                  },
                  child: CyberCard(
                    borderColor: isFull
                        ? CyberTheme.neonGreen
                        : CyberTheme.neonCyan,
                    backgroundColor: isFull
                        ? CyberTheme.neonGreen
                        : CyberTheme.neonCyan,
                    borderWidth: 0.0,
                    chamferSize: 6.0,
                    showAccents: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 10.0,
                      ),
                      child: Text(
                        'DISMISS',
                        style: CyberTheme.fontHeading(
                          size: 11.0,
                          color: Colors.black,
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
  }
}

class _BatteryStatusCard extends ConsumerStatefulWidget {
  const _BatteryStatusCard();

  @override
  ConsumerState<_BatteryStatusCard> createState() => _BatteryStatusCardState();
}

class _BatteryStatusCardState extends ConsumerState<_BatteryStatusCard> {
  Timer? _cardTimer;

  @override
  void initState() {
    super.initState();
    _cardTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _cardTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final mStr = m.toString().padLeft(2, '0');
    final sStr = s.toString().padLeft(2, '0');
    return '$mStr:$sStr';
  }

  @override
  Widget build(BuildContext context) {
    final battery = ref.watch(pilotBatteryProvider);
    final batteryNotifier = ref.read(pilotBatteryProvider.notifier);
    final isFull = battery >= PilotBatteryNotifier.maxBattery;
    final secondsRemaining = batteryNotifier.getSecondsRemaining();

    final Color themeColor = isFull
        ? CyberTheme.neonCyan
        : CyberTheme.neonYellow;

    return InkWell(
      onTap: () {
        ref.read(audioControllerProvider).playClick();
        showCyberDialog(
          context: context,
          builder: (context) => const _BatteryCooldownDialogContent(),
        );
      },
      borderRadius: BorderRadius.circular(6.0),
      child: CyberCard(
        borderColor: themeColor,
        backgroundColor: CyberTheme.cardBg,
        borderWidth: 1.0,
        chamferSize: 6.0,
        showAccents: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isFull ? Icons.battery_full : Icons.battery_charging_full,
                  color: themeColor,
                  size: 18.0,
                ),
                const SizedBox(width: 6.0),
                Text(
                  isFull
                      ? '$battery/50 PWR'
                      : '$battery/50 PWR (${_formatDuration(secondsRemaining)})',
                  style: CyberTheme.fontCode(size: 13.0, color: themeColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

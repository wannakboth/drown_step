import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/program_block.dart';
import '../models/level.dart';
import '../providers/game_state.dart';
import '../theme/colors.dart';
import 'cyber_card.dart';
import 'cyber_dialog.dart';
import 'tutorial_overlay.dart';
import '../models/tutorial_keys.dart';
import '../providers/audio_provider.dart';

class TutorialActionTriggerNotifier extends Notifier<TutorialTarget?> {
  @override
  TutorialTarget? build() => null;

  void trigger(TutorialTarget? target) {
    state = target;
  }
}

final tutorialActionTriggerProvider =
    NotifierProvider<TutorialActionTriggerNotifier, TutorialTarget?>(
      TutorialActionTriggerNotifier.new,
    );

List<ProgramBlock> findAllRepeatBlocks(List<ProgramBlock> list) {
  final result = <ProgramBlock>[];
  for (final block in list) {
    if (block.type == BlockType.repeat) {
      result.add(block);
    }
    result.addAll(findAllRepeatBlocks(block.body));
    result.addAll(findAllRepeatBlocks(block.elseBody));
  }
  return result;
}

class CommandPanel extends ConsumerStatefulWidget {
  const CommandPanel({super.key});

  @override
  ConsumerState<CommandPanel> createState() => _CommandPanelState();
}

class _CommandPanelState extends ConsumerState<CommandPanel> {
  late final ScrollController _workspaceScrollController;
  late final ScrollController _paletteScrollController;
  late final ScrollController _hintStepsScrollController;
  int _currentTutorialStep = 0;
  int _nextHintStepIndex = 0;
  List<ActionType>? _cachedHintSteps;
  String? _lastLevelId;
  OverlayEntry? _tutorialOverlay;
  bool _tutorialDismissed = false;
  bool _isTransitioning = false;
  int? _lastShownStepIndex;
  Timer? _tutorialTimer;

  String? _getLastBlockId(DroneGameState state, String? parentId, bool isElse) {
    if (parentId == null) {
      if (state.program.isNotEmpty) {
        return state.program.last.id;
      }
      return null;
    }
    ProgramBlock? findBlock(List<ProgramBlock> blocks, String id) {
      for (final b in blocks) {
        if (b.id == id) return b;
        final res = findBlock(b.body, id);
        if (res != null) return res;
        final res2 = findBlock(b.elseBody, id);
        if (res2 != null) return res2;
      }
      return null;
    }

    final parent = findBlock(state.program, parentId);
    if (parent != null) {
      final list = isElse ? parent.elseBody : parent.body;
      if (list.isNotEmpty) {
        return list.last.id;
      }
    }
    return null;
  }

  void _executeTutorialTargetAction(TutorialTarget target, bool isNext) {
    final state = ref.read(gameStateProvider);
    final notifier = ref.read(gameStateProvider.notifier);
    final activeContainer = ref.read(activeContainerProvider);

    switch (target) {
      case TutorialTarget.telemetry:
        break;

      case TutorialTarget.console:
        break;

      case TutorialTarget.takeoff:
      case TutorialTarget.land:
      case TutorialTarget.moveForward:
      case TutorialTarget.turnLeft:
      case TutorialTarget.turnRight:
        if (isNext) {
          ActionType? action;
          if (target == TutorialTarget.takeoff) action = ActionType.takeoff;
          if (target == TutorialTarget.land) action = ActionType.land;
          if (target == TutorialTarget.moveForward) action = ActionType.forward;
          if (target == TutorialTarget.turnLeft) action = ActionType.rotateLeft;
          if (target == TutorialTarget.turnRight) {
            action = ActionType.rotateRight;
          }
          if (action != null) {
            final newBlockId = 'block_${DateTime.now().microsecondsSinceEpoch}';
            ref
                .read(lastAddedBlockIdProvider.notifier)
                .setLastAddedId(newBlockId);
            notifier.addBlock(
              ProgramBlock(
                id: newBlockId,
                type: BlockType.action,
                action: action,
              ),
              parentId: activeContainer.parentId,
              isElse: activeContainer.isElse,
            );
          }
        } else {
          final lastId = _getLastBlockId(
            state,
            activeContainer.parentId,
            activeContainer.isElse,
          );
          if (lastId != null) {
            notifier.removeBlock(lastId);
          }
        }
        break;

      case TutorialTarget.repeatBlock:
        if (isNext) {
          final newBlockId = 'block_${DateTime.now().microsecondsSinceEpoch}';
          ref
              .read(lastAddedBlockIdProvider.notifier)
              .setLastAddedId(newBlockId);
          notifier.addBlock(
            ProgramBlock(
              id: newBlockId,
              type: BlockType.repeat,
              repeatCount: 2,
            ),
            parentId: activeContainer.parentId,
            isElse: activeContainer.isElse,
          );
          ref.read(activeContainerProvider.notifier).select(newBlockId);
        } else {
          final lastId = _getLastBlockId(
            state,
            activeContainer.parentId,
            activeContainer.isElse,
          );
          if (lastId != null) {
            if (activeContainer.parentId == lastId) {
              ref.read(activeContainerProvider.notifier).reset();
            }
            notifier.removeBlock(lastId);
          }
        }
        break;

      case TutorialTarget.firstRepeatDropdown:
      case TutorialTarget.secondRepeatDropdown:
        final allRepeats = findAllRepeatBlocks(state.program);
        final idx = target == TutorialTarget.firstRepeatDropdown ? 0 : 1;
        if (allRepeats.length > idx) {
          notifier.updateBlockRepeat(allRepeats[idx].id, isNext ? 3 : 2);
        }
        break;

      case TutorialTarget.firstRepeatBlock:
      case TutorialTarget.secondRepeatBlock:
        if (isNext) {
          final allRepeats = findAllRepeatBlocks(state.program);
          final idx = target == TutorialTarget.firstRepeatBlock ? 0 : 1;
          if (allRepeats.length > idx) {
            ref
                .read(activeContainerProvider.notifier)
                .select(allRepeats[idx].id);
          }
        } else {
          ref.read(activeContainerProvider.notifier).reset();
        }
        break;

      case TutorialTarget.workspace:
        if (isNext) {
          final currentStep = state.level.tutorialSteps?[_currentTutorialStep];
          if (state.level.id == 'T1' &&
              currentStep != null &&
              currentStep.message.contains("rebuild")) {
            notifier.clearProgram();
            final blocks = [
              ActionType.takeoff,
              ActionType.forward,
              ActionType.land,
              ActionType.takeoff,
              ActionType.forward,
              ActionType.land,
            ];
            for (final act in blocks) {
              notifier.addBlock(
                ProgramBlock(
                  id: 'block_${DateTime.now().microsecondsSinceEpoch}_${act.name}',
                  type: BlockType.action,
                  action: act,
                ),
              );
            }
          } else {
            ref.read(activeContainerProvider.notifier).reset();
          }
        } else {
          if (state.level.id == 'T1') {
            notifier.clearProgram();
          } else if (state.level.id == 'T3') {
            final repeats = findAllRepeatBlocks(state.program);
            if (_currentTutorialStep - 1 == 5 && repeats.isNotEmpty) {
              ref.read(activeContainerProvider.notifier).select(repeats[0].id);
            } else if (_currentTutorialStep - 1 == 13 && repeats.length > 1) {
              ref.read(activeContainerProvider.notifier).select(repeats[1].id);
            }
          }
        }
        break;

      case TutorialTarget.speed:
        notifier.setSpeed(isNext ? 2.0 : 1.0);
        break;

      case TutorialTarget.hint:
        if (isNext) {
          _showHintDialog(context, state.level);
        } else {
          if (mounted) Navigator.of(context).pop();
        }
        break;

      case TutorialTarget.dismissHint:
        if (isNext) {
          if (mounted) Navigator.of(context).pop();
        } else {
          _showHintDialog(context, state.level);
        }
        break;

      case TutorialTarget.reset:
        if (isNext) {
          _showConfirmDialog(
            context,
            title: 'RETRY SIMULATION',
            message: 'Are you sure you want to restart the flight simulation?',
            onConfirm: () {
              notifier.clearProgram();
              notifier.resetSimulation();
            },
          );
        } else {
          if (mounted) Navigator.of(context).pop();
        }
        break;

      case TutorialTarget.confirmReset:
        if (isNext) {
          if (mounted) Navigator.of(context).pop();
          notifier.clearProgram();
          notifier.resetSimulation();
        } else {
          _showConfirmDialog(
            context,
            title: 'RETRY SIMULATION',
            message: 'Are you sure you want to restart the flight simulation?',
            onConfirm: () {
              notifier.clearProgram();
              notifier.resetSimulation();
            },
          );
        }
        break;

      case TutorialTarget.runProgram:
        if (isNext) {
          notifier.runSimulation();
        } else {
          notifier.pauseSimulation();
        }
        break;

      default:
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _workspaceScrollController = ScrollController();
    _paletteScrollController = ScrollController();
    _hintStepsScrollController = ScrollController();
  }

  @override
  void dispose() {
    _tutorialTimer?.cancel();
    _tutorialTimer = null;
    _tutorialOverlay?.remove();
    _tutorialOverlay = null;
    _workspaceScrollController.dispose();
    _paletteScrollController.dispose();
    _hintStepsScrollController.dispose();
    super.dispose();
  }

  void _playClick() {
    ref.read(audioControllerProvider).playClick();
  }

  GlobalKey? _keyForTarget(TutorialTarget t) {
    switch (t) {
      case TutorialTarget.takeoff:
        return TutorialKeys.takeoff;
      case TutorialTarget.land:
        return TutorialKeys.land;
      case TutorialTarget.moveForward:
        return TutorialKeys.moveForward;
      case TutorialTarget.turnLeft:
        return TutorialKeys.turnLeft;
      case TutorialTarget.turnRight:
        return TutorialKeys.turnRight;
      case TutorialTarget.ascend:
        return TutorialKeys.ascend;
      case TutorialTarget.descend:
        return TutorialKeys.descend;
      case TutorialTarget.repeatBlock:
        return TutorialKeys.repeatBlock;
      case TutorialTarget.whileBlock:
        return TutorialKeys.whileBlock;
      case TutorialTarget.ifElse:
        return TutorialKeys.ifElse;
      case TutorialTarget.workspace:
        return TutorialKeys.workspace;
      case TutorialTarget.runProgram:
        return TutorialKeys.runProgram;
      case TutorialTarget.telemetry:
        return TutorialKeys.telemetry;
      case TutorialTarget.console:
        return TutorialKeys.console;
      case TutorialTarget.gridArena:
        return TutorialKeys.gridArena;
      case TutorialTarget.speed:
        return TutorialKeys.speed;
      case TutorialTarget.hint:
        return TutorialKeys.hint;
      case TutorialTarget.dismissHint:
        return TutorialKeys.dismissHint;
      case TutorialTarget.reset:
        return TutorialKeys.reset;
      case TutorialTarget.confirmReset:
        return TutorialKeys.confirmReset;
      case TutorialTarget.firstRepeatBlock:
        return TutorialKeys.firstRepeatBlock;
      case TutorialTarget.firstRepeatDropdown:
        return TutorialKeys.firstRepeatDropdown;
      case TutorialTarget.secondRepeatBlock:
        return TutorialKeys.secondRepeatBlock;
      case TutorialTarget.secondRepeatDropdown:
        return TutorialKeys.secondRepeatDropdown;
      case TutorialTarget.none:
        return null;
    }
  }

  void _showTutorialStep(List<TutorialStep> steps) {
    // Cancel any existing timer/overlay transition
    _tutorialTimer?.cancel();
    _tutorialTimer = null;

    // Remove existing overlay immediately
    _tutorialOverlay?.remove();
    _tutorialOverlay = null;
    _isTransitioning = true;

    if (_currentTutorialStep >= steps.length) {
      _isTransitioning = false;
      return;
    }

    final expectedStep = _currentTutorialStep;
    _lastShownStepIndex = expectedStep;

    final step = steps[_currentTutorialStep];
    final targetKey = _keyForTarget(step.target);

    final levelId = ref.read(gameStateProvider).level.id;
    if (levelId == 'T1') {
      final shouldExpand =
          !(_currentTutorialStep == 2 || _currentTutorialStep == 3);
      if (ref.read(consoleExpandedProvider) != shouldExpand) {
        ref.read(consoleExpandedProvider.notifier).setExpanded(shouldExpand);
      }
    }

    void insertOverlay() {
      if (!mounted) return;
      if (expectedStep != _currentTutorialStep) return;
      if (_currentTutorialStep >= steps.length) {
        _isTransitioning = false;
        return;
      }
      final currentStep = steps[_currentTutorialStep];

      void advance() {
        final currentStep = steps[_currentTutorialStep];
        _executeTutorialTargetAction(currentStep.target, true);

        if (_currentTutorialStep < steps.length - 1) {
          setState(() => _currentTutorialStep++);
          _showTutorialStep(steps);
        } else {
          _tutorialOverlay?.remove();
          _tutorialOverlay = null;
          setState(() => _tutorialDismissed = true);
        }
      }

      void goBack() {
        if (_currentTutorialStep > 0) {
          final prevStep = steps[_currentTutorialStep - 1];
          _executeTutorialTargetAction(prevStep.target, false);

          setState(() => _currentTutorialStep--);
          _showTutorialStep(steps);
        }
      }

      // Safeguard: ensure any existing overlay is removed before adding new one
      _tutorialOverlay?.remove();
      _tutorialOverlay = null;

      _tutorialOverlay = OverlayEntry(
        builder: (_) => TutorialOverlay(
          step: currentStep,
          stepIndex: _currentTutorialStep,
          totalSteps: steps.length,
          targetKey: _keyForTarget(currentStep.target),
          onNext: advance,
          onPrev: _currentTutorialStep > 0 ? goBack : null,
        ),
      );

      Overlay.of(context).insert(_tutorialOverlay!);
      _isTransitioning = false;
    }

    final delayMs = targetKey != null ? 1000 : 500;
    _tutorialTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      if (expectedStep != _currentTutorialStep) return;

      if (targetKey != null) {
        final targetContext = targetKey.currentContext;
        if (targetContext != null && targetContext.mounted) {
          Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.5,
          ).then((_) {
            if (!mounted) return;
            if (expectedStep != _currentTutorialStep) return;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (expectedStep != _currentTutorialStep) return;
              insertOverlay();
            });
          });
        } else {
          insertOverlay();
        }
      } else {
        insertOverlay();
      }
    });
  }

  void _onTutorialActionTapped(TutorialTarget target) {
    if (_isTransitioning) return; // ignore taps during transition
    final state = ref.read(gameStateProvider);
    final tutorialSteps = state.level.tutorialSteps;
    if (tutorialSteps != null &&
        _currentTutorialStep < tutorialSteps.length &&
        !_tutorialDismissed) {
      final step = tutorialSteps[_currentTutorialStep];
      if (step.target == target) {
        if (_currentTutorialStep < tutorialSteps.length - 1) {
          setState(() => _currentTutorialStep++);
          _showTutorialStep(tutorialSteps);
        } else {
          _tutorialOverlay?.remove();
          _tutorialOverlay = null;
          setState(() => _tutorialDismissed = true);
        }
      }
    }
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
                            Icons.lightbulb,
                            color: CyberTheme.neonYellow,
                            size: 22.0,
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(duration: 800.ms, end: const Offset(1.1, 1.1)),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'SECTOR MISSION BRIEFING',
                            style: CyberTheme.fontHeading(
                              size: 16.0,
                              color: CyberTheme.neonYellow,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  // Objective Section
                  Text(
                    'MISSION OBJECTIVE',
                    style: CyberTheme.fontCode(
                      size: 11.0,
                      color: CyberTheme.neonPink,
                    ).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 6.0),
                  CyberCard(
                    borderColor: CyberTheme.neonPink.withValues(alpha: 0.15),
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
                    'TACTICAL HINTS & TELEMETRY',
                    style: CyberTheme.fontCode(
                      size: 11.0,
                      color: CyberTheme.neonCyan,
                    ).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 6.0),
                  CyberCard(
                    borderColor: CyberTheme.borderTranslucent,
                    backgroundColor: CyberTheme.darkBg,
                    borderWidth: 1.0,
                    chamferSize: 8.0,
                    showAccents: false,
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        level.hint ??
                            "No telemetry recommendations available for this zone. Proceed with manual flight program.",
                        style: CyberTheme.fontBody(
                          size: 13.0,
                          color: CyberTheme.textMain,
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
                        _playClick();
                        Navigator.pop(context);
                        _onTutorialActionTapped(TutorialTarget.dismissHint);
                      },
                      child: CyberCard(
                        key: TutorialKeys.dismissHint,
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
  }

  void _showNestingLimitDialog(BuildContext context) {
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
                            Icons.warning_amber_rounded,
                            color: CyberTheme.neonPink,
                            size: 22.0,
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(duration: 800.ms, end: const Offset(1.1, 1.1)),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'NESTING LIMIT EXCEEDED',
                            style: CyberTheme.fontHeading(
                              size: 16.0,
                              color: CyberTheme.neonPink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    'NESTING OVERFLOW PROTECTION',
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
                        'Loops and conditions can only be nested up to 2 levels deep to prevent display and stack layout overflows.',
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

  void _showContainerLimitDialog(
    BuildContext context, {
    required bool isNested,
  }) {
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
                            Icons.warning_amber_rounded,
                            color: CyberTheme.neonPink,
                            size: 22.0,
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(duration: 800.ms, end: const Offset(1.1, 1.1)),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'STACK LIMIT EXCEEDED',
                            style: CyberTheme.fontHeading(
                              size: 16.0,
                              color: CyberTheme.neonPink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    'CONTAINER STACK OVERFLOW',
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
                        isNested
                            ? 'This nested loop/condition container has reached its capacity limit (5 blocks) to prevent terminal display overflow. Please select a position outside this container or delete existing actions before adding more.'
                            : 'The main command registry has reached its capacity limit (25 blocks). Please optimize your program or delete existing actions before adding more.',
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

  @override
  Widget build(BuildContext context) {
    ref.listen<TutorialTarget?>(tutorialActionTriggerProvider, (
      previous,
      next,
    ) {
      if (next != null) {
        _onTutorialActionTapped(next);
        ref.read(tutorialActionTriggerProvider.notifier).trigger(null);
      }
    });

    ref.listen<bool>(showHintGuidanceProvider, (previous, next) {
      if (next == false) {
        setState(() {
          _nextHintStepIndex = 0;
          _cachedHintSteps = null;
        });
      } else if (next == true) {
        final stateVal = ref.read(gameStateProvider);
        final startState = simulateProgramToState(
          stateVal.level,
          stateVal.program,
        );
        final path = solveLevelBFS(stateVal.level, startState: startState);
        setState(() {
          _nextHintStepIndex = 0;
          _cachedHintSteps = path != null
              ? path.take(3).toList()
              : <ActionType>[];
        });
      }
    });

    ref.listen<String?>(lastAddedBlockIdProvider, (previous, next) {
      if (next != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_workspaceScrollController.hasClients) {
            _workspaceScrollController.animateTo(
              _workspaceScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
            ref.read(lastAddedBlockIdProvider.notifier).setLastAddedId(null);
          }
        });
      }
    });

    final state = ref.watch(gameStateProvider);
    final notifier = ref.read(gameStateProvider.notifier);
    final isRunning = state.status == GameStatus.running;
    final isLandscape = MediaQuery.sizeOf(context).width > 850;
    final isExpanded = ref.watch(consoleExpandedProvider) || isLandscape;

    final level = state.level;
    final tutorialSteps = level.tutorialSteps;
    if (_lastLevelId != level.id) {
      _lastLevelId = level.id;
      _currentTutorialStep = 0;
      _nextHintStepIndex = 0;
      _cachedHintSteps = null;
      _tutorialDismissed = false; // new level → show tutorial again
      _lastShownStepIndex = null;
      _tutorialTimer?.cancel();
      _tutorialTimer = null;
      // Remove any leftover overlay from previous level
      _tutorialOverlay?.remove();
      _tutorialOverlay = null;
    }

    // Tutorial: drive OverlayEntry spotlight (one-time per level / step change)
    if (tutorialSteps != null &&
        tutorialSteps.isNotEmpty &&
        !_tutorialDismissed) {
      if (_currentTutorialStep >= tutorialSteps.length) {
        _currentTutorialStep = tutorialSteps.length - 1;
      }
      if (_currentTutorialStep < 0) _currentTutorialStep = 0;

      // Open overlay only if not already visible, not transitioning, and not already showing/scheduling this step
      if (_tutorialOverlay == null &&
          !_isTransitioning &&
          _lastShownStepIndex != _currentTutorialStep) {
        _lastShownStepIndex = _currentTutorialStep;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showTutorialStep(tutorialSteps),
        );
      }
    } else if (_tutorialDismissed ||
        tutorialSteps == null ||
        tutorialSteps.isEmpty) {
      // Clean up any stale overlay
      if (_tutorialOverlay != null) {
        _tutorialOverlay!.remove();
        _tutorialOverlay = null;
      }
      _tutorialTimer?.cancel();
      _tutorialTimer = null;
      _lastShownStepIndex = null;
    }

    return CyberCard(
      borderColor: CyberTheme.borderTranslucent,
      backgroundColor: CyberTheme.cardBg,
      chamferSize: 16.0,
      showAccents: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 500 ? 6.0 : 12.0,
          vertical: 8.0,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 450;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Header controls
                SizedBox(
                  width: constraints.maxWidth,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: constraints.maxWidth < 380.0
                          ? 380.0
                          : constraints.maxWidth,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // RUN/PAUSE button
                                CyberCard(
                                  key: TutorialKeys.runProgram,
                                  borderColor: isRunning
                                      ? CyberTheme.neonPink.withValues(
                                          alpha: 0.9,
                                        )
                                      : CyberTheme.neonCyan.withValues(
                                          alpha: 0.9,
                                        ),
                                  backgroundColor: isRunning
                                      ? CyberTheme.neonPink
                                      : CyberTheme.neonCyan,
                                  chamferSize: 6.0,
                                  showAccents: false,
                                  child: InkWell(
                                    onTap: () {
                                      _playClick();
                                      if (isRunning) {
                                        notifier.pauseSimulation();
                                      } else {
                                        notifier.runSimulation();
                                      }
                                      _onTutorialActionTapped(
                                        TutorialTarget.runProgram,
                                      );
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isNarrow ? 10.0 : 14.0,
                                        vertical: isNarrow ? 8.0 : 10.0,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isRunning
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                            size: isNarrow ? 14.0 : 16.0,
                                            color: CyberTheme.darkBg,
                                          ),
                                          const SizedBox(width: 4.0),
                                          Text(
                                            isNarrow
                                                ? (isRunning
                                                      ? 'PAUSE'
                                                      : 'RUN PROGRAM')
                                                : (isRunning
                                                      ? 'PAUSE FLIGHT PROGRAM'
                                                      : 'RUN FLIGHT PROGRAM'),
                                            style:
                                                CyberTheme.fontCode(
                                                  size: isNarrow ? 13 : 14.0,
                                                  color: CyberTheme.darkBg,
                                                ).copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: isNarrow ? 6.0 : 8.0),
                                // STEP button
                                CyberCard(
                                  borderColor: isRunning
                                      ? CyberTheme.textMuted.withValues(
                                          alpha: 0.2,
                                        )
                                      : CyberTheme.neonYellow.withValues(
                                          alpha: 0.9,
                                        ),
                                  backgroundColor: isRunning
                                      ? Colors.transparent
                                      : CyberTheme.neonYellow.withValues(
                                          alpha: 0.1,
                                        ),
                                  borderWidth: 1.0,
                                  chamferSize: 6.0,
                                  showAccents: false,
                                  child: InkWell(
                                    onTap: isRunning
                                        ? null
                                        : () {
                                            _playClick();
                                            notifier.stepSimulation();
                                          },
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isNarrow ? 10.0 : 14.0,
                                        vertical: isNarrow ? 8.0 : 10.0,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.skip_next,
                                            size: isNarrow ? 14.0 : 16.0,
                                            color: isRunning
                                                ? CyberTheme.textMuted
                                                : CyberTheme.neonYellow,
                                          ),
                                          const SizedBox(width: 4.0),
                                          Text(
                                            isNarrow ? 'STEP' : 'STEP PROGRAM',
                                            style:
                                                CyberTheme.fontCode(
                                                  size: isNarrow ? 13 : 14.0,
                                                  color: isRunning
                                                      ? CyberTheme.textMuted
                                                      : CyberTheme.neonYellow,
                                                ).copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: isNarrow ? 6.0 : 8.0),
                                // Reset button
                                CyberCard(
                                  key: TutorialKeys.reset,
                                  borderColor: CyberTheme.borderTranslucent,
                                  backgroundColor: const Color(0xFF1E293B),
                                  chamferSize: 5.0,
                                  showAccents: false,
                                  child: InkWell(
                                    onTap: () {
                                      _playClick();
                                      _onTutorialActionTapped(
                                        TutorialTarget.reset,
                                      );
                                      _showConfirmDialog(
                                        context,
                                        title: 'RETRY SIMULATION',
                                        message:
                                            'Are you sure you want to restart the flight simulation?',
                                        onConfirm: () {
                                          notifier.clearProgram();
                                          notifier.resetSimulation();
                                        },
                                      );
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isNarrow ? 12.0 : 14.0,
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.refresh,
                                        size: isNarrow ? 18.0 : 20.0,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Speed segmented pill selector
                          CyberCard(
                            key: TutorialKeys.speed,
                            borderColor: CyberTheme.borderTranslucent,
                            backgroundColor: CyberTheme.darkBg,
                            chamferSize: 4.0,
                            showAccents: false,
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildSpeedSegment(1.0, '1X'),
                                  _buildSpeedSegment(2.0, '2X'),
                                  _buildSpeedSegment(4.0, '4X'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (isExpanded && constraints.maxHeight > 170.0) ...[
                  const SizedBox(height: 6.0),
                  Container(height: 1.0, color: CyberTheme.borderTranslucent),
                  const SizedBox(height: 6.0),

                  // 2. Body of the panel: Palette vs Workspace stacked column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Toolbox palette row (top)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // LOOPS & CONDS Group
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 4.0,
                                        bottom: 4.0,
                                      ),
                                      child: Text(
                                        'LOOPS & CONDS',
                                        style: CyberTheme.fontCode(
                                          size: 11,
                                          color: CyberTheme.textMuted,
                                        ).copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildPaletteItem(
                                          ProgramBlock(
                                            id: '',
                                            type: BlockType.repeat,
                                          ),
                                          const Color(0xFF8B5CF6),
                                          'REPEAT [x]',
                                          Icons.loop,
                                          isHorizontal: true,
                                          itemKey: TutorialKeys.repeatBlock,
                                          tutorialTarget:
                                              TutorialTarget.repeatBlock,
                                        ),
                                        _buildPaletteItem(
                                          ProgramBlock(
                                            id: '',
                                            type: BlockType.whileLoop,
                                          ),
                                          const Color(0xFF6D28D9),
                                          'WHILE [x]',
                                          Icons.autorenew,
                                          isHorizontal: true,
                                          itemKey: TutorialKeys.whileBlock,
                                          tutorialTarget:
                                              TutorialTarget.whileBlock,
                                        ),
                                        _buildPaletteItem(
                                          ProgramBlock(
                                            id: '',
                                            type: BlockType.ifElse,
                                          ),
                                          const Color(0xFFF59E0B),
                                          'IF / ELSE',
                                          Icons.alt_route,
                                          isHorizontal: true,
                                          itemKey: TutorialKeys.ifElse,
                                          tutorialTarget: TutorialTarget.ifElse,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                // Divider
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: 12.0,
                                    top: 22.0,
                                  ),
                                  child: Container(
                                    width: 1.0,
                                    height: 44.0,
                                    color: CyberTheme.borderTranslucent,
                                  ),
                                ),
                                // ACTIONS Group
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 4.0,
                                        bottom: 4.0,
                                      ),
                                      child: Text(
                                        'ACTIONS',
                                        style: CyberTheme.fontCode(
                                          size: 11,
                                          color: CyberTheme.textMuted,
                                        ).copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildPaletteItem(
                                          ProgramBlock(
                                            id: '',
                                            type: BlockType.action,
                                            action: ActionType.takeoff,
                                          ),
                                          const Color(0xFF0EA5E9),
                                          'TAKEOFF',
                                          Icons.flight_takeoff,
                                          isHorizontal: true,
                                          itemKey: TutorialKeys.takeoff,
                                          tutorialTarget:
                                              TutorialTarget.takeoff,
                                        ),
                                        _buildPaletteItem(
                                          ProgramBlock(
                                            id: '',
                                            type: BlockType.action,
                                            action: ActionType.land,
                                          ),
                                          const Color(0xFF0EA5E9),
                                          'LAND',
                                          Icons.flight_land,
                                          isHorizontal: true,
                                          itemKey: TutorialKeys.land,
                                          tutorialTarget: TutorialTarget.land,
                                        ),
                                        _buildPaletteItem(
                                          ProgramBlock(
                                            id: '',
                                            type: BlockType.action,
                                            action: ActionType.forward,
                                          ),
                                          const Color(0xFF0EA5E9),
                                          'MOVE FWD',
                                          Icons.arrow_upward,
                                          isHorizontal: true,
                                          itemKey: TutorialKeys.moveForward,
                                          tutorialTarget:
                                              TutorialTarget.moveForward,
                                        ),
                                        _buildPaletteItem(
                                          ProgramBlock(
                                            id: '',
                                            type: BlockType.action,
                                            action: ActionType.rotateLeft,
                                          ),
                                          const Color(0xFF0EA5E9),
                                          'TURN LEFT',
                                          Icons.rotate_left,
                                          isHorizontal: true,
                                          itemKey: TutorialKeys.turnLeft,
                                          tutorialTarget:
                                              TutorialTarget.turnLeft,
                                        ),
                                        _buildPaletteItem(
                                          ProgramBlock(
                                            id: '',
                                            type: BlockType.action,
                                            action: ActionType.rotateRight,
                                          ),
                                          const Color(0xFF0EA5E9),
                                          'TURN RIGHT',
                                          Icons.rotate_right,
                                          isHorizontal: true,
                                          itemKey: TutorialKeys.turnRight,
                                          tutorialTarget:
                                              TutorialTarget.turnRight,
                                        ),
                                        _buildPaletteItem(
                                          ProgramBlock(
                                            id: '',
                                            type: BlockType.action,
                                            action: ActionType.ascend,
                                          ),
                                          const Color(0xFF0EA5E9),
                                          'ASCEND',
                                          Icons.keyboard_double_arrow_up,
                                          isHorizontal: true,
                                          itemKey: TutorialKeys.ascend,
                                          tutorialTarget: TutorialTarget.ascend,
                                        ),
                                        _buildPaletteItem(
                                          ProgramBlock(
                                            id: '',
                                            type: BlockType.action,
                                            action: ActionType.descend,
                                          ),
                                          const Color(0xFF0EA5E9),
                                          'DESCEND',
                                          Icons.keyboard_double_arrow_down,
                                          isHorizontal: true,
                                          itemKey: TutorialKeys.descend,
                                          tutorialTarget:
                                              TutorialTarget.descend,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Horizontal Divider
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Container(
                            height: 1.0,
                            color: CyberTheme.borderTranslucent,
                          ),
                        ),
                        // Canvas Workspace Column (bottom)
                        Expanded(
                          key: TutorialKeys.workspace,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHintGuidancePanel(state, notifier),
                              if (constraints.maxHeight > 240.0) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      isNarrow
                                          ? 'SEQUENCE'
                                          : 'ACTIVE FLIGHT SEQUENCE',
                                      style: CyberTheme.fontCode(
                                        size: isNarrow ? 14 : 16,
                                        color: CyberTheme.textMuted,
                                      ),
                                    ),
                                    Text(
                                      '${state.totalBlockCount} BLOCKS',
                                      style: CyberTheme.fontCode(
                                        size: isNarrow ? 14 : 16,
                                        color: CyberTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8.0),
                              ],
                              Expanded(child: _buildWorkspace(state, notifier)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSpeedSegment(double speed, String label) {
    final notifier = ref.read(gameStateProvider.notifier);
    final activeSpeed = notifier.speedMultiplier;
    final isActive = activeSpeed == speed;

    return GestureDetector(
      onTap: () {
        notifier.setSpeed(speed);
        _onTutorialActionTapped(TutorialTarget.speed);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isActive ? CyberTheme.neonCyan : Colors.transparent,
        ),
        child: Text(
          label,
          style: CyberTheme.fontCode(
            size: 12,
            color: isActive ? CyberTheme.darkBg : CyberTheme.textMuted,
          ).copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildPaletteItem(
    ProgramBlock templateBlock,
    Color blockColor,
    String label,
    IconData icon, {
    bool isHorizontal = false,
    Key? itemKey,
    TutorialTarget? tutorialTarget,
  }) {
    final isRunning = ref.watch(gameStateProvider).status == GameStatus.running;
    final activeContainer = ref.watch(activeContainerProvider);
    final notifier = ref.watch(gameStateProvider.notifier);

    final isLandscape = MediaQuery.sizeOf(context).width > 850;
    final isNarrow = MediaQuery.sizeOf(context).width < 500;
    final isExpanded = ref.watch(consoleExpandedProvider) || isLandscape;
    final useBiggerFont = isExpanded;

    final double paletteFontSize = useBiggerFont
        ? 12.5
        : (isNarrow ? 11.0 : 12.5);

    final double paletteIconSize = useBiggerFont
        ? 14.0
        : (isNarrow ? 11.0 : 13.0);

    final isLoopOrCond =
        templateBlock.type == BlockType.repeat ||
        templateBlock.type == BlockType.whileLoop ||
        templateBlock.type == BlockType.ifElse;

    final containerDepth = activeContainer.parentId == null
        ? 0
        : notifier.getBlockNestingDepth(activeContainer.parentId) + 1;

    final isPaletteItemDisabled = isLoopOrCond && containerDepth >= 2;

    return Container(
      key: itemKey,
      margin: isHorizontal
          ? const EdgeInsets.only(right: 8.0, bottom: 4.0, top: 4.0)
          : const EdgeInsets.only(bottom: 6.0),
      child: InkWell(
        onTap: isRunning
            ? null
            : () {
                _playClick();
                final isNested = activeContainer.parentId != null;
                final activeBlocksCount = notifier.getBlocksInContainerCount(
                  activeContainer.parentId,
                  activeContainer.isElse,
                );

                final limit = isNested ? 5 : 25;
                if (activeBlocksCount >= limit) {
                  _showContainerLimitDialog(context, isNested: isNested);
                  return;
                }

                if (isPaletteItemDisabled) {
                  _showNestingLimitDialog(context);
                  return;
                }

                String? finalParentId = activeContainer.parentId;
                bool finalIsElse = activeContainer.isElse;

                if (finalParentId != null) {
                  final exists = notifier.blockExists(finalParentId);
                  if (!exists) {
                    finalParentId = null;
                    finalIsElse = false;
                    ref.read(activeContainerProvider.notifier).reset();
                  }
                }

                final newBlockId =
                    'block_${DateTime.now().microsecondsSinceEpoch}';
                ref
                    .read(lastAddedBlockIdProvider.notifier)
                    .setLastAddedId(newBlockId);

                notifier.addBlock(
                  templateBlock.copyWith(id: newBlockId),
                  parentId: finalParentId,
                  isElse: finalIsElse,
                );

                if (templateBlock.type == BlockType.repeat ||
                    templateBlock.type == BlockType.whileLoop ||
                    templateBlock.type == BlockType.ifElse) {
                  ref.read(activeContainerProvider.notifier).select(newBlockId);
                }

                if (tutorialTarget != null) {
                  _onTutorialActionTapped(tutorialTarget);
                }
              },
        child: CyberCard(
          borderColor: isRunning
              ? CyberTheme.borderTranslucent
              : (isPaletteItemDisabled
                    ? blockColor.withValues(alpha: 0.15)
                    : blockColor.withValues(alpha: 0.45)),
          backgroundColor: CyberTheme.darkBg,
          chamferSize: 6.0,
          showAccents: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isHorizontal ? 8.0 : (isNarrow ? 6.0 : 12.0),
              vertical: isHorizontal ? 6.0 : 8.0,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: isHorizontal
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: paletteIconSize + 4.0,
                          color: isRunning
                              ? CyberTheme.textMuted
                              : (isPaletteItemDisabled
                                    ? CyberTheme.textMuted
                                    : blockColor),
                        ),
                        const SizedBox(height: 3.0),
                        Text(
                          label,
                          style: CyberTheme.fontCode(
                            size: paletteFontSize - 1.0,
                            color: isRunning
                                ? CyberTheme.textMuted
                                : (isPaletteItemDisabled
                                      ? CyberTheme.textMuted
                                      : CyberTheme.textMain),
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: isNarrow ? 90.0 : 130.0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              style: CyberTheme.fontCode(
                                size: paletteFontSize,
                                color: isRunning
                                    ? CyberTheme.textMuted
                                    : (isPaletteItemDisabled
                                          ? CyberTheme.textMuted
                                          : CyberTheme.textMain),
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Icon(
                            Icons.add_circle_outline,
                            size: paletteIconSize + 1.0,
                            color: isRunning
                                ? CyberTheme.textMuted
                                : (isPaletteItemDisabled
                                      ? CyberTheme.textMuted
                                      : blockColor),
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

  Widget _buildWorkspace(DroneGameState state, GameStateNotifier notifier) {
    final program = state.program;
    final isRunning = state.status == GameStatus.running;
    final activeContainer = ref.watch(activeContainerProvider);
    final isRootActive = activeContainer.parentId == null;

    final List<Widget> listItems = [];
    for (int i = 0; i < program.length; i++) {
      final blockItem = program[i];
      // if (i > 0) {
      //   listItems.add(const SizedBox(height: 0.0));
      // }
      listItems.add(
        VisualBlock(
          block: blockItem,
          parentId: null,
          isElse: false,
          index: i,
          parentListLength: program.length,
          isRunning: isRunning,
          activeBlockId: state.activeBlockId,
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isRunning
          ? null
          : () {
              ref.read(activeContainerProvider.notifier).reset();
              _onTutorialActionTapped(TutorialTarget.workspace);
            },
      child: CyberCard(
        borderColor: isRootActive
            ? CyberTheme.neonCyan.withValues(alpha: 0.7)
            : CyberTheme.borderTranslucent,
        backgroundColor: CyberTheme.darkBg,
        chamferSize: 12.0,
        showAccents: true,
        shadows: isRootActive
            ? [
                BoxShadow(
                  color: CyberTheme.neonCyan.withValues(alpha: 0.1),
                  blurRadius: 4.0,
                ),
              ]
            : null,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: program.isEmpty
              ? _buildEmptyQueuePlaceholder()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        controller: _workspaceScrollController,
                        physics: const BouncingScrollPhysics(),
                        children: listItems,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyQueuePlaceholder() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.terminal_outlined,
              color: CyberTheme.textMuted.withValues(alpha: 0.3),
              size: 42.0,
            ),
            const SizedBox(height: 6.0),
            Text(
              'WORKSPACE IS EMPTY',
              style: CyberTheme.fontCode(
                size: 18.0,
                color: CyberTheme.textMuted,
              ),
            ),
            const SizedBox(height: 4.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Tap blocks from the palette to write your program.',
                style: CyberTheme.fontBody(
                  size: 13,
                  color: CyberTheme.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
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
                            _playClick();
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
                            _playClick();
                            Navigator.pop(dialogContext);
                            onConfirm();
                            _onTutorialActionTapped(
                              TutorialTarget.confirmReset,
                            );
                          },
                          child: CyberCard(
                            key: TutorialKeys.confirmReset,
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

  Widget _buildHintGuidancePanel(
    DroneGameState state,
    GameStateNotifier notifier,
  ) {
    final showGuidance = ref.watch(showHintGuidanceProvider);

    Widget child;
    if (!showGuidance) {
      child = const SizedBox.shrink(key: ValueKey('hint_hidden'));
    } else {
      final steps =
          _cachedHintSteps ??
          (() {
            final startState = simulateProgramToState(
              state.level,
              state.program,
            );
            final path = solveLevelBFS(state.level, startState: startState);
            return path != null ? path.take(3).toList() : <ActionType>[];
          })();

      if (steps.isEmpty) {
        child = Padding(
          key: const ValueKey('hint_empty'),
          padding: const EdgeInsets.only(bottom: 12.0),
          child: CyberCard(
            borderColor: CyberTheme.neonYellow.withValues(alpha: 0.5),
            backgroundColor: Colors.black26,
            chamferSize: 8.0,
            showAccents: false,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: CyberTheme.neonYellow,
                    size: 20,
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      'No optimal path calculated. Formulate your own flight plan!',
                      style: CyberTheme.fontCode(
                        size: 12.0,
                        color: CyberTheme.textMuted,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: CyberTheme.textMuted,
                      size: 16,
                    ),
                    onPressed: () {
                      ref.read(showHintGuidanceProvider.notifier).set(false);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        child = Padding(
          key: const ValueKey('hint_steps'),
          padding: const EdgeInsets.only(bottom: 12.0),
          child: CyberCard(
            borderColor: CyberTheme.neonYellow,
            backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.4),
            borderWidth: 1.2,
            chamferSize: 8.0,
            showAccents: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 10.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.lightbulb,
                            color: CyberTheme.neonYellow,
                            size: 18,
                          ),
                          const SizedBox(width: 6.0),
                          Text(
                            'TACTICAL SOLUTION LINKED',
                            style: CyberTheme.fontHeading(
                              size: 13.0,
                              color: CyberTheme.neonYellow,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          _playClick();
                          ref
                              .read(showHintGuidanceProvider.notifier)
                              .set(false);
                        },
                        child: const Icon(
                          Icons.close,
                          color: CyberTheme.neonYellow,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Follow flight sequence instructions step by step:',
                    style: CyberTheme.fontCode(
                      size: 11.0,
                      color: CyberTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  SingleChildScrollView(
                    controller: _hintStepsScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: List.generate(steps.length, (index) {
                        final action = steps[index];
                        final isFirst = index == 0;

                        final isCompleted = index < _nextHintStepIndex;
                        final isActive = index == _nextHintStepIndex;

                        Color cardBorderColor;
                        Color cardBgColor;
                        Color textColor;
                        IconData stepIcon;
                        Color iconColor;

                        if (isCompleted) {
                          cardBorderColor = CyberTheme.neonGreen.withValues(
                            alpha: 0.3,
                          );
                          cardBgColor = CyberTheme.neonGreen.withValues(
                            alpha: 0.05,
                          );
                          textColor = CyberTheme.neonGreen.withValues(
                            alpha: 0.6,
                          );
                          stepIcon = Icons.check_circle_outline;
                          iconColor = CyberTheme.neonGreen.withValues(
                            alpha: 0.6,
                          );
                        } else if (isActive) {
                          cardBorderColor = CyberTheme.neonYellow;
                          cardBgColor = CyberTheme.neonYellow.withValues(
                            alpha: 0.1,
                          );
                          textColor = CyberTheme.neonYellow;
                          stepIcon = action.icon;
                          iconColor = CyberTheme.neonYellow;
                        } else {
                          cardBorderColor = CyberTheme.textMuted.withValues(
                            alpha: 0.3,
                          );
                          cardBgColor = Colors.transparent;
                          textColor = CyberTheme.textMuted;
                          stepIcon = Icons.lock_outline;
                          iconColor = CyberTheme.textMuted;
                        }

                        Widget cardContent = Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 6.0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(stepIcon, size: 12.0, color: iconColor),
                              const SizedBox(width: 4.0),
                              Text(
                                '${index + 1}. ${action.label}',
                                style: CyberTheme.fontCode(
                                  size: 11.0,
                                  color: textColor,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );

                        if (isActive) {
                          cardContent = cardContent
                              .animate(
                                onPlay: (controller) =>
                                    controller.repeat(reverse: true),
                              )
                              .custom(
                                duration: 1000.ms,
                                builder: (context, value, child) {
                                  return Opacity(
                                    opacity: 0.7 + (value * 0.3),
                                    child: child,
                                  );
                                },
                              );
                        }

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isFirst)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0,
                                ),
                                child: Icon(
                                  Icons.arrow_forward,
                                  size: 14.0,
                                  color: isCompleted
                                      ? CyberTheme.neonGreen.withValues(
                                          alpha: 0.4,
                                        )
                                      : CyberTheme.textMuted.withValues(
                                          alpha: 0.3,
                                        ),
                                ),
                              ),
                            GestureDetector(
                              onTap: isActive
                                  ? () {
                                      _playClick();
                                      final newBlockId =
                                          'block_hint_${DateTime.now().microsecondsSinceEpoch}_$index';

                                      final activeContainer = ref.read(
                                        activeContainerProvider,
                                      );
                                      String? finalParentId =
                                          activeContainer.parentId;
                                      bool finalIsElse = activeContainer.isElse;

                                      if (finalParentId != null) {
                                        final exists = notifier.blockExists(
                                          finalParentId,
                                        );
                                        if (!exists) {
                                          finalParentId = null;
                                          finalIsElse = false;
                                          ref
                                              .read(
                                                activeContainerProvider
                                                    .notifier,
                                              )
                                              .reset();
                                        }
                                      }

                                      ref
                                          .read(
                                            lastAddedBlockIdProvider.notifier,
                                          )
                                          .setLastAddedId(newBlockId);

                                      notifier.addBlock(
                                        ProgramBlock(
                                          id: newBlockId,
                                          type: BlockType.action,
                                          action: action,
                                        ),
                                        parentId: finalParentId,
                                        isElse: finalIsElse,
                                      );

                                      setState(() {
                                        _nextHintStepIndex++;
                                      });

                                      if (_nextHintStepIndex == 2) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              if (_hintStepsScrollController
                                                  .hasClients) {
                                                _hintStepsScrollController
                                                    .animateTo(
                                                      _hintStepsScrollController
                                                          .position
                                                          .maxScrollExtent,
                                                      duration: const Duration(
                                                        milliseconds: 300,
                                                      ),
                                                      curve: Curves.easeInOut,
                                                    );
                                              }
                                            });
                                      }

                                      if (_nextHintStepIndex >= steps.length) {
                                        Future.delayed(
                                          const Duration(milliseconds: 600),
                                          () {
                                            if (mounted) {
                                              ref
                                                  .read(
                                                    showHintGuidanceProvider
                                                        .notifier,
                                                  )
                                                  .set(false);
                                              setState(() {
                                                _nextHintStepIndex = 0;
                                              });
                                            }
                                          },
                                        );
                                      }
                                    }
                                  : null,
                              child: CyberCard(
                                borderColor: cardBorderColor,
                                backgroundColor: cardBgColor,
                                borderWidth: 1.0,
                                chamferSize: 5.0,
                                showAccents: false,
                                child: cardContent,
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1.0,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: child,
      ),
    );
  }
}

class VisualBlock extends ConsumerWidget {
  final ProgramBlock block;
  final String? parentId;
  final bool isElse;
  final int index;
  final int parentListLength;
  final bool isRunning;
  final String? activeBlockId;

  const VisualBlock({
    super.key,
    required this.block,
    this.parentId,
    this.isElse = false,
    required this.index,
    required this.parentListLength,
    required this.isRunning,
    this.activeBlockId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameStateProvider);
    final notifier = ref.read(gameStateProvider.notifier);
    final isActive = activeBlockId == block.id;

    final activeInst = state.pc >= 0 && state.pc < state.vmInstructions.length
        ? state.vmInstructions[state.pc]
        : null;
    final isLoopActive =
        isActive || (activeInst != null && activeInst.loopBlockId == block.id);

    final program = state.program;
    final allRepeats = findAllRepeatBlocks(program);
    final isFirstRepeat = allRepeats.isNotEmpty && allRepeats[0].id == block.id;
    final isSecondRepeat =
        allRepeats.length > 1 && allRepeats[1].id == block.id;

    return _buildCardContent(
      context,
      ref,
      notifier,
      isActive,
      isLoopActive,
      activeInst,
      isFirstRepeat,
      isSecondRepeat,
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    WidgetRef ref,
    GameStateNotifier notifier,
    bool isActive,
    bool isLoopActive,
    VMInstruction? activeInst,
    bool isFirstRepeat,
    bool isSecondRepeat, {
    bool isFeedback = false,
  }) {
    final isNarrow = MediaQuery.sizeOf(context).width < 500;
    final isExpanded =
        ref.watch(consoleExpandedProvider) ||
        (MediaQuery.sizeOf(context).width > 850);
    final useBiggerFont = isExpanded;

    final depth = parentId == null
        ? 0
        : notifier.getBlockNestingDepth(parentId) + 1;
    final isNested = depth > 0;

    final double titleFontSize = useBiggerFont
        ? 12.5
        : (isNarrow ? (isNested ? 8.0 : 9.5) : (isNested ? 10.5 : 11.5));
    final double labelFontSize = useBiggerFont
        ? 11.5
        : (isNarrow ? (isNested ? 8.0 : 9.5) : (isNested ? 9.5 : 10.5));
    final double timesFontSize = useBiggerFont
        ? 11.0
        : (isNarrow ? (isNested ? 9.0 : 10.0) : (isNested ? 9.5 : 10.5));
    final double dropdownHeight = useBiggerFont
        ? 26.0
        : (isNarrow ? (isNested ? 19.0 : 21.0) : 23.0);
    final double iconSize = useBiggerFont
        ? 15.0
        : (isNarrow ? (isNested ? 9.0 : 10.0) : (isNested ? 11.5 : 13.5));
    final double dropdownIconSize = useBiggerFont
        ? 15.0
        : (isNarrow ? (isNested ? 8.5 : 9.5) : (isNested ? 9.5 : 11.5));
    final double dragIconSize = useBiggerFont ? 15.0 : (isNested ? 11.0 : 13.0);
    final double deleteIconSize = useBiggerFont
        ? 18.0
        : (isNarrow ? (isNested ? 9.5 : 11.0) : (isNested ? 14.5 : 17.0));
    final double arrowIconSize = useBiggerFont
        ? 21.0
        : (isNarrow ? (isNested ? 10.0 : 12.0) : (isNested ? 16.0 : 20.0));

    final EdgeInsets headerPadding = EdgeInsets.symmetric(
      horizontal: useBiggerFont
          ? 10.0
          : (isNarrow ? (isNested ? 1.0 : 1.5) : 10.0),
      vertical: useBiggerFont
          ? 10.0
          : (isNarrow ? (isNested ? 4.0 : 6.0) : 8.0),
    );

    final EdgeInsets bodyPadding = EdgeInsets.only(
      left: useBiggerFont
          ? 14.0
          : (isNarrow ? (isNested ? 3.0 : 4.0) : (isNested ? 8.0 : 12.0)),
      right: useBiggerFont
          ? 10.0
          : (isNarrow ? (isNested ? 1.5 : 2.5) : (isNested ? 4.0 : 8.0)),
    );

    final EdgeInsets innerBodyPadding = EdgeInsets.only(
      left: useBiggerFont
          ? 10.0
          : (isNarrow ? (isNested ? 1.5 : 2.5) : (isNested ? 4.0 : 8.0)),
      top: useBiggerFont ? 4.0 : 2.0,
      bottom: useBiggerFont ? 4.0 : 2.0,
    );

    Color blockColor;
    IconData icon;
    String title;
    Widget? customInput;
    Widget? nestedBody;

    switch (block.type) {
      case BlockType.action:
        blockColor = const Color(0xFF0EA5E9); // Cyan-blue
        icon = block.action?.icon ?? Icons.code;
        final rawTitle = block.action?.label ?? 'ACTION';
        final useShortTitle = isNarrow || isNested;
        if (block.action == ActionType.forward) {
          title = useShortTitle ? 'FWD' : 'MOVE_FWD';
        } else if (block.action == ActionType.rotateLeft) {
          title = useShortTitle ? 'LEFT' : 'TURN_LEFT';
        } else if (block.action == ActionType.rotateRight) {
          title = useShortTitle ? 'RIGHT' : 'TURN_RIGHT';
        } else {
          title = rawTitle;
        }
        break;

      case BlockType.repeat:
        blockColor = const Color(0xFF8B5CF6); // Loop purple
        icon = Icons.loop;
        title = (isNarrow || isNested) ? (isNarrow ? 'REP' : 'REPT') : 'REPEAT';
        customInput = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final state = ref.read(gameStateProvider);
                  final isT3 = state.level.id == 'T3';
                  if (isT3) {
                    notifier.updateBlockRepeat(block.id, 3);
                    if (isFirstRepeat) {
                      ref
                          .read(tutorialActionTriggerProvider.notifier)
                          .trigger(TutorialTarget.firstRepeatDropdown);
                    } else if (isSecondRepeat) {
                      ref
                          .read(tutorialActionTriggerProvider.notifier)
                          .trigger(TutorialTarget.secondRepeatDropdown);
                    }
                  }
                },
                child: IgnorePointer(
                  ignoring: ref.watch(gameStateProvider).level.id == 'T3',
                  child: Container(
                    key: isFirstRepeat
                        ? TutorialKeys.firstRepeatDropdown
                        : (isSecondRepeat
                              ? TutorialKeys.secondRepeatDropdown
                              : null),
                    width: useBiggerFont
                        ? 46.0
                        : (isNarrow ? (isNested ? 18.0 : 22.0) : 40.0),
                    padding: EdgeInsets.symmetric(
                      horizontal: isNarrow ? 1.0 : 4.0,
                    ),
                    constraints: BoxConstraints(minHeight: dropdownHeight),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: CyberTheme.darkBg),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isDense: true,
                        isExpanded: true,
                        iconSize: useBiggerFont
                            ? 16.0
                            : (isNarrow ? 10.0 : 16.0),
                        padding: EdgeInsets.zero,
                        value: block.repeatCount,
                        dropdownColor: CyberTheme.cardBg,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          size: dropdownIconSize,
                          color: Colors.white70,
                        ),
                        style: CyberTheme.fontCode(
                          size: labelFontSize,
                          color: Colors.white,
                        ).copyWith(fontWeight: FontWeight.bold),
                        onChanged: isRunning
                            ? null
                            : (val) {
                                if (val != null) {
                                  notifier.updateBlockRepeat(block.id, val);
                                  if (isFirstRepeat && val == 3) {
                                    ref
                                        .read(
                                          tutorialActionTriggerProvider
                                              .notifier,
                                        )
                                        .trigger(
                                          TutorialTarget.firstRepeatDropdown,
                                        );
                                  } else if (isSecondRepeat && val == 3) {
                                    ref
                                        .read(
                                          tutorialActionTriggerProvider
                                              .notifier,
                                        )
                                        .trigger(
                                          TutorialTarget.secondRepeatDropdown,
                                        );
                                  }
                                }
                              },
                        selectedItemBuilder: (BuildContext context) {
                          return List.generate(9, (i) => i + 2).map<Widget>((
                            i,
                          ) {
                            return Align(
                              alignment: Alignment.center,
                              child: Text(
                                '$i',
                                style: CyberTheme.fontCode(
                                  size: labelFontSize,
                                  color: Colors.white,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList();
                        },
                        items: List.generate(9, (i) => i + 2).map((i) {
                          return DropdownMenuItem<int>(
                            value: i,
                            child: Text(
                              '$i ',
                              style: CyberTheme.fontCode(
                                size: labelFontSize,
                                color: Colors.white,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: isNarrow ? 2.0 : 4.0),
            Text(
              isNarrow ? 'x' : 'TIMES',
              style: CyberTheme.fontCode(
                size: timesFontSize,
                color: Colors.white70,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        );
        nestedBody = _buildNestedList(
          context,
          ref,
          block.body,
          false,
          notifier,
        );
        break;

      case BlockType.whileLoop:
        blockColor = const Color(0xFF6D28D9); // While dark purple
        icon = Icons.autorenew;
        title = (isNarrow || isNested) ? (isNarrow ? 'WHL' : 'WHIL') : 'WHILE';
        customInput = Container(
          width: useBiggerFont
              ? 100.0
              : (isNarrow ? (isNested ? 32.0 : 38.0) : 82.0),
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 1.0 : 4.0),
          constraints: BoxConstraints(minHeight: dropdownHeight),
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: CyberTheme.darkBg),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ConditionType>(
              isDense: true,
              isExpanded: true,
              iconSize: useBiggerFont ? 16.0 : (isNarrow ? 10.0 : 16.0),
              padding: EdgeInsets.zero,
              value: block.condition,
              dropdownColor: CyberTheme.cardBg,
              icon: Icon(
                Icons.arrow_drop_down,
                size: dropdownIconSize,
                color: Colors.white70,
              ),
              style: CyberTheme.fontCode(
                size: labelFontSize,
                color: Colors.white,
              ).copyWith(fontWeight: FontWeight.bold),
              onChanged: isRunning
                  ? null
                  : (val) {
                      if (val != null) {
                        notifier.updateBlockCondition(block.id, val);
                      }
                    },
              selectedItemBuilder: (BuildContext context) {
                return ConditionType.values.map<Widget>((cond) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        cond.shortLabel,
                        style: CyberTheme.fontCode(
                          size: labelFontSize,
                          color: Colors.white,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }).toList();
              },
              items: ConditionType.values.map((cond) {
                return DropdownMenuItem<ConditionType>(
                  value: cond,
                  child: Text(
                    '${cond.label} ',
                    style: CyberTheme.fontCode(
                      size: labelFontSize,
                      color: Colors.white,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
          ),
        );
        nestedBody = _buildNestedList(
          context,
          ref,
          block.body,
          false,
          notifier,
        );
        break;

      case BlockType.ifElse:
        blockColor = const Color(0xFFF59E0B); // If orange
        icon = Icons.alt_route;
        title = 'IF';
        customInput = Container(
          width: useBiggerFont
              ? 100.0
              : (isNarrow ? (isNested ? 32.0 : 38.0) : 82.0),
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 1.0 : 4.0),
          constraints: BoxConstraints(minHeight: dropdownHeight),
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: CyberTheme.darkBg),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ConditionType>(
              isDense: true,
              isExpanded: true,
              iconSize: useBiggerFont ? 16.0 : (isNarrow ? 10.0 : 16.0),
              padding: EdgeInsets.zero,
              value: block.condition,
              dropdownColor: CyberTheme.cardBg,
              icon: Icon(
                Icons.arrow_drop_down,
                size: dropdownIconSize,
                color: Colors.white70,
              ),
              style: CyberTheme.fontCode(
                size: labelFontSize,
                color: Colors.white,
              ).copyWith(fontWeight: FontWeight.bold),
              onChanged: isRunning
                  ? null
                  : (val) {
                      if (val != null) {
                        notifier.updateBlockCondition(block.id, val);
                      }
                    },
              selectedItemBuilder: (BuildContext context) {
                return ConditionType.values.map<Widget>((cond) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        cond.shortLabel,
                        style: CyberTheme.fontCode(
                          size: labelFontSize,
                          color: Colors.white,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }).toList();
              },
              items: ConditionType.values.map((cond) {
                return DropdownMenuItem<ConditionType>(
                  value: cond,
                  child: Text(
                    '${cond.label} ',
                    style: CyberTheme.fontCode(
                      size: labelFontSize,
                      color: Colors.white,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
          ),
        );
        nestedBody = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildNestedList(context, ref, block.body, false, notifier),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isRunning
                  ? null
                  : () {
                      ref
                          .read(activeContainerProvider.notifier)
                          .select(block.id, isElse: true);
                    },
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.subdirectory_arrow_right,
                      size: 14,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      'ELSE',
                      style: CyberTheme.fontCode(
                        size: useBiggerFont ? 12.0 : 10.0,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildNestedList(context, ref, block.elseBody, true, notifier),
          ],
        );
        break;
    }

    final card = Container(
      key: isFirstRepeat
          ? TutorialKeys.firstRepeatBlock
          : (isSecondRepeat ? TutorialKeys.secondRepeatBlock : null),
      width: isFeedback ? 220.0 : double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 2.0),
      child: CyberCard(
        borderColor: isActive
            ? CyberTheme.neonYellow
            : (isLoopActive
                  ? CyberTheme.neonCyan
                  : (isRunning
                        ? blockColor.withValues(alpha: 0.45)
                        : blockColor.withValues(alpha: 0.8))),
        backgroundColor: CyberTheme.cardBg,
        borderWidth: (isActive || isLoopActive) ? 1.8 : 1.0,
        chamferSize: 8.0,
        showAccents: false,
        shadows: isActive
            ? CyberTheme.neonGlow(CyberTheme.neonYellow, radius: 8.0)
            : (isLoopActive
                  ? CyberTheme.neonGlow(
                      CyberTheme.neonCyan.withValues(alpha: 0.4),
                      radius: 6.0,
                    )
                  : null),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Block Header Row
            Padding(
              padding: headerPadding,
              child: Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isRunning &&
                              !isFeedback &&
                              !isNarrow &&
                              !isNested)
                            Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: Icon(
                                Icons.drag_indicator,
                                size: dragIconSize,
                                color: Colors.white38,
                              ),
                            ),
                          Icon(icon, size: iconSize, color: blockColor),
                          SizedBox(width: isNarrow ? 1.0 : 6.0),
                          Text(
                            title,
                            style: CyberTheme.fontCode(
                              size: titleFontSize,
                              color: Colors.white,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (block.type == BlockType.repeat &&
                              isLoopActive &&
                              activeInst != null &&
                              activeInst.loopIteration != null) ...[
                            SizedBox(width: isNarrow ? 3.0 : 6.0),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                                vertical: 1.0,
                              ),
                              decoration: BoxDecoration(
                                color: CyberTheme.neonCyan.withValues(
                                  alpha: 0.15,
                                ),
                                border: Border.all(
                                  color: CyberTheme.neonCyan.withValues(
                                    alpha: 0.5,
                                  ),
                                  width: 0.8,
                                ),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Text(
                                'ITER: ${activeInst.loopIteration}/${activeInst.loopTotal}',
                                style: CyberTheme.fontCode(
                                  size: useBiggerFont ? 9.5 : 8.0,
                                  color: CyberTheme.neonCyan,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          if (block.type == BlockType.whileLoop &&
                              isLoopActive) ...[
                            SizedBox(width: isNarrow ? 3.0 : 6.0),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                                vertical: 1.0,
                              ),
                              decoration: BoxDecoration(
                                color: CyberTheme.neonCyan.withValues(
                                  alpha: 0.15,
                                ),
                                border: Border.all(
                                  color: CyberTheme.neonCyan.withValues(
                                    alpha: 0.5,
                                  ),
                                  width: 0.8,
                                ),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: CyberTheme.fontCode(
                                  size: useBiggerFont ? 9.5 : 8.0,
                                  color: CyberTheme.neonCyan,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          if (isActive) ...[
                            SizedBox(width: isNarrow ? 1.5 : 6.0),
                            const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 14.0,
                                  color: CyberTheme.neonYellow,
                                )
                                .animate(
                                  onPlay: (controller) =>
                                      controller.repeat(reverse: true),
                                )
                                .fadeIn(duration: 200.ms)
                                .scaleXY(
                                  end: 1.25,
                                  duration: 600.ms,
                                  curve: Curves.easeInOut,
                                ),
                          ],
                          if (customInput != null) ...[
                            SizedBox(width: isNarrow ? 1.0 : 8.0),
                            customInput,
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (!isRunning && !isFeedback) ...[
                    SizedBox(width: isNarrow ? 0.0 : 4.0),
                    InkWell(
                      onTap: index > 0
                          ? () {
                              ref.read(audioControllerProvider).playClick();
                              notifier.moveBlock(
                                block.id,
                                targetParentId: parentId,
                                isElse: isElse,
                                index: index - 1,
                              );
                            }
                          : null,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: useBiggerFont
                              ? 6.0
                              : (isNarrow ? 1.0 : 7.0),
                          vertical: useBiggerFont
                              ? 6.0
                              : (isNarrow ? 5.0 : 7.0),
                        ),
                        child: Icon(
                          Icons.arrow_drop_up,
                          size: arrowIconSize,
                          color: index > 0
                              ? CyberTheme.neonCyan
                              : Colors.white24,
                        ),
                      ),
                    ),
                    SizedBox(width: isNarrow ? 0.0 : 2.0),
                    InkWell(
                      onTap: index < parentListLength - 1
                          ? () {
                              ref.read(audioControllerProvider).playClick();
                              notifier.moveBlock(
                                block.id,
                                targetParentId: parentId,
                                isElse: isElse,
                                index: index + 1,
                              );
                            }
                          : null,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: useBiggerFont
                              ? 6.0
                              : (isNarrow ? 1.0 : 7.0),
                          vertical: useBiggerFont
                              ? 6.0
                              : (isNarrow ? 5.0 : 7.0),
                        ),
                        child: Icon(
                          Icons.arrow_drop_down,
                          size: arrowIconSize,
                          color: index < parentListLength - 1
                              ? CyberTheme.neonCyan
                              : Colors.white24,
                        ),
                      ),
                    ),
                    SizedBox(width: isNarrow ? 0.0 : 4.0),
                    InkWell(
                      onTap: () {
                        ref.read(audioControllerProvider).playClick();
                        notifier.removeBlock(block.id);
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: useBiggerFont
                              ? 6.0
                              : (isNarrow ? 1.0 : 7.0),
                          vertical: useBiggerFont
                              ? 6.0
                              : (isNarrow ? 5.0 : 7.0),
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          size: deleteIconSize,
                          color: CyberTheme.neonPink,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Block Body (Nested lists)
            if (nestedBody != null)
              Padding(
                padding: bodyPadding,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: blockColor.withValues(alpha: 0.5),
                        width: 3.0,
                      ),
                      bottom: BorderSide(
                        color: blockColor.withValues(alpha: 0.15),
                        width: 1.0,
                      ),
                    ),
                    color: blockColor.withValues(alpha: 0.02),
                  ),
                  padding: innerBodyPadding,
                  child: nestedBody,
                ),
              ),
          ],
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isRunning
          ? null
          : () {
              ref.read(audioControllerProvider).playClick();
              if (block.type == BlockType.repeat ||
                  block.type == BlockType.whileLoop ||
                  block.type == BlockType.ifElse) {
                ref
                    .read(activeContainerProvider.notifier)
                    .select(block.id, isElse: false);
                if (block.type == BlockType.repeat) {
                  if (isFirstRepeat) {
                    ref
                        .read(tutorialActionTriggerProvider.notifier)
                        .trigger(TutorialTarget.firstRepeatBlock);
                  } else if (isSecondRepeat) {
                    ref
                        .read(tutorialActionTriggerProvider.notifier)
                        .trigger(TutorialTarget.secondRepeatBlock);
                  }
                }
              } else {
                ref
                    .read(activeContainerProvider.notifier)
                    .select(parentId, isElse: isElse);
              }

              // Auto scroll to show full item of this sequence item
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  Scrollable.ensureVisible(
                    context,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              });
            },
      child: card,
    );
  }

  Widget _buildNestedList(
    BuildContext context,
    WidgetRef ref,
    List<ProgramBlock> children,
    bool nestedIsElse,
    GameStateNotifier notifier,
  ) {
    final isNarrow = MediaQuery.sizeOf(context).width < 500;
    final List<Widget> nestedItems = [];
    for (int i = 0; i < children.length; i++) {
      final blockItem = children[i];
      if (i > 0) {
        nestedItems.add(const SizedBox(height: 2.0));
      }
      nestedItems.add(
        VisualBlock(
          block: blockItem,
          parentId: block.id,
          isElse: nestedIsElse,
          index: i,
          parentListLength: children.length,
          isRunning: isRunning,
          activeBlockId: activeBlockId,
        ),
      );
    }

    final activeContainer = ref.watch(activeContainerProvider);
    final isActiveTarget =
        activeContainer.parentId == block.id &&
        activeContainer.isElse == nestedIsElse;

    final Color blockColor;
    if (block.type == BlockType.repeat) {
      blockColor = const Color(0xFF8B5CF6);
    } else if (block.type == BlockType.whileLoop) {
      blockColor = const Color(0xFF6D28D9);
    } else {
      blockColor = const Color(0xFFF59E0B);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isRunning
          ? null
          : () {
              ref.read(audioControllerProvider).playClick();
              ref
                  .read(activeContainerProvider.notifier)
                  .select(block.id, isElse: nestedIsElse);
            },
      child: Container(
        decoration: BoxDecoration(
          color: isActiveTarget
              ? CyberTheme.neonCyan.withValues(alpha: 0.05)
              : Colors.transparent,
          border: Border.all(
            color: isActiveTarget
                ? CyberTheme.neonCyan.withValues(alpha: 0.6)
                : Colors.transparent,
            width: 1.0,
          ),
        ),
        padding: EdgeInsets.symmetric(
          vertical: 2.0,
          horizontal: isNarrow ? 1.0 : 4.0,
        ),
        child: children.isEmpty
            ? Container(
                height: 36.0,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActiveTarget
                      ? CyberTheme.neonCyan.withValues(alpha: 0.08)
                      : blockColor.withValues(alpha: 0.03),
                  border: Border.all(
                    color: isActiveTarget
                        ? CyberTheme.neonCyan
                        : blockColor.withValues(alpha: 0.15),
                    width: 1.0,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isActiveTarget
                        ? (isNarrow
                              ? 'TAP PALETTE TO INSERT'
                              : 'PALETTE TAP WILL INSERT HERE')
                        : (isNarrow
                              ? 'TAP TO ADD CODE'
                              : 'TAP TO ADD CODE HERE'),
                    textAlign: TextAlign.center,
                    style: CyberTheme.fontCode(
                      size: isNarrow ? 9.2 : 11.0,
                      color: isActiveTarget
                          ? CyberTheme.neonCyan
                          : blockColor.withValues(alpha: 0.4),
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...nestedItems,
                  if (isActiveTarget)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '● TARGETING THIS LOOP ●',
                          textAlign: TextAlign.center,
                          style: CyberTheme.fontCode(
                            size: 10.0,
                            color: CyberTheme.neonCyan,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

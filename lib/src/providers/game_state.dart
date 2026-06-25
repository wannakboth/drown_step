import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/level.dart';
import '../models/program_block.dart';

enum GameStatus {
  idle,
  running,
  paused,
  crashed,
  success,
}

class DroneGameState {
  final Level level;
  final List<ProgramBlock> program;
  final List<VMInstruction> vmInstructions;
  final int pc;
  final String? activeBlockId;
  final GameStatus status;
  
  // Drone current simulation state
  final int droneX;
  final int droneY;
  final int droneHeight; // 0 = landed, 1 = default altitude, 2+ = high altitude
  final Direction droneDirection;
  final int battery;
  final List<EnergyCell> remainingEnergyCells;
  final String? message;
  final List<Offset> pathHistory;
  final bool hasCargo; // True once drone lands on boxX, boxY
  final double speedMultiplier;
  final bool isStepMode;

  DroneGameState({
    required this.level,
    required this.program,
    required this.vmInstructions,
    required this.pc,
    this.activeBlockId,
    required this.status,
    required this.droneX,
    required this.droneY,
    required this.droneHeight,
    required this.droneDirection,
    required this.battery,
    required this.remainingEnergyCells,
    this.message,
    required this.pathHistory,
    required this.hasCargo,
    required this.speedMultiplier,
    this.isStepMode = false,
  });

  DroneGameState copyWith({
    Level? level,
    List<ProgramBlock>? program,
    List<VMInstruction>? vmInstructions,
    int? pc,
    String? activeBlockId,
    GameStatus? status,
    int? droneX,
    int? droneY,
    int? droneHeight,
    Direction? droneDirection,
    int? battery,
    List<EnergyCell>? remainingEnergyCells,
    String? message,
    List<Offset>? pathHistory,
    bool? hasCargo,
    double? speedMultiplier,
    bool? isStepMode,
  }) {
    return DroneGameState(
      level: level ?? this.level,
      program: program ?? this.program,
      vmInstructions: vmInstructions ?? this.vmInstructions,
      pc: pc ?? this.pc,
      activeBlockId: activeBlockId ?? this.activeBlockId,
      status: status ?? this.status,
      droneX: droneX ?? this.droneX,
      droneY: droneY ?? this.droneY,
      droneHeight: droneHeight ?? this.droneHeight,
      droneDirection: droneDirection ?? this.droneDirection,
      battery: battery ?? this.battery,
      remainingEnergyCells: remainingEnergyCells ?? this.remainingEnergyCells,
      message: message, // Allow setting to null explicitly
      pathHistory: pathHistory ?? this.pathHistory,
      hasCargo: hasCargo ?? this.hasCargo,
      speedMultiplier: speedMultiplier ?? this.speedMultiplier,
      isStepMode: isStepMode ?? this.isStepMode,
    );
  }

  int get totalBlockCount {
    int count(List<ProgramBlock> blocks) {
      int c = 0;
      for (final b in blocks) {
        c += 1;
        c += count(b.body);
        c += count(b.elseBody);
      }
      return c;
    }
    return count(program);
  }

  factory DroneGameState.initial(Level level) {
    return DroneGameState(
      level: level,
      program: [],
      vmInstructions: [],
      pc: -1,
      activeBlockId: null,
      status: GameStatus.idle,
      droneX: level.startX,
      droneY: level.startY,
      droneHeight: 0,
      droneDirection: level.startDirection,
      battery: level.initialBattery,
      remainingEnergyCells: List.from(level.energyCells),
      message: null,
      pathHistory: [Offset(level.startX.toDouble(), level.startY.toDouble())],
      hasCargo: false,
      speedMultiplier: 1.0,
      isStepMode: false,
    );
  }
}

class GameStateNotifier extends Notifier<DroneGameState> {
  Timer? _timer;

  @override
  DroneGameState build() {
    final level = ref.watch(currentLevelProvider);
    ref.onDispose(() {
      _timer?.cancel();
    });
    _timer?.cancel();
    return DroneGameState.initial(level);
  }

  double get speedMultiplier => state.speedMultiplier;

  void setSpeed(double speed) {
    state = state.copyWith(speedMultiplier: speed);
    if (state.status == GameStatus.running) {
      pauseSimulation();
      runSimulation();
    }
  }

  // --- AST Program Mutators ---

  void addBlock(ProgramBlock block, {String? parentId, bool isElse = false, int? index}) {
    if (state.status == GameStatus.running) return;

    final updated = _addBlockToTree(state.program, block, parentId, isElse, index);
    state = state.copyWith(program: updated);
  }

  bool blockExists(String blockId) {
    return _findBlockInTree(state.program, blockId) != null;
  }

  int getBlocksInContainerCount(String? parentId, bool isElse) {
    if (parentId == null) {
      return state.program.length;
    }
    final parentBlock = _findBlockInTree(state.program, parentId);
    if (parentBlock == null) return 0;
    return isElse ? parentBlock.elseBody.length : parentBlock.body.length;
  }

  int getBlockNestingDepth(String? blockId) {
    if (blockId == null) return 0;
    
    int? search(List<ProgramBlock> blocks, int currentDepth) {
      for (final block in blocks) {
        if (block.id == blockId) {
          return currentDepth;
        }
        
        final isNestingType = block.type == BlockType.repeat ||
            block.type == BlockType.whileLoop ||
            block.type == BlockType.ifElse;
        
        final nextDepth = isNestingType ? currentDepth + 1 : currentDepth;
        
        final bodyResult = search(block.body, nextDepth);
        if (bodyResult != null) return bodyResult;
        
        final elseResult = search(block.elseBody, nextDepth);
        if (elseResult != null) return elseResult;
      }
      return null;
    }
    
    return search(state.program, 0) ?? 0;
  }

  void removeBlock(String blockId) {
    if (state.status == GameStatus.running) return;

    final updated = _removeBlockFromTree(state.program, blockId);
    state = state.copyWith(program: updated);
  }

  void moveBlock(String blockId, {String? targetParentId, bool isElse = false, int? index}) {
    if (state.status == GameStatus.running) return;

    final targetBlock = _findBlockInTree(state.program, blockId);
    if (targetBlock == null) return;

    // 1. Remove from old position
    var updated = _removeBlockFromTree(state.program, blockId);
    // 2. Add to new position
    updated = _addBlockToTree(updated, targetBlock, targetParentId, isElse, index);

    state = state.copyWith(program: updated);
  }

  void updateBlockRepeat(String blockId, int count) {
    if (state.status == GameStatus.running) return;

    final updated = _updateRepeatInTree(state.program, blockId, count);
    state = state.copyWith(program: updated);
  }

  void updateBlockCondition(String blockId, ConditionType condition) {
    if (state.status == GameStatus.running) return;

    final updated = _updateConditionInTree(state.program, blockId, condition);
    state = state.copyWith(program: updated);
  }

  void clearProgram() {
    if (state.status == GameStatus.running) return;
    state = state.copyWith(program: []);
  }

  // --- AST Tree Helper Logic ---

  List<ProgramBlock> _addBlockToTree(
    List<ProgramBlock> currentBlocks,
    ProgramBlock blockToAdd,
    String? parentId,
    bool isElse,
    int? index,
  ) {
    if (parentId == null) {
      final newBlocks = List<ProgramBlock>.from(currentBlocks);
      if (index != null && index >= 0 && index <= newBlocks.length) {
        newBlocks.insert(index, blockToAdd);
      } else {
        newBlocks.add(blockToAdd);
      }
      return newBlocks;
    }

    return currentBlocks.map((block) {
      if (block.id == parentId) {
        if (isElse) {
          final newElseBody = List<ProgramBlock>.from(block.elseBody);
          if (index != null && index >= 0 && index <= newElseBody.length) {
            newElseBody.insert(index, blockToAdd);
          } else {
            newElseBody.add(blockToAdd);
          }
          return block.copyWith(elseBody: newElseBody);
        } else {
          final newBody = List<ProgramBlock>.from(block.body);
          if (index != null && index >= 0 && index <= newBody.length) {
            newBody.insert(index, blockToAdd);
          } else {
            newBody.add(blockToAdd);
          }
          return block.copyWith(body: newBody);
        }
      }

      return block.copyWith(
        body: _addBlockToTree(block.body, blockToAdd, parentId, isElse, index),
        elseBody: _addBlockToTree(block.elseBody, blockToAdd, parentId, isElse, index),
      );
    }).toList();
  }

  List<ProgramBlock> _removeBlockFromTree(List<ProgramBlock> currentBlocks, String blockId) {
    final updatedList = <ProgramBlock>[];
    for (final block in currentBlocks) {
      if (block.id == blockId) {
        continue; // Exclude it (deletes it and all its children!)
      }
      updatedList.add(block.copyWith(
        body: _removeBlockFromTree(block.body, blockId),
        elseBody: _removeBlockFromTree(block.elseBody, blockId),
      ));
    }
    return updatedList;
  }

  ProgramBlock? _findBlockInTree(List<ProgramBlock> currentBlocks, String blockId) {
    for (final block in currentBlocks) {
      if (block.id == blockId) return block;
      final bodyResult = _findBlockInTree(block.body, blockId);
      if (bodyResult != null) return bodyResult;
      final elseResult = _findBlockInTree(block.elseBody, blockId);
      if (elseResult != null) return elseResult;
    }
    return null;
  }

  List<ProgramBlock> _updateRepeatInTree(List<ProgramBlock> currentBlocks, String blockId, int count) {
    return currentBlocks.map((block) {
      if (block.id == blockId) {
        return block.copyWith(repeatCount: count);
      }
      return block.copyWith(
        body: _updateRepeatInTree(block.body, blockId, count),
        elseBody: _updateRepeatInTree(block.elseBody, blockId, count),
      );
    }).toList();
  }

  List<ProgramBlock> _updateConditionInTree(List<ProgramBlock> currentBlocks, String blockId, ConditionType condition) {
    return currentBlocks.map((block) {
      if (block.id == blockId) {
        return block.copyWith(condition: condition);
      }
      return block.copyWith(
        body: _updateConditionInTree(block.body, blockId, condition),
        elseBody: _updateConditionInTree(block.elseBody, blockId, condition),
      );
    }).toList();
  }

  // --- Simulation Execution Engine ---

  void resetSimulation() {
    _timer?.cancel();
    state = DroneGameState(
      level: state.level,
      program: state.program,
      vmInstructions: [],
      pc: -1,
      activeBlockId: null,
      status: GameStatus.idle,
      droneX: state.level.startX,
      droneY: state.level.startY,
      droneHeight: 0,
      droneDirection: state.level.startDirection,
      battery: state.level.initialBattery,
      remainingEnergyCells: List.from(state.level.energyCells),
      message: null,
      pathHistory: [Offset(state.level.startX.toDouble(), state.level.startY.toDouble())],
      hasCargo: false,
      speedMultiplier: state.speedMultiplier,
    );
  }

  void runSimulation() {
    if (state.program.isEmpty) {
      state = state.copyWith(
        status: GameStatus.crashed,
        message: "Program is empty! Add coding blocks to start.",
      );
      return;
    }

    if ((state.status == GameStatus.paused || state.isStepMode) && state.vmInstructions.isNotEmpty) {
      state = state.copyWith(
        status: GameStatus.running,
        isStepMode: false,
      );
      _scheduleNextStep();
      return;
    }

    if (state.status == GameStatus.crashed || state.status == GameStatus.success) {
      resetSimulation();
    }

    final compiled = compileProgram(state.program);
    if (compiled.isEmpty) {
      state = state.copyWith(
        status: GameStatus.crashed,
        message: "No action commands compiled from program blocks.",
      );
      return;
    }

    state = state.copyWith(
      status: GameStatus.running,
      vmInstructions: compiled,
      pc: -1,
      activeBlockId: null,
      isStepMode: false,
    );

    _scheduleNextStep();
  }

  void startStepMode() {
    if (state.program.isEmpty) {
      state = state.copyWith(
        status: GameStatus.crashed,
        message: "Program is empty! Add coding blocks to start.",
      );
      return;
    }

    if (state.status == GameStatus.crashed || state.status == GameStatus.success) {
      resetSimulation();
    }

    final compiled = compileProgram(state.program);
    if (compiled.isEmpty) {
      state = state.copyWith(
        status: GameStatus.crashed,
        message: "No action commands compiled from program blocks.",
      );
      return;
    }

    state = state.copyWith(
      status: GameStatus.paused,
      vmInstructions: compiled,
      pc: -1,
      activeBlockId: null,
      isStepMode: true,
    );
  }

  void stepSimulation() {
    _timer?.cancel();
    if (!state.isStepMode || state.vmInstructions.isEmpty) {
      startStepMode();
    }

    if (state.status == GameStatus.crashed || state.status == GameStatus.success) {
      return;
    }

    executeNextStep();
  }

  void pauseSimulation() {
    _timer?.cancel();
    state = state.copyWith(status: GameStatus.paused);
  }

  void _scheduleNextStep() {
    _timer?.cancel();
    
    bool isCargoPickup = false;
    if (state.pc >= 0 && state.pc < state.vmInstructions.length) {
      final inst = state.vmInstructions[state.pc];
      if (inst.type == InstructionType.executeAction &&
          inst.action == ActionType.land &&
          state.droneX == state.level.boxX &&
          state.droneY == state.level.boxY &&
          state.hasCargo) {
        isCargoPickup = true;
      }
    }

    final int baseDelay = isCargoPickup ? 3700 : 2100;
    int delayMs;
    if (state.pc == -1) {
      // Wait at least 400ms for the 350ms layout expand animation to finish
      final speedDelay = (baseDelay / state.speedMultiplier).round();
      delayMs = math.max(400, speedDelay);
    } else {
      delayMs = (baseDelay / state.speedMultiplier).round();
    }

    _timer = Timer(Duration(milliseconds: delayMs), () {
      if (state.status == GameStatus.running) {
        executeNextStep();
      }
    });
  }

  void executeNextStep() {
    int nextPC = state.pc + 1;
    
    // Evaluate VM jump bytecode immediately in a loop
    while (true) {
      if (nextPC >= state.vmInstructions.length) {
        _timer?.cancel();
        if (state.droneHeight == 0 && state.droneX == state.level.targetX && state.droneY == state.level.targetY) {
          if (state.hasCargo) {
            state = state.copyWith(
              pc: nextPC,
              activeBlockId: null,
              status: GameStatus.success,
              message: "Mission Accomplished! Cargo delivered.",
            );
          } else {
            state = state.copyWith(
              pc: nextPC,
              activeBlockId: null,
              status: GameStatus.crashed,
              message: "Landed on target, but empty! You forgot to pick up the cargo at (${state.level.boxX}, ${state.level.boxY}).",
            );
          }
        } else if (state.droneHeight > 0) {
          state = state.copyWith(
            pc: nextPC,
            activeBlockId: null,
            status: GameStatus.crashed,
            message: "Out of commands! The drone is hovering in mid-air.",
          );
        } else {
          state = state.copyWith(
            pc: nextPC,
            activeBlockId: null,
            status: GameStatus.crashed,
            message: "Out of commands! Drone landed at the wrong coordinates.",
          );
        }
        return;
      }

      final inst = state.vmInstructions[nextPC];
      if (inst.type == InstructionType.jump) {
        nextPC = inst.jumpTarget;
      } else if (inst.type == InstructionType.jumpIfNot) {
        final conditionVal = evaluateCondition(inst.condition!);
        if (!conditionVal) {
          nextPC = inst.jumpTarget;
        } else {
          nextPC = nextPC + 1;
        }
      } else {
        // executeAction instruction - run it!
        break;
      }
    }

    final inst = state.vmInstructions[nextPC];
    final action = inst.action!;

    int nextX = state.droneX;
    int nextY = state.droneY;
    int nextHeight = state.droneHeight;
    Direction nextDir = state.droneDirection;
    int nextBattery = state.battery - 1;
    bool nextHasCargo = state.hasCargo;
    String? crashMsg;
    GameStatus nextStatus = state.isStepMode ? GameStatus.paused : GameStatus.running;

    switch (action) {
      case ActionType.takeoff:
        if (state.droneHeight > 0) {
          nextStatus = GameStatus.crashed;
          crashMsg = "TAKEOFF FAIL: Drone is already flying.";
        } else {
          nextHeight = 1;
        }
        break;

      case ActionType.land:
        if (state.droneHeight == 0) {
          nextStatus = GameStatus.crashed;
          crashMsg = "LAND FAIL: Drone is already on the ground.";
        } else if (state.droneHeight > 1) {
          nextStatus = GameStatus.crashed;
          crashMsg = "LAND FAIL: Too high! Descend to altitude 1 before landing.";
        } else {
          nextHeight = 0;
          
          if (nextX == state.level.boxX && nextY == state.level.boxY) {
            if (!state.hasCargo) {
              nextHasCargo = true;
              crashMsg = "CARGO ACQUIRED! Proceed to the target pad.";
            } else {
              crashMsg = "Hovering over cargo pickup zone.";
            }
          } else if (nextX == state.level.targetX && nextY == state.level.targetY) {
            if (nextHasCargo) {
              nextStatus = GameStatus.success;
              crashMsg = "Mission Accomplished! Cargo delivered safely.";
            } else {
              nextStatus = GameStatus.crashed;
              crashMsg = "CRASH: Landed on target without the cargo box! You must pick up the cargo first.";
            }
          } else {
            nextStatus = GameStatus.crashed;
            crashMsg = "CRASH: Landed off-target at ($nextX, $nextY).";
          }
        }
        break;

      case ActionType.forward:
        if (state.droneHeight == 0) {
          nextStatus = GameStatus.crashed;
          crashMsg = "ENGINE FAIL: Cannot fly while landed. Use TAKEOFF first.";
        } else {
          final delta = state.droneDirection.delta;
          nextX = state.droneX + delta.dx.toInt();
          nextY = state.droneY + delta.dy.toInt();

          if (nextX < 0 || nextX >= state.level.gridWidth || nextY < 0 || nextY >= state.level.gridHeight) {
            nextStatus = GameStatus.crashed;
            crashMsg = "CRASH: Flew out of grid boundaries!";
          } else {
            for (final obs in state.level.obstacles) {
              if (obs.x == nextX && obs.y == nextY) {
                if (nextHeight <= obs.height) {
                  nextStatus = GameStatus.crashed;
                  crashMsg = "CRASH: Hit an obstacle at ($nextX, $nextY)! Height ${obs.height} requires altitude ${obs.height + 1}.";
                  break;
                }
              }
            }
          }
        }
        break;

      case ActionType.rotateLeft:
        if (state.droneHeight == 0) {
          nextStatus = GameStatus.crashed;
          crashMsg = "FAIL: Cannot rotate while landed.";
        } else {
          nextDir = state.droneDirection.rotateLeft();
        }
        break;

      case ActionType.rotateRight:
        if (state.droneHeight == 0) {
          nextStatus = GameStatus.crashed;
          crashMsg = "FAIL: Cannot rotate while landed.";
        } else {
          nextDir = state.droneDirection.rotateRight();
        }
        break;

      case ActionType.ascend:
        if (state.droneHeight == 0) {
          nextStatus = GameStatus.crashed;
          crashMsg = "FAIL: Cannot ascend while landed. Take off first.";
        } else {
          nextHeight += 1;
        }
        break;

      case ActionType.descend:
        if (state.droneHeight == 0) {
          nextStatus = GameStatus.crashed;
          crashMsg = "FAIL: Drone is already on the ground.";
        } else if (state.droneHeight == 1) {
          nextStatus = GameStatus.crashed;
          crashMsg = "FAIL: Cannot descend below altitude 1. Use LAND command instead.";
        } else {
          nextHeight -= 1;
        }
        break;
    }

    final updatedEnergyCells = List<EnergyCell>.from(state.remainingEnergyCells);
    if (nextStatus != GameStatus.crashed) {
      int cellIndex = -1;
      for (int i = 0; i < updatedEnergyCells.length; i++) {
        final cell = updatedEnergyCells[i];
        if (cell.x == nextX && cell.y == nextY && cell.height == nextHeight) {
          cellIndex = i;
          break;
        }
      }
      if (cellIndex != -1) {
        final cell = updatedEnergyCells.removeAt(cellIndex);
        nextBattery += cell.charge;
      }
    }

    if (nextStatus != GameStatus.crashed && nextStatus != GameStatus.success && nextBattery <= 0) {
      nextStatus = GameStatus.crashed;
      crashMsg = "CRASH: Out of battery power!";
    }

    final newHistory = List<Offset>.from(state.pathHistory)
      ..add(Offset(nextX.toDouble(), nextY.toDouble()));

    state = state.copyWith(
      pc: nextPC,
      activeBlockId: inst.blockId,
      droneX: nextX,
      droneY: nextY,
      droneHeight: nextHeight,
      droneDirection: nextDir,
      battery: nextBattery,
      remainingEnergyCells: updatedEnergyCells,
      status: nextStatus,
      message: crashMsg,
      pathHistory: newHistory,
      hasCargo: nextHasCargo,
    );

    if (state.status == GameStatus.running) {
      _scheduleNextStep();
    }
  }

  bool evaluateCondition(ConditionType condition) {
    switch (condition) {
      case ConditionType.hasCargo:
        return state.hasCargo;
      case ConditionType.notHasCargo:
        return !state.hasCargo;
      case ConditionType.obstacleAhead:
        final delta = state.droneDirection.delta;
        final tx = state.droneX + delta.dx.toInt();
        final ty = state.droneY + delta.dy.toInt();
        if (tx < 0 || tx >= state.level.gridWidth || ty < 0 || ty >= state.level.gridHeight) {
          return true; // boundaries are obstacles
        }
        return state.level.obstacles.any((obs) => obs.x == tx && obs.y == ty && state.droneHeight <= obs.height);
      case ConditionType.obstacleNearby:
        for (final dir in Direction.values) {
          final delta = dir.delta;
          final tx = state.droneX + delta.dx.toInt();
          final ty = state.droneY + delta.dy.toInt();
          if (tx >= 0 && tx < state.level.gridWidth && ty >= 0 && ty < state.level.gridHeight) {
            if (state.level.obstacles.any((obs) => obs.x == tx && obs.y == ty && state.droneHeight <= obs.height)) {
              return true;
            }
          }
        }
        return false;
      case ConditionType.batteryLow:
        return state.battery < 5;
      case ConditionType.batteryHigh:
        return state.battery >= 5;
      case ConditionType.altitudeHigh:
        return state.droneHeight > 1;
      case ConditionType.onTarget:
        return state.droneX == state.level.targetX && state.droneY == state.level.targetY;
    }
  }
}

class CurrentLevelNotifier extends Notifier<Level> {
  @override
  Level build() {
    final auth = ref.watch(authProvider);
    final mode = ref.watch(gameModeProvider);
    final user = auth.currentUser ?? 'guest';
    final prefs = ref.watch(authProvider.notifier).prefs;
    
    final seenTutorial = ref.watch(seenTutorialMissionsProvider);
    final levels = seenTutorial ? Level.getLevelsForMode(mode) : Level.tutorialMissions;
    
    if (prefs != null) {
      final key = 'dronestep_${user}_last_played_${mode.name}_tutorial_$seenTutorial';
      final rawVal = prefs.get(key);
      String? lastPlayedId;
      if (rawVal is int) {
        if (seenTutorial) {
          lastPlayedId = mode == GameMode.hard ? 'H$rawVal' : 'N$rawVal';
        } else {
          lastPlayedId = 'T${rawVal.abs()}';
        }
        prefs.setString(key, lastPlayedId);
      } else if (rawVal is String) {
        lastPlayedId = rawVal;
      }
      if (lastPlayedId != null) {
        final index = levels.indexWhere((lvl) => lvl.id == lastPlayedId);
        if (index != -1) {
          return levels[index];
        }
      }
    }
    
    final maxUnlocked = seenTutorial ? ref.watch(maxUnlockedLevelProvider) : ref.watch(maxUnlockedTutorialLevelProvider);
    final index = math.min(maxUnlocked - 1, levels.length - 1);
    if (index >= 0 && index < levels.length) {
      return levels[index];
    }
    return levels.first;
  }

  void setLevel(Level level) {
    state = level;
    ref.read(showHintGuidanceProvider.notifier).set(false);
    final auth = ref.read(authProvider);
    final mode = ref.read(gameModeProvider);
    final user = auth.currentUser ?? 'guest';
    final prefs = ref.read(authProvider.notifier).prefs;
    final seenTutorial = ref.read(seenTutorialMissionsProvider);
    if (prefs != null) {
      prefs.setString('dronestep_${user}_last_played_${mode.name}_tutorial_$seenTutorial', level.id);
    }
  }
}

final currentLevelProvider = NotifierProvider<CurrentLevelNotifier, Level>(
  CurrentLevelNotifier.new,
);

final gameStateProvider = NotifierProvider<GameStateNotifier, DroneGameState>(
  GameStateNotifier.new,
);

class ConsoleExpandedNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.listen<DroneGameState>(gameStateProvider, (previous, next) {
      if (next.status == GameStatus.running && previous?.status != GameStatus.running) {
        state = false;
      } else if (next.status == GameStatus.idle && previous?.status != GameStatus.idle) {
        state = true;
      }
    });
    return true;
  }

  void setExpanded(bool val) {
    state = val;
  }
}

final consoleExpandedProvider = NotifierProvider<ConsoleExpandedNotifier, bool>(
  ConsoleExpandedNotifier.new,
);

class ActiveContainer {
  final String? parentId;
  final bool isElse;

  const ActiveContainer({this.parentId, this.isElse = false});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveContainer &&
          runtimeType == other.runtimeType &&
          parentId == other.parentId &&
          isElse == other.isElse;

  @override
  int get hashCode => parentId.hashCode ^ isElse.hashCode;
}

class ActiveContainerNotifier extends Notifier<ActiveContainer> {
  @override
  ActiveContainer build() {
    ref.listen<DroneGameState>(gameStateProvider, (previous, next) {
      if (next.status == GameStatus.running && previous?.status != GameStatus.running) {
        state = const ActiveContainer();
      }
    });
    return const ActiveContainer();
  }

  void select(String? parentId, {bool isElse = false}) {
    state = ActiveContainer(parentId: parentId, isElse: isElse);
  }

  void reset() {
    state = const ActiveContainer();
  }
}

final activeContainerProvider = NotifierProvider<ActiveContainerNotifier, ActiveContainer>(
  ActiveContainerNotifier.new,
);

class LastAddedBlockIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setLastAddedId(String? id) {
    state = id;
  }
}

final lastAddedBlockIdProvider = NotifierProvider<LastAddedBlockIdNotifier, String?>(
  LastAddedBlockIdNotifier.new,
);

enum AppScreen {
  home,
  game,
  sandboxEditor,
}

class AppScreenNotifier extends Notifier<AppScreen> {
  @override
  AppScreen build() => AppScreen.home;

  void toScreen(AppScreen screen) {
    state = screen;
  }
}

final appScreenProvider = NotifierProvider<AppScreenNotifier, AppScreen>(
  AppScreenNotifier.new,
);

class SandboxLevelsNotifier extends Notifier<List<Level>> {
  SharedPreferences? _prefs;
  static const _key = 'sandbox_levels';

  @override
  List<Level> build() {
    _init();
    return [];
  }

  Future<void> _init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (_prefs != null) {
        final listStr = _prefs!.getString(_key);
        if (listStr != null) {
          final List<dynamic> listJson = jsonDecode(listStr);
          state = listJson.map((item) => Level.fromJson(item as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
  }

  Future<void> saveLevel(Level level) async {
    final updated = [...state];
    final existingIndex = updated.indexWhere((l) => l.id == level.id);
    if (existingIndex != -1) {
      updated[existingIndex] = level;
    } else {
      updated.add(level);
    }
    state = updated;
    await _saveToPrefs();
  }

  Future<void> deleteLevel(String id) async {
    state = state.where((l) => l.id != id).toList();
    await _saveToPrefs();
  }

  Future<void> _saveToPrefs() async {
    if (_prefs == null) return;
    final listJson = state.map((l) => l.toJson()).toList();
    await _prefs!.setString(_key, jsonEncode(listJson));
  }
}

final sandboxLevelsProvider = NotifierProvider<SandboxLevelsNotifier, List<Level>>(
  SandboxLevelsNotifier.new,
);

class EditingSandboxLevelNotifier extends Notifier<Level?> {
  @override
  Level? build() => null;

  void setLevel(Level? level) {
    state = level;
  }
}

final editingSandboxLevelProvider = NotifierProvider<EditingSandboxLevelNotifier, Level?>(
  EditingSandboxLevelNotifier.new,
);

class MaxUnlockedLevelNotifier extends Notifier<int> {
  @override
  int build() => 1;

  void unlockLevel(String levelId) {
    final numStr = levelId.replaceAll(RegExp(r'[^0-9]'), '');
    final lvlNum = int.tryParse(numStr) ?? 1;
    if (lvlNum >= state) {
      state = lvlNum + 1;
      ref.read(authProvider.notifier).saveActiveProgress(state, ref.read(levelStarsProvider));
    }
  }

  void setMaxUnlocked(int lvl) {
    state = lvl;
  }
}

final maxUnlockedLevelProvider = NotifierProvider<MaxUnlockedLevelNotifier, int>(
  MaxUnlockedLevelNotifier.new,
);

class MaxUnlockedTutorialLevelNotifier extends Notifier<int> {
  @override
  int build() {
    final auth = ref.watch(authProvider);
    final user = auth.currentUser ?? 'guest';
    final prefs = ref.watch(authProvider.notifier).prefs;
    if (prefs == null) return 1;
    return prefs.getInt('dronestep_${user}_max_unlocked_tutorial') ?? 1;
  }

  Future<void> unlockTutorialLevel(String levelId) async {
    final numStr = levelId.replaceAll(RegExp(r'[^0-9]'), '');
    final stepNumber = int.tryParse(numStr) ?? 1;
    if (stepNumber >= state && state < 3) {
      state = stepNumber + 1;
      final auth = ref.read(authProvider);
      final user = auth.currentUser ?? 'guest';
      final prefs = ref.read(authProvider.notifier).prefs;
      if (prefs != null) {
        await prefs.setInt('dronestep_${user}_max_unlocked_tutorial', state);
      }
    }
  }
}

final maxUnlockedTutorialLevelProvider = NotifierProvider<MaxUnlockedTutorialLevelNotifier, int>(
  MaxUnlockedTutorialLevelNotifier.new,
);

class LevelStarsNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => {};

  void setStars(String levelId, int stars) {
    final current = state[levelId] ?? 0;
    if (stars > current) {
      state = {
        ...state,
        levelId: stars,
      };
      ref.read(authProvider.notifier).saveActiveProgress(ref.read(maxUnlockedLevelProvider), state);
    }
  }

  void setAllStars(Map<String, int> stars) {
    state = stars;
  }
}

final levelStarsProvider = NotifierProvider<LevelStarsNotifier, Map<String, int>>(
  LevelStarsNotifier.new,
);

class GameModeNotifier extends Notifier<GameMode> {
  @override
  GameMode build() => GameMode.normal;

  void setMode(GameMode mode) {
    state = mode;
    ref.read(authProvider.notifier).onModeChanged();
  }
}

final gameModeProvider = NotifierProvider<GameModeNotifier, GameMode>(
  GameModeNotifier.new,
);

class AuthStatus {
  final String? currentUser;
  final List<String> registeredUsers;
  final String? message;

  const AuthStatus({
    this.currentUser,
    this.registeredUsers = const [],
    this.message,
  });

  AuthStatus copyWith({
    String? currentUser,
    bool clearUser = false,
    List<String>? registeredUsers,
    String? message,
  }) {
    return AuthStatus(
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      registeredUsers: registeredUsers ?? this.registeredUsers,
      message: message,
    );
  }
}

class AuthNotifier extends Notifier<AuthStatus> {
  SharedPreferences? _prefs;
  bool _initialized = false;

  SharedPreferences? get prefs => _prefs;

  @override
  AuthStatus build() {
    _initPrefs();
    return const AuthStatus();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;

    final usersList = _prefs!.getStringList('dronestep_users') ?? [];
    final currentUser = _prefs!.getString('dronestep_current_user');

    state = AuthStatus(
      currentUser: currentUser,
      registeredUsers: usersList,
    );

    _syncProgressToProviders();
  }

  void _syncProgressToProviders() {
    if (!_initialized || _prefs == null) return;
    
    final mode = ref.read(gameModeProvider);
    final user = state.currentUser ?? 'guest';

    final maxKey = 'dronestep_${user}_max_unlocked_${mode.name}';
    final maxLvl = _prefs!.getInt(maxKey) ?? 1;
    ref.read(maxUnlockedLevelProvider.notifier).setMaxUnlocked(maxLvl);

    final starsKey = 'dronestep_${user}_stars_${mode.name}';
    final starsJson = _prefs!.getString(starsKey) ?? '{}';
    Map<String, int> starsMap = {};
    try {
      final decoded = jsonDecode(starsJson) as Map;
      starsMap = decoded.map((key, val) {
        String newKey = key.toString();
        final parsedKey = int.tryParse(newKey);
        if (parsedKey != null) {
          if (parsedKey < 0) {
            newKey = 'T${parsedKey.abs()}';
          } else {
            newKey = mode == GameMode.hard ? 'H$newKey' : 'N$newKey';
          }
        }
        return MapEntry(newKey, int.parse(val.toString()));
      });
    } catch (_) {}
    ref.read(levelStarsProvider.notifier).setAllStars(starsMap);

    final hintsKey = 'dronestep_${user}_unlocked_hints_${mode.name}';
    final hintsListStr = _prefs!.getStringList(hintsKey) ?? [];
    final hintsListMapped = hintsListStr.map((id) {
      String newId = id.toString();
      final parsedId = int.tryParse(newId);
      if (parsedId != null) {
        if (parsedId < 0) {
          newId = 'T${parsedId.abs()}';
        } else {
          newId = mode == GameMode.hard ? 'H$newId' : 'N$newId';
        }
      }
      return newId;
    }).toList();
    ref.read(unlockedHintsProvider.notifier).setUnlocked(hintsListMapped);

    ref.read(pilotBatteryProvider.notifier).initBattery(_prefs!, user);
    ref.read(diamondProvider.notifier).initDiamonds(_prefs!, user);
    ref.read(boughtHintsProvider.notifier).initBoughtHints(_prefs!, user);
  }

  Future<bool> register(String username, String password) async {
    if (!_initialized || _prefs == null || username.isEmpty || password.isEmpty) {
      state = state.copyWith(message: 'Invalid input fields.');
      return false;
    }

    final trimmedUser = username.trim();
    if (state.registeredUsers.contains(trimmedUser)) {
      state = state.copyWith(message: 'Pilot ID already registered.');
      return false;
    }

    final newList = List<String>.from(state.registeredUsers)..add(trimmedUser);
    await _prefs!.setStringList('dronestep_users', newList);
    await _prefs!.setString('dronestep_user_${trimmedUser}_password', password);
    await _prefs!.setString('dronestep_current_user', trimmedUser);

    state = state.copyWith(
      currentUser: trimmedUser,
      registeredUsers: newList,
      message: 'Pilot registered and synced!',
    );

    _syncProgressToProviders();
    return true;
  }

  Future<bool> login(String username, String password) async {
    if (!_initialized || _prefs == null || username.isEmpty || password.isEmpty) {
      state = state.copyWith(message: 'Invalid input fields.');
      return false;
    }

    final trimmedUser = username.trim();
    if (!state.registeredUsers.contains(trimmedUser)) {
      state = state.copyWith(message: 'Pilot ID not found.');
      return false;
    }

    final storedPass = _prefs!.getString('dronestep_user_${trimmedUser}_password');
    if (storedPass != password) {
      state = state.copyWith(message: 'Invalid security passkey.');
      return false;
    }

    await _prefs!.setString('dronestep_current_user', trimmedUser);

    state = state.copyWith(
      currentUser: trimmedUser,
      message: 'Pilot profile synced.',
    );

    _syncProgressToProviders();
    return true;
  }

  Future<void> logout() async {
    if (!_initialized || _prefs == null) return;

    await _prefs!.remove('dronestep_current_user');

    state = state.copyWith(
      clearUser: true,
      message: 'Logged out. Guest profile active.',
    );

    _syncProgressToProviders();
  }

  Future<void> saveActiveProgress(int maxUnlocked, Map<String, int> stars) async {
    if (!_initialized || _prefs == null) return;

    final mode = ref.read(gameModeProvider);
    final user = state.currentUser ?? 'guest';

    final maxKey = 'dronestep_${user}_max_unlocked_${mode.name}';
    await _prefs!.setInt(maxKey, maxUnlocked);

    final starsKey = 'dronestep_${user}_stars_${mode.name}';
    final starsStrMap = stars.map((key, val) => MapEntry(key, val));
    await _prefs!.setString(starsKey, jsonEncode(starsStrMap));
  }

  Future<void> saveUnlockedHint(String levelId) async {
    if (!_initialized || _prefs == null) return;
    final mode = ref.read(gameModeProvider);
    final user = state.currentUser ?? 'guest';
    final key = 'dronestep_${user}_unlocked_hints_${mode.name}';
    final current = ref.read(unlockedHintsProvider);
    final newList = [...current, levelId];
    await _prefs!.setStringList(key, newList);
  }

  void onModeChanged() {
    _syncProgressToProviders();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthStatus>(
  AuthNotifier.new,
);

class UnlockedHintsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void setUnlocked(List<String> ids) {
    state = ids;
  }

  void unlockHint(String levelId) {
    state = [...state, levelId];
    ref.read(authProvider.notifier).saveUnlockedHint(levelId);
  }
}

final unlockedHintsProvider = NotifierProvider<UnlockedHintsNotifier, List<String>>(
  UnlockedHintsNotifier.new,
);

final remainingHintsProvider = Provider<int>((ref) {
  final starsMap = ref.watch(levelStarsProvider);
  final unlockedHints = ref.watch(unlockedHintsProvider);
  final boughtHints = ref.watch(boughtHintsProvider);
  final completedCount = starsMap.values.where((stars) => stars > 0).length;
  final totalHintsEarned = completedCount * 3;
  return math.max(0, totalHintsEarned + boughtHints - unlockedHints.length);
});

class SeenTutorialNotifier extends Notifier<bool> {
  @override
  bool build() {
    final auth = ref.watch(authProvider);
    final user = auth.currentUser ?? 'guest';
    final prefs = ref.watch(authProvider.notifier).prefs;
    if (prefs == null) return false;

    // Fallback: If T3 has stars > 0, they have finished the tutorial.
    final starsKey = 'dronestep_${user}_stars_normal';
    final starsJson = prefs.getString(starsKey) ?? '{}';
    try {
      final decoded = jsonDecode(starsJson) as Map;
      final t3Stars = decoded['T3'] ?? 0;
      if (int.parse(t3Stars.toString()) > 0) {
        return true;
      }
    } catch (_) {}

    return prefs.getBool('dronestep_${user}_seen_tutorial_missions') ?? false;
  }

  Future<void> markAsSeen() async {
    final auth = ref.read(authProvider);
    final user = auth.currentUser ?? 'guest';
    final prefs = ref.read(authProvider.notifier).prefs;
    if (prefs != null) {
      await prefs.setBool('dronestep_${user}_seen_tutorial_missions', true);
      state = true;
    }
  }

  Future<void> reset() async {
    final auth = ref.read(authProvider);
    final user = auth.currentUser ?? 'guest';
    final prefs = ref.read(authProvider.notifier).prefs;
    if (prefs != null) {
      await prefs.remove('dronestep_${user}_seen_tutorial_missions');
      state = false;
    }
  }
}

final seenTutorialMissionsProvider = NotifierProvider<SeenTutorialNotifier, bool>(
  SeenTutorialNotifier.new,
);

class PilotBatteryNotifier extends Notifier<int> with WidgetsBindingObserver {
  Timer? _timer;
  static const int maxBattery = 50;
  static const int secondsPerCharge = 60; // 60 seconds per charge
  DateTime _lastRechargeTime = DateTime.now();

  DateTime get lastRechargeTime => _lastRechargeTime;

  @override
  int build() {
    WidgetsBinding.instance.addObserver(this);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _rechargePassive();
    });

    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _timer?.cancel();
    });

    return maxBattery;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _rechargePassive();
    }
  }

  int getSecondsRemaining() {
    if (state >= maxBattery) return 0;
    final now = DateTime.now();
    final diff = now.difference(_lastRechargeTime);
    final elapsed = diff.inSeconds;
    final remaining = secondsPerCharge - (elapsed % secondsPerCharge);
    return math.max(0, remaining);
  }

  int getTotalSecondsRemaining() {
    if (state >= maxBattery) return 0;
    final nextChargeRemaining = getSecondsRemaining();
    final fullChargesNeeded = maxBattery - state - 1;
    return nextChargeRemaining + (fullChargesNeeded * secondsPerCharge);
  }

  Future<void> initBattery(SharedPreferences prefs, String user) async {
    final batteryKey = 'dronestep_${user}_battery';
    final timestampKey = 'dronestep_${user}_battery_timestamp';

    int level = prefs.getInt(batteryKey) ?? maxBattery;
    final timestampStr = prefs.getString(timestampKey);
    final now = DateTime.now();

    if (timestampStr != null && level < maxBattery) {
      final lastTime = DateTime.parse(timestampStr);
      final difference = now.difference(lastTime);
      final chargesGained = difference.inSeconds ~/ secondsPerCharge;
      if (chargesGained > 0) {
        level = math.min(maxBattery, level + chargesGained);
      }
    }

    state = level;

    DateTime saveTime = now;
    if (timestampStr != null && level < maxBattery) {
      final lastTime = DateTime.parse(timestampStr);
      final elapsedSeconds = now.difference(lastTime).inSeconds;
      saveTime = lastTime.add(Duration(seconds: (elapsedSeconds ~/ secondsPerCharge) * secondsPerCharge));
    }

    _lastRechargeTime = saveTime;
    _saveToPrefs(prefs, user, level, saveTime);
  }

  void _rechargePassive() {
    final auth = ref.read(authProvider);
    final user = auth.currentUser ?? 'guest';
    final authNotifier = ref.read(authProvider.notifier);
    final prefs = authNotifier.prefs;
    if (prefs == null) return;

    if (state >= maxBattery) {
      _lastRechargeTime = DateTime.now();
      return;
    }

    final timestampKey = 'dronestep_${user}_battery_timestamp';
    final timestampStr = prefs.getString(timestampKey);
    final now = DateTime.now();

    if (timestampStr != null) {
      final lastTime = DateTime.parse(timestampStr);
      final difference = now.difference(lastTime);
      final chargesGained = difference.inSeconds ~/ secondsPerCharge;
      if (chargesGained > 0) {
        final newLevel = math.min(maxBattery, state + chargesGained);
        state = newLevel;
        final nextTime = lastTime.add(Duration(seconds: chargesGained * secondsPerCharge));
        _lastRechargeTime = newLevel == maxBattery ? now : nextTime;
        _saveToPrefs(prefs, user, newLevel, _lastRechargeTime);
      }
    } else {
      _lastRechargeTime = now;
      prefs.setString(timestampKey, now.toIso8601String());
    }
  }

  Future<bool> spendBattery(int amount) async {
    if (state < amount) return false;
    final auth = ref.read(authProvider);
    final user = auth.currentUser ?? 'guest';
    final authNotifier = ref.read(authProvider.notifier);
    final prefs = authNotifier.prefs;

    final newLevel = state - amount;
    final wasFull = (state == maxBattery);
    state = newLevel;

    if (prefs != null) {
      final timestampKey = 'dronestep_${user}_battery_timestamp';
      final now = DateTime.now();
      DateTime lastTime = now;
      if (newLevel < maxBattery) {
        if (wasFull) {
          lastTime = now;
        } else {
          final lastTimeStr = prefs.getString(timestampKey);
          if (lastTimeStr != null) {
            lastTime = DateTime.parse(lastTimeStr);
          }
        }
      }
      _lastRechargeTime = lastTime;
      await _saveToPrefs(prefs, user, newLevel, lastTime);
    }
    return true;
  }

  Future<void> rewardBattery(int amount) async {
    final auth = ref.read(authProvider);
    final user = auth.currentUser ?? 'guest';
    final authNotifier = ref.read(authProvider.notifier);
    final prefs = authNotifier.prefs;

    final newLevel = math.min(maxBattery, state + amount);
    final reachesFull = (newLevel == maxBattery);
    state = newLevel;

    if (prefs != null) {
      final timestampKey = 'dronestep_${user}_battery_timestamp';
      final now = DateTime.now();
      DateTime lastTime = now;
      if (!reachesFull) {
        final lastTimeStr = prefs.getString(timestampKey);
        if (lastTimeStr != null) {
          lastTime = DateTime.parse(lastTimeStr);
        }
      }
      _lastRechargeTime = lastTime;
      await _saveToPrefs(prefs, user, newLevel, lastTime);
    }
  }

  Future<void> _saveToPrefs(SharedPreferences prefs, String user, int level, DateTime time) async {
    final batteryKey = 'dronestep_${user}_battery';
    final timestampKey = 'dronestep_${user}_battery_timestamp';
    await prefs.setInt(batteryKey, level);
    await prefs.setString(timestampKey, time.toIso8601String());
  }
}

final pilotBatteryProvider = NotifierProvider<PilotBatteryNotifier, int>(
  PilotBatteryNotifier.new,
);

class DiamondNotifier extends Notifier<int> {
  SharedPreferences? _prefs;
  String _user = 'guest';

  @override
  int build() {
    return 200; // default start
  }

  void initDiamonds(SharedPreferences prefs, String user) {
    _prefs = prefs;
    _user = user;
    final key = 'dronestep_${user}_diamonds';
    state = prefs.getInt(key) ?? 200;
  }

  Future<void> addDiamonds(int amount) async {
    state = state + amount;
    if (_prefs != null) {
      final key = 'dronestep_${_user}_diamonds';
      await _prefs!.setInt(key, state);
    }
  }

  Future<bool> spendDiamonds(int amount) async {
    if (state >= amount) {
      state = state - amount;
      if (_prefs != null) {
        final key = 'dronestep_${_user}_diamonds';
        await _prefs!.setInt(key, state);
      }
      return true;
    }
    return false;
  }
}

final diamondProvider = NotifierProvider<DiamondNotifier, int>(
  DiamondNotifier.new,
);

class BoughtHintsNotifier extends Notifier<int> {
  SharedPreferences? _prefs;
  String _user = 'guest';

  @override
  int build() {
    return 0;
  }

  void initBoughtHints(SharedPreferences prefs, String user) {
    _prefs = prefs;
    _user = user;
    final mode = ref.read(gameModeProvider);
    final key = 'dronestep_${user}_bought_hints_${mode.name}';
    state = prefs.getInt(key) ?? 0;
  }

  Future<void> addBoughtHints(int count) async {
    state = state + count;
    if (_prefs != null) {
      final mode = ref.read(gameModeProvider);
      final key = 'dronestep_${_user}_bought_hints_${mode.name}';
      await _prefs!.setInt(key, state);
    }
  }
}

final boughtHintsProvider = NotifierProvider<BoughtHintsNotifier, int>(
  BoughtHintsNotifier.new,
);

class SolverState {
  final int x;
  final int y;
  final int height;
  final Direction direction;
  final bool hasCargo;
  final List<ActionType> path;

  SolverState({
    required this.x,
    required this.y,
    required this.height,
    required this.direction,
    required this.hasCargo,
    required this.path,
  });
}

List<ActionType>? solveLevelBFS(Level level, {SolverState? startState}) {
  final initial = startState ?? SolverState(
    x: level.startX,
    y: level.startY,
    height: 0,
    direction: level.startDirection,
    hasCargo: false,
    path: [],
  );

  if (initial.hasCargo && initial.x == level.targetX && initial.y == level.targetY && initial.height == 0) {
    return [];
  }

  final queue = <SolverState>[initial];
  final visited = <int>{};
  visited.add((initial.x & 0xF) | ((initial.y & 0xF) << 4) | ((initial.height & 0x7) << 8) | ((initial.direction.index & 0x3) << 11) | ((initial.hasCargo ? 1 : 0) << 13));

  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);

    // Goal: delivered cargo to target coordinates and landed (height == 0)
    if (current.hasCargo && current.x == level.targetX && current.y == level.targetY && current.height == 0) {
      return current.path;
    }

    for (final action in ActionType.values) {
      int nextX = current.x;
      int nextY = current.y;
      int nextHeight = current.height;
      Direction nextDirection = current.direction;
      bool nextHasCargo = current.hasCargo;

      bool valid = false;

      switch (action) {
        case ActionType.takeoff:
          if (current.height == 0) {
            nextHeight = 1;
            valid = true;
          }
          break;
        case ActionType.land:
          if (current.height == 1) {
            nextHeight = 0;
            if (current.x == level.boxX && current.y == level.boxY && !current.hasCargo) {
              nextHasCargo = true;
              valid = true;
            } else if (current.x == level.targetX && current.y == level.targetY && current.hasCargo) {
              valid = true;
            }
          }
          break;
        case ActionType.forward:
          if (current.height > 0) {
            final delta = current.direction.delta;
            final tx = current.x + delta.dx.toInt();
            final ty = current.y + delta.dy.toInt();
            if (tx >= 0 && tx < level.gridWidth && ty >= 0 && ty < level.gridHeight) {
              bool hitObstacle = false;
              for (final obs in level.obstacles) {
                if (obs.x == tx && obs.y == ty) {
                  if (current.height <= obs.height) {
                    hitObstacle = true;
                    break;
                  }
                }
              }
              if (!hitObstacle) {
                nextX = tx;
                nextY = ty;
                valid = true;
              }
            }
          }
          break;
        case ActionType.rotateLeft:
          if (current.height > 0) {
            nextDirection = current.direction.rotateLeft();
            valid = true;
          }
          break;
        case ActionType.rotateRight:
          if (current.height > 0) {
            nextDirection = current.direction.rotateRight();
            valid = true;
          }
          break;
        case ActionType.ascend:
          if (current.height > 0 && current.height < 4) {
            nextHeight = current.height + 1;
            valid = true;
          }
          break;
        case ActionType.descend:
          if (current.height > 1) {
            nextHeight = current.height - 1;
            valid = true;
          }
          break;
      }

      if (valid) {
        final stateKey = (nextX & 0xF) | ((nextY & 0xF) << 4) | ((nextHeight & 0x7) << 8) | ((nextDirection.index & 0x3) << 11) | ((nextHasCargo ? 1 : 0) << 13);
        if (!visited.contains(stateKey)) {
          visited.add(stateKey);
          queue.add(SolverState(
            x: nextX,
            y: nextY,
            height: nextHeight,
            direction: nextDirection,
            hasCargo: nextHasCargo,
            path: [...current.path, action],
          ));
        }
      }
    }
  }

  return null;
}

SolverState simulateProgramToState(Level level, List<ProgramBlock> program) {
  final compiled = compileProgram(program);
  
  int x = level.startX;
  int y = level.startY;
  int height = 0;
  Direction direction = level.startDirection;
  bool hasCargo = false;
  int battery = level.initialBattery;
  
  int pc = 0;
  int stepsCount = 0;
  
  bool evaluateSimCondition(ConditionType condition) {
    switch (condition) {
      case ConditionType.hasCargo:
        return hasCargo;
      case ConditionType.notHasCargo:
        return !hasCargo;
      case ConditionType.obstacleAhead:
        final delta = direction.delta;
        final tx = x + delta.dx.toInt();
        final ty = y + delta.dy.toInt();
        if (tx < 0 || tx >= level.gridWidth || ty < 0 || ty >= level.gridHeight) {
          return true;
        }
        return level.obstacles.any((obs) => obs.x == tx && obs.y == ty && height <= obs.height);
      case ConditionType.obstacleNearby:
        for (final dir in Direction.values) {
          final delta = dir.delta;
          final tx = x + delta.dx.toInt();
          final ty = y + delta.dy.toInt();
          if (tx >= 0 && tx < level.gridWidth && ty >= 0 && ty < level.gridHeight) {
            if (level.obstacles.any((obs) => obs.x == tx && obs.y == ty && height <= obs.height)) {
              return true;
            }
          }
        }
        return false;
      case ConditionType.batteryLow:
        return battery < 5;
      case ConditionType.batteryHigh:
        return battery >= 5;
      case ConditionType.altitudeHigh:
        return height > 1;
      case ConditionType.onTarget:
        return x == level.targetX && y == level.targetY;
    }
  }

  while (pc >= 0 && pc < compiled.length && stepsCount < 1000) {
    stepsCount++;
    final inst = compiled[pc];
    if (inst.type == InstructionType.jump) {
      pc = inst.jumpTarget;
      continue;
    } else if (inst.type == InstructionType.jumpIfNot) {
      final conditionVal = evaluateSimCondition(inst.condition!);
      if (!conditionVal) {
        pc = inst.jumpTarget;
      } else {
        pc++;
      }
      continue;
    }

    final action = inst.action!;
    battery--;
    
    switch (action) {
      case ActionType.takeoff:
        if (height == 0) {
          height = 1;
        } else {
          return SolverState(x: x, y: y, height: height, direction: direction, hasCargo: hasCargo, path: []);
        }
        break;
      case ActionType.land:
        if (height == 1) {
          height = 0;
          if (x == level.boxX && y == level.boxY && !hasCargo) {
            hasCargo = true;
          }
        } else {
          return SolverState(x: x, y: y, height: height, direction: direction, hasCargo: hasCargo, path: []);
        }
        break;
      case ActionType.forward:
        if (height > 0) {
          final delta = direction.delta;
          final tx = x + delta.dx.toInt();
          final ty = y + delta.dy.toInt();
          if (tx >= 0 && tx < level.gridWidth && ty >= 0 && ty < level.gridHeight) {
            bool hitObstacle = false;
            for (final obs in level.obstacles) {
              if (obs.x == tx && obs.y == ty && height <= obs.height) {
                hitObstacle = true;
                break;
              }
            }
            if (!hitObstacle) {
              x = tx;
              y = ty;
            } else {
              return SolverState(x: x, y: y, height: height, direction: direction, hasCargo: hasCargo, path: []);
            }
          } else {
            return SolverState(x: x, y: y, height: height, direction: direction, hasCargo: hasCargo, path: []);
          }
        } else {
          return SolverState(x: x, y: y, height: height, direction: direction, hasCargo: hasCargo, path: []);
        }
        break;
      case ActionType.rotateLeft:
        if (height > 0) {
          direction = direction.rotateLeft();
        } else {
          return SolverState(x: x, y: y, height: height, direction: direction, hasCargo: hasCargo, path: []);
        }
        break;
      case ActionType.rotateRight:
        if (height > 0) {
          direction = direction.rotateRight();
        } else {
          return SolverState(x: x, y: y, height: height, direction: direction, hasCargo: hasCargo, path: []);
        }
        break;
      case ActionType.ascend:
        if (height > 0 && height < 4) {
          height++;
        } else {
          return SolverState(x: x, y: y, height: height, direction: direction, hasCargo: hasCargo, path: []);
        }
        break;
      case ActionType.descend:
        if (height > 1) {
          height--;
        } else {
          return SolverState(x: x, y: y, height: height, direction: direction, hasCargo: hasCargo, path: []);
        }
        break;
    }
    pc++;
  }

  return SolverState(
    x: x,
    y: y,
    height: height,
    direction: direction,
    hasCargo: hasCargo,
    path: [],
  );
}

class ShowHintGuidanceNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool val) => state = val;
}

final showHintGuidanceProvider = NotifierProvider<ShowHintGuidanceNotifier, bool>(
  ShowHintGuidanceNotifier.new,
);

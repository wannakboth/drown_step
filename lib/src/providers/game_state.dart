import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    );

    _scheduleNextStep();
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

    final int baseDelay = isCargoPickup ? 1800 : 1000;
    final delayMs = (baseDelay / state.speedMultiplier).round();
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
    GameStatus nextStatus = GameStatus.running;

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
  Level build() => Level.predefinedLevels.first;

  void setLevel(Level level) {
    state = level;
  }
}

final currentLevelProvider = NotifierProvider<CurrentLevelNotifier, Level>(
  CurrentLevelNotifier.new,
);

final gameStateProvider = NotifierProvider<GameStateNotifier, DroneGameState>(
  GameStateNotifier.new,
);

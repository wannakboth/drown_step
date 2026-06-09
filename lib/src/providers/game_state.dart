import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/drone_command.dart';
import '../models/level.dart';

enum GameStatus {
  idle,
  running,
  paused,
  crashed,
  success,
}

class DroneGameState {
  final Level level;
  final List<DroneCommand> commandQueue;
  final GameStatus status;
  final int currentCommandIndex;
  
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
    required this.commandQueue,
    required this.status,
    required this.currentCommandIndex,
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
    List<DroneCommand>? commandQueue,
    GameStatus? status,
    int? currentCommandIndex,
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
      commandQueue: commandQueue ?? this.commandQueue,
      status: status ?? this.status,
      currentCommandIndex: currentCommandIndex ?? this.currentCommandIndex,
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

  factory DroneGameState.initial(Level level) {
    return DroneGameState(
      level: level,
      commandQueue: [],
      status: GameStatus.idle,
      currentCommandIndex: -1,
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

  void addCommand(CommandType type) {
    if (state.status == GameStatus.running) return;
    
    final newQueue = List<DroneCommand>.from(state.commandQueue)..add(DroneCommand(type));
    state = state.copyWith(commandQueue: newQueue);
  }

  void removeCommand(int index) {
    if (state.status == GameStatus.running) return;
    
    final newQueue = List<DroneCommand>.from(state.commandQueue)..removeAt(index);
    state = state.copyWith(commandQueue: newQueue);
  }

  void clearQueue() {
    if (state.status == GameStatus.running) return;
    state = state.copyWith(commandQueue: []);
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (state.status == GameStatus.running) return;
    
    final newQueue = List<DroneCommand>.from(state.commandQueue);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = newQueue.removeAt(oldIndex);
    newQueue.insert(newIndex, item);
    state = state.copyWith(commandQueue: newQueue);
  }

  void resetSimulation() {
    _timer?.cancel();
    state = DroneGameState(
      level: state.level,
      commandQueue: state.commandQueue,
      status: GameStatus.idle,
      currentCommandIndex: -1,
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
    if (state.commandQueue.isEmpty) {
      state = state.copyWith(
        status: GameStatus.crashed,
        message: "Command queue is empty! Add commands to start.",
      );
      return;
    }

    if (state.status == GameStatus.crashed || state.status == GameStatus.success) {
      resetSimulation();
    }

    state = state.copyWith(status: GameStatus.running);
    _scheduleNextStep();
  }

  void pauseSimulation() {
    _timer?.cancel();
    state = state.copyWith(status: GameStatus.paused);
  }

  void _scheduleNextStep() {
    _timer?.cancel();
    
    bool isCargoPickup = false;
    if (state.currentCommandIndex >= 0 && state.currentCommandIndex < state.commandQueue.length) {
      final cmd = state.commandQueue[state.currentCommandIndex];
      if (cmd.type == CommandType.land &&
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
    final nextIndex = state.currentCommandIndex + 1;

    // Out of commands check
    if (nextIndex >= state.commandQueue.length) {
      _timer?.cancel();
      if (state.droneHeight == 0 && state.droneX == state.level.targetX && state.droneY == state.level.targetY) {
        if (state.hasCargo) {
          state = state.copyWith(status: GameStatus.success, message: "Mission Accomplished! Cargo delivered.");
        } else {
          state = state.copyWith(
            status: GameStatus.crashed,
            message: "Landed on target, but empty! You forgot to pick up the cargo at (${state.level.boxX}, ${state.level.boxY}).",
          );
        }
      } else if (state.droneHeight > 0) {
        state = state.copyWith(
          status: GameStatus.crashed,
          message: "Out of commands! The drone is hovering in mid-air.",
        );
      } else {
        state = state.copyWith(
          status: GameStatus.crashed,
          message: "Out of commands! Drone landed at the wrong coordinates.",
        );
      }
      return;
    }

    final command = state.commandQueue[nextIndex];
    int nextX = state.droneX;
    int nextY = state.droneY;
    int nextHeight = state.droneHeight;
    Direction nextDir = state.droneDirection;
    int nextBattery = state.battery - 1;
    bool nextHasCargo = state.hasCargo;
    String? crashMsg;
    GameStatus nextStatus = GameStatus.running;

    switch (command.type) {
      case CommandType.takeoff:
        if (state.droneHeight > 0) {
          nextStatus = GameStatus.crashed;
          crashMsg = "TAKEOFF FAIL: Drone is already flying.";
        } else {
          nextHeight = 1;
        }
        break;

      case CommandType.land:
        if (state.droneHeight == 0) {
          nextStatus = GameStatus.crashed;
          crashMsg = "LAND FAIL: Drone is already on the ground.";
        } else if (state.droneHeight > 1) {
          nextStatus = GameStatus.crashed;
          crashMsg = "LAND FAIL: Too high! Descend to altitude 1 before landing.";
        } else {
          nextHeight = 0;
          
          // Landing logic for Cargo vs Target
          if (nextX == state.level.boxX && nextY == state.level.boxY) {
            if (!state.hasCargo) {
              nextHasCargo = true;
              crashMsg = "CARGO ACQUIRED! Proceed to the target pad.";
            } else {
              // Already has cargo, landing on box coordinates again is allowed but redundant
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

      case CommandType.forward:
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

      case CommandType.rotateLeft:
        if (state.droneHeight == 0) {
          nextStatus = GameStatus.crashed;
          crashMsg = "FAIL: Cannot rotate while landed.";
        } else {
          nextDir = state.droneDirection.rotateLeft();
        }
        break;

      case CommandType.rotateRight:
        if (state.droneHeight == 0) {
          nextStatus = GameStatus.crashed;
          crashMsg = "FAIL: Cannot rotate while landed.";
        } else {
          nextDir = state.droneDirection.rotateRight();
        }
        break;

      case CommandType.ascend:
        if (state.droneHeight == 0) {
          nextStatus = GameStatus.crashed;
          crashMsg = "FAIL: Cannot ascend while landed. Take off first.";
        } else {
          nextHeight += 1;
        }
        break;

      case CommandType.descend:
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

    // Energy cells logic
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
      currentCommandIndex: nextIndex,
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

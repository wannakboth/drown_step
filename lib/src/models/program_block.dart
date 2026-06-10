import 'package:flutter/material.dart';

enum BlockType {
  action,
  repeat,
  whileLoop,
  ifElse,
}

enum ActionType {
  takeoff,
  land,
  forward,
  rotateLeft,
  rotateRight,
  ascend,
  descend,
}

enum ConditionType {
  hasCargo,
  notHasCargo,
  obstacleAhead,
  obstacleNearby,
  batteryLow,
  batteryHigh,
  altitudeHigh,
  onTarget,
}

extension ActionTypeExt on ActionType {
  String get label {
    switch (this) {
      case ActionType.takeoff:
        return 'TAKEOFF';
      case ActionType.land:
        return 'LAND';
      case ActionType.forward:
        return 'MOVE FORWARD';
      case ActionType.rotateLeft:
        return 'TURN LEFT';
      case ActionType.rotateRight:
        return 'TURN RIGHT';
      case ActionType.ascend:
        return 'ASCEND';
      case ActionType.descend:
        return 'DESCEND';
    }
  }

  String get shortLabel {
    switch (this) {
      case ActionType.takeoff:
        return 'T-OFF';
      case ActionType.land:
        return 'LAND';
      case ActionType.forward:
        return 'FWD';
      case ActionType.rotateLeft:
        return 'L-ROT';
      case ActionType.rotateRight:
        return 'R-ROT';
      case ActionType.ascend:
        return 'ASC';
      case ActionType.descend:
        return 'DSC';
    }
  }

  IconData get icon {
    switch (this) {
      case ActionType.takeoff:
        return Icons.flight_takeoff;
      case ActionType.land:
        return Icons.flight_land;
      case ActionType.forward:
        return Icons.arrow_upward;
      case ActionType.rotateLeft:
        return Icons.rotate_left;
      case ActionType.rotateRight:
        return Icons.rotate_right;
      case ActionType.ascend:
        return Icons.keyboard_double_arrow_up;
      case ActionType.descend:
        return Icons.keyboard_double_arrow_down;
    }
  }
}

extension ConditionTypeExt on ConditionType {
  String get label {
    switch (this) {
      case ConditionType.hasCargo:
        return 'HAS CARGO';
      case ConditionType.notHasCargo:
        return 'NOT HAS CARGO';
      case ConditionType.obstacleAhead:
        return 'OBSTACLE AHEAD';
      case ConditionType.obstacleNearby:
        return 'OBSTACLE NEARBY';
      case ConditionType.batteryLow:
        return 'BATTERY LOW (< 5)';
      case ConditionType.batteryHigh:
        return 'BATTERY OK (>= 5)';
      case ConditionType.altitudeHigh:
        return 'ALTITUDE HIGH (> 1)';
      case ConditionType.onTarget:
        return 'ON TARGET PAD';
    }
  }
}

class ProgramBlock {
  final String id;
  final BlockType type;
  
  // Action properties
  final ActionType? action;
  
  // Repeat properties
  final int repeatCount;
  
  // Conditional properties
  final ConditionType condition;
  
  // Nested child blocks
  final List<ProgramBlock> body;
  
  // Nested else child blocks
  final List<ProgramBlock> elseBody;

  ProgramBlock({
    required this.id,
    required this.type,
    this.action,
    this.repeatCount = 2,
    this.condition = ConditionType.hasCargo,
    List<ProgramBlock>? body,
    List<ProgramBlock>? elseBody,
  })  : body = body ?? [],
        elseBody = elseBody ?? [];

  ProgramBlock copyWith({
    String? id,
    BlockType? type,
    ActionType? action,
    int? repeatCount,
    ConditionType? condition,
    List<ProgramBlock>? body,
    List<ProgramBlock>? elseBody,
  }) {
    return ProgramBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      action: action ?? this.action,
      repeatCount: repeatCount ?? this.repeatCount,
      condition: condition ?? this.condition,
      body: body ?? List.from(this.body),
      elseBody: elseBody ?? List.from(this.elseBody),
    );
  }

  // Deep clone a block list
  static List<ProgramBlock> cloneList(List<ProgramBlock> original) {
    return original
        .map((block) => block.copyWith(
              body: cloneList(block.body),
              elseBody: cloneList(block.elseBody),
            ))
        .toList();
  }
}

enum InstructionType {
  executeAction,
  jump,
  jumpIfNot,
}

class VMInstruction {
  final InstructionType type;
  final ActionType? action;
  final ConditionType? condition;
  final int jumpTarget;
  final String blockId;

  VMInstruction({
    required this.type,
    this.action,
    this.condition,
    this.jumpTarget = -1,
    required this.blockId,
  });

  @override
  String toString() {
    return 'VMInstruction(type: $type, action: $action, condition: $condition, target: $jumpTarget, blockId: $blockId)';
  }
}

List<VMInstruction> compileProgram(List<ProgramBlock> program) {
  final instructions = <VMInstruction>[];

  void compileBlock(ProgramBlock block) {
    switch (block.type) {
      case BlockType.action:
        if (block.action != null) {
          instructions.add(VMInstruction(
            type: InstructionType.executeAction,
            action: block.action,
            blockId: block.id,
          ));
        }
        break;

      case BlockType.repeat:
        for (int i = 0; i < block.repeatCount; i++) {
          for (final child in block.body) {
            compileBlock(child);
          }
        }
        break;

      case BlockType.whileLoop:
        final startIdx = instructions.length;
        
        final jumpIfFalseIdx = instructions.length;
        instructions.add(VMInstruction(
          type: InstructionType.jumpIfNot,
          condition: block.condition,
          blockId: block.id,
        ));

        for (final child in block.body) {
          compileBlock(child);
        }

        instructions.add(VMInstruction(
          type: InstructionType.jump,
          jumpTarget: startIdx,
          blockId: block.id,
        ));

        final endIdx = instructions.length;
        instructions[jumpIfFalseIdx] = VMInstruction(
          type: InstructionType.jumpIfNot,
          condition: block.condition,
          jumpTarget: endIdx,
          blockId: block.id,
        );
        break;

      case BlockType.ifElse:
        final jumpIfFalseIdx = instructions.length;
        instructions.add(VMInstruction(
          type: InstructionType.jumpIfNot,
          condition: block.condition,
          blockId: block.id,
        ));

        for (final child in block.body) {
          compileBlock(child);
        }

        final jumpToEndIdx = instructions.length;
        instructions.add(VMInstruction(
          type: InstructionType.jump,
          blockId: block.id,
        ));

        final elseStartIdx = instructions.length;
        instructions[jumpIfFalseIdx] = VMInstruction(
          type: InstructionType.jumpIfNot,
          condition: block.condition,
          jumpTarget: elseStartIdx,
          blockId: block.id,
        );

        for (final child in block.elseBody) {
          compileBlock(child);
        }

        final endIdx = instructions.length;
        instructions[jumpToEndIdx] = VMInstruction(
          type: InstructionType.jump,
          jumpTarget: endIdx,
          blockId: block.id,
        );
        break;
    }
  }

  for (final block in program) {
    compileBlock(block);
  }

  return instructions;
}

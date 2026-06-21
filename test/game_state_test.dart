import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drone_step/src/models/level.dart';
import 'package:drone_step/src/models/program_block.dart';
import 'package:drone_step/src/providers/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Program Compiler Tests', () {
    test('Action blocks compile to direct VMInstructions', () {
      final program = [
        ProgramBlock(id: '1', type: BlockType.action, action: ActionType.takeoff),
        ProgramBlock(id: '2', type: BlockType.action, action: ActionType.forward),
      ];

      final instructions = compileProgram(program);

      expect(instructions.length, 2);
      expect(instructions[0].type, InstructionType.executeAction);
      expect(instructions[0].action, ActionType.takeoff);
      expect(instructions[1].action, ActionType.forward);
    });

    test('Repeat block compiles to unrolled child instructions', () {
      final program = [
        ProgramBlock(
          id: 'repeat_1',
          type: BlockType.repeat,
          repeatCount: 3,
          body: [
            ProgramBlock(id: 'act_1', type: BlockType.action, action: ActionType.forward),
          ],
        ),
      ];

      final instructions = compileProgram(program);

      // Should repeat 3 times
      expect(instructions.length, 3);
      for (int i = 0; i < 3; i++) {
        expect(instructions[i].type, InstructionType.executeAction);
        expect(instructions[i].action, ActionType.forward);
        expect(instructions[i].loopBlockId, 'repeat_1');
        expect(instructions[i].loopIteration, i + 1);
        expect(instructions[i].loopTotal, 3);
      }
    });

    test('While loop compiles to jumpIfNot and jump structure', () {
      final program = [
        ProgramBlock(
          id: 'while_1',
          type: BlockType.whileLoop,
          condition: ConditionType.notHasCargo,
          body: [
            ProgramBlock(id: 'act_1', type: BlockType.action, action: ActionType.forward),
          ],
        ),
      ];

      final instructions = compileProgram(program);

      // Structure:
      // 0: jumpIfNot to 3 (end) if notHasCargo is false
      // 1: executeAction forward
      // 2: jump to 0
      // 3: (end)
      expect(instructions.length, 3);
      expect(instructions[0].type, InstructionType.jumpIfNot);
      expect(instructions[0].condition, ConditionType.notHasCargo);
      expect(instructions[0].jumpTarget, 3);

      expect(instructions[1].type, InstructionType.executeAction);
      expect(instructions[1].action, ActionType.forward);

      expect(instructions[2].type, InstructionType.jump);
      expect(instructions[2].jumpTarget, 0);
    });

    test('IfElse compiles to conditional jump and target alignment', () {
      final program = [
        ProgramBlock(
          id: 'ifelse_1',
          type: BlockType.ifElse,
          condition: ConditionType.obstacleAhead,
          body: [
            ProgramBlock(id: 'act_1', type: BlockType.action, action: ActionType.rotateLeft),
          ],
          elseBody: [
            ProgramBlock(id: 'act_2', type: BlockType.action, action: ActionType.forward),
          ],
        ),
      ];

      final instructions = compileProgram(program);

      // Structure:
      // 0: jumpIfNot to 3 (elseStart) if obstacleAhead is false
      // 1: executeAction rotateLeft
      // 2: jump to 4 (end)
      // 3: executeAction forward
      // 4: (end)
      expect(instructions.length, 4);
      expect(instructions[0].type, InstructionType.jumpIfNot);
      expect(instructions[0].jumpTarget, 3);

      expect(instructions[1].action, ActionType.rotateLeft);

      expect(instructions[2].type, InstructionType.jump);
      expect(instructions[2].jumpTarget, 4);

      expect(instructions[3].action, ActionType.forward);
    });
  });

  group('GameStateNotifier AST Mutators Tests', () {
    late ProviderContainer container;
    
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();

      container.read(authProvider);
      while (container.read(authProvider.notifier).prefs == null) {
        await Future.delayed(const Duration(milliseconds: 5));
      }
    });

    tearDown(() {
      container.dispose();
    });

    test('Adding and removing blocks in AST works correctly', () {
      final notifier = container.read(gameStateProvider.notifier);

      expect(container.read(gameStateProvider).program.length, 0);

      final takeoff = ProgramBlock(id: 't1', type: BlockType.action, action: ActionType.takeoff);
      notifier.addBlock(takeoff);

      expect(container.read(gameStateProvider).program.length, 1);
      expect(container.read(gameStateProvider).program[0].id, 't1');

      notifier.removeBlock('t1');
      expect(container.read(gameStateProvider).program.length, 0);
    });

    test('Nesting blocks inside loops and measuring depth', () {
      final notifier = container.read(gameStateProvider.notifier);

      final loop = ProgramBlock(id: 'loop1', type: BlockType.repeat);
      notifier.addBlock(loop);

      final action = ProgramBlock(id: 'act1', type: BlockType.action, action: ActionType.forward);
      notifier.addBlock(action, parentId: 'loop1');

      final state = container.read(gameStateProvider);
      expect(state.program.length, 1);
      expect(state.program[0].body.length, 1);
      expect(state.program[0].body[0].id, 'act1');

      expect(notifier.getBlockNestingDepth('loop1'), 0);
      expect(notifier.getBlockNestingDepth('act1'), 1);
    });
  });

  group('Simulation Execution Tests', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();

      container.read(authProvider);
      while (container.read(authProvider.notifier).prefs == null) {
        await Future.delayed(const Duration(milliseconds: 5));
      }
    });

    tearDown(() {
      container.dispose();
    });

    test('Takeoff increases altitude and spends battery', () async {
      final level = Level.predefinedLevels[0]; // N1
      container.read(currentLevelProvider.notifier).setLevel(level);

      final notifier = container.read(gameStateProvider.notifier);
      
      notifier.addBlock(ProgramBlock(id: 't', type: BlockType.action, action: ActionType.takeoff));
      notifier.runSimulation();
      notifier.pauseSimulation();

      expect(container.read(gameStateProvider).droneHeight, 0);
      
      notifier.executeNextStep();
      
      final state = container.read(gameStateProvider);
      expect(state.droneHeight, 1);
      expect(state.battery, level.initialBattery - 1); // takeoff drains 1 battery
    });

    test('Move forward changes drone coordinates and spends battery', () async {
      final level = Level.predefinedLevels[0]; // N1 starts at (0, 4) heading East
      container.read(currentLevelProvider.notifier).setLevel(level);

      final notifier = container.read(gameStateProvider.notifier);
      
      notifier.addBlock(ProgramBlock(id: 't', type: BlockType.action, action: ActionType.takeoff));
      notifier.addBlock(ProgramBlock(id: 'f', type: BlockType.action, action: ActionType.forward));
      notifier.runSimulation();
      notifier.pauseSimulation();

      // Lift off
      notifier.executeNextStep();
      expect(container.read(gameStateProvider).droneHeight, 1);

      // Move forward
      notifier.executeNextStep();
      final state = container.read(gameStateProvider);
      expect(state.droneX, 1); // moved from 0 to 1
      expect(state.droneY, 4);
      expect(state.battery, level.initialBattery - 2); // 1 (takeoff) + 1 (forward)
    });

    test('Landing on cargo box acquires cargo', () async {
      final level = Level.predefinedLevels[0]; // N1 cargo at (2, 4)
      container.read(currentLevelProvider.notifier).setLevel(level);

      final notifier = container.read(gameStateProvider.notifier);
      
      notifier.addBlock(ProgramBlock(id: 't1', type: BlockType.action, action: ActionType.takeoff));
      notifier.addBlock(ProgramBlock(id: 'f1', type: BlockType.action, action: ActionType.forward));
      notifier.addBlock(ProgramBlock(id: 'f2', type: BlockType.action, action: ActionType.forward));
      notifier.addBlock(ProgramBlock(id: 'l1', type: BlockType.action, action: ActionType.land));
      notifier.runSimulation();
      notifier.pauseSimulation();

      // Run takeoff, move, move, land
      notifier.executeNextStep(); // takeoff
      notifier.executeNextStep(); // move 1
      notifier.executeNextStep(); // move 2
      notifier.executeNextStep(); // land on box

      final state = container.read(gameStateProvider);
      expect(state.droneX, 2);
      expect(state.droneY, 4);
      expect(state.droneHeight, 0);
      expect(state.hasCargo, true);
    });
  });
}

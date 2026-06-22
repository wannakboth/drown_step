import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drone_step/src/models/level.dart';
import 'package:drone_step/src/models/program_block.dart';
import 'package:drone_step/src/providers/game_state.dart';
import 'package:drone_step/src/providers/audio_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sandbox Level Serialization Tests', () {
    test('Obstacle toJson and fromJson', () {
      const obstacle = Obstacle(x: 2, y: 3, height: 1);
      final json = obstacle.toJson();
      expect(json['x'], 2);
      expect(json['y'], 3);
      expect(json['height'], 1);

      final deserialized = Obstacle.fromJson(json);
      expect(deserialized.x, 2);
      expect(deserialized.y, 3);
      expect(deserialized.height, 1);
    });

    test('EnergyCell toJson and fromJson', () {
      const cell = EnergyCell(x: 4, y: 1, height: 2, charge: 10);
      final json = cell.toJson();
      expect(json['x'], 4);
      expect(json['y'], 1);
      expect(json['height'], 2);
      expect(json['charge'], 10);

      final deserialized = EnergyCell.fromJson(json);
      expect(deserialized.x, 4);
      expect(deserialized.y, 1);
      expect(deserialized.height, 2);
      expect(deserialized.charge, 10);
    });

    test('Level toJson and fromJson', () {
      const level = Level(
        id: 'sandbox_test_1',
        title: 'Sandbox Test Mission',
        description: 'Test sandbox features',
        hint: 'Use takeoff',
        gridWidth: 6,
        gridHeight: 6,
        startX: 1,
        startY: 2,
        startDirection: Direction.east,
        boxX: 3,
        boxY: 4,
        targetX: 5,
        targetY: 5,
        initialBattery: 35,
        obstacles: [Obstacle(x: 2, y: 2, height: 1)],
        energyCells: [EnergyCell(x: 0, y: 1, height: 0, charge: 5)],
        star3Target: 8,
      );

      final json = level.toJson();
      expect(json['id'], 'sandbox_test_1');
      expect(json['title'], 'Sandbox Test Mission');
      expect(json['gridWidth'], 6);
      expect(json['startDirection'], Direction.east.index);
      expect(json['obstacles'].length, 1);
      expect(json['energyCells'].length, 1);

      final deserialized = Level.fromJson(json);
      expect(deserialized.id, 'sandbox_test_1');
      expect(deserialized.title, 'Sandbox Test Mission');
      expect(deserialized.description, 'Test sandbox features');
      expect(deserialized.hint, 'Use takeoff');
      expect(deserialized.gridWidth, 6);
      expect(deserialized.gridHeight, 6);
      expect(deserialized.startX, 1);
      expect(deserialized.startY, 2);
      expect(deserialized.startDirection, Direction.east);
      expect(deserialized.boxX, 3);
      expect(deserialized.boxY, 4);
      expect(deserialized.targetX, 5);
      expect(deserialized.targetY, 5);
      expect(deserialized.initialBattery, 35);
      expect(deserialized.obstacles.length, 1);
      expect(deserialized.obstacles[0].x, 2);
      expect(deserialized.obstacles[0].height, 1);
      expect(deserialized.energyCells.length, 1);
      expect(deserialized.energyCells[0].charge, 5);
      expect(deserialized.star3Target, 8);
    });
  });

  group('SandboxLevelsNotifier Tests', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      // Wait for notifier initialization (we can read the notifier and trigger build)
      container.read(sandboxLevelsProvider);
      await Future.delayed(const Duration(milliseconds: 10));
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial levels list is empty', () {
      final list = container.read(sandboxLevelsProvider);
      expect(list, isEmpty);
    });

    test('Save and delete custom sandbox level works and persists', () async {
      final notifier = container.read(sandboxLevelsProvider.notifier);
      const level = Level(
        id: 'user_lvl_1',
        title: 'Custom Level 1',
        description: 'First custom level',
        gridWidth: 5,
        gridHeight: 5,
        startX: 0,
        startY: 0,
        startDirection: Direction.north,
        boxX: 1,
        boxY: 1,
        targetX: 2,
        targetY: 2,
        initialBattery: 20,
        obstacles: [],
        energyCells: [],
        star3Target: 5,
      );

      await notifier.saveLevel(level);

      var list = container.read(sandboxLevelsProvider);
      expect(list.length, 1);
      expect(list[0].id, 'user_lvl_1');
      expect(list[0].title, 'Custom Level 1');

      // Edit level
      const updatedLevel = Level(
        id: 'user_lvl_1',
        title: 'Updated Custom Level 1',
        description: 'First custom level',
        gridWidth: 5,
        gridHeight: 5,
        startX: 0,
        startY: 0,
        startDirection: Direction.north,
        boxX: 1,
        boxY: 1,
        targetX: 2,
        targetY: 2,
        initialBattery: 20,
        obstacles: [],
        energyCells: [],
        star3Target: 5,
      );

      await notifier.saveLevel(updatedLevel);
      list = container.read(sandboxLevelsProvider);
      expect(list.length, 1);
      expect(list[0].title, 'Updated Custom Level 1');

      // Delete level
      await notifier.deleteLevel('user_lvl_1');
      list = container.read(sandboxLevelsProvider);
      expect(list, isEmpty);
    });
  });

  group('Step-by-Step Mode execution Tests', () {
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

    test('Start step mode compiles and pauses execution', () {
      final notifier = container.read(gameStateProvider.notifier);
      final level = Level.predefinedLevels[0];
      container.read(currentLevelProvider.notifier).setLevel(level);

      // Add a block to program
      notifier.addBlock(ProgramBlock(id: 't', type: BlockType.action, action: ActionType.takeoff));

      // Before step mode
      var state = container.read(gameStateProvider);
      expect(state.isStepMode, false);
      expect(state.status, GameStatus.idle);

      // Start Step Mode
      notifier.startStepMode();

      state = container.read(gameStateProvider);
      expect(state.isStepMode, true);
      expect(state.status, GameStatus.paused);
      expect(state.vmInstructions.length, 1);
      expect(state.pc, -1);
    });

    test('Step simulation runs exactly one instruction and stays paused', () {
      final notifier = container.read(gameStateProvider.notifier);
      final level = Level.predefinedLevels[0];
      container.read(currentLevelProvider.notifier).setLevel(level);

      notifier.addBlock(ProgramBlock(id: 't', type: BlockType.action, action: ActionType.takeoff));
      notifier.addBlock(ProgramBlock(id: 'f', type: BlockType.action, action: ActionType.forward));

      // First step execution
      notifier.stepSimulation();

      var state = container.read(gameStateProvider);
      expect(state.isStepMode, true);
      expect(state.status, GameStatus.paused);
      expect(state.pc, 0);
      expect(state.droneHeight, 1); // takeoff executed

      // Second step execution
      notifier.stepSimulation();

      state = container.read(gameStateProvider);
      expect(state.isStepMode, true);
      expect(state.status, GameStatus.paused);
      expect(state.pc, 1);
      expect(state.droneX, 1); // forward executed
    });

    test('Run simulation switches out of step mode and continues execution', () async {
      final notifier = container.read(gameStateProvider.notifier);
      final level = Level.predefinedLevels[0];
      container.read(currentLevelProvider.notifier).setLevel(level);

      notifier.addBlock(ProgramBlock(id: 't', type: BlockType.action, action: ActionType.takeoff));
      notifier.addBlock(ProgramBlock(id: 'f', type: BlockType.action, action: ActionType.forward));

      // Start in step mode and step once
      notifier.stepSimulation();
      expect(container.read(gameStateProvider).isStepMode, true);

      // Resume simulation (auto execution)
      notifier.runSimulation();

      final state = container.read(gameStateProvider);
      expect(state.isStepMode, false);
      expect(state.status, GameStatus.running);
    });
  });

  group('Audio Providers Tests', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      container.read(soundOnProvider);
      container.read(bgmOnProvider);
      container.read(humOnProvider);
      container.read(sfxVolumeProvider);
      container.read(bgmVolumeProvider);
      container.read(humVolumeProvider);
      await Future.delayed(const Duration(milliseconds: 10));
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial audio settings volume defaults', () {
      expect(container.read(soundOnProvider), true);
      expect(container.read(bgmOnProvider), true);
      expect(container.read(humOnProvider), true);
      expect(container.read(sfxVolumeProvider), 0.7);
      expect(container.read(bgmVolumeProvider), 0.4);
      expect(container.read(humVolumeProvider), 0.3);
    });

    test('Toggling sound/bgm/hum and setting volume works', () {
      container.read(soundOnProvider.notifier).toggle();
      expect(container.read(soundOnProvider), false);

      container.read(bgmOnProvider.notifier).toggle();
      expect(container.read(bgmOnProvider), false);

      container.read(humOnProvider.notifier).toggle();
      expect(container.read(humOnProvider), false);

      container.read(sfxVolumeProvider.notifier).setVolume(0.9);
      expect(container.read(sfxVolumeProvider), 0.9);

      container.read(bgmVolumeProvider.notifier).setVolume(0.1);
      expect(container.read(bgmVolumeProvider), 0.1);

      container.read(humVolumeProvider.notifier).setVolume(0.5);
      expect(container.read(humVolumeProvider), 0.5);
    });
  });
}

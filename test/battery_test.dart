import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drone_step/src/providers/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PilotBatteryNotifier Tests', () {
    late ProviderContainer container;
    late SharedPreferences prefs;
    const user = 'guest';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer();
      
      // Read authProvider to trigger async build and wait for it to load
      container.read(authProvider);
      while (container.read(authProvider.notifier).prefs == null) {
        await Future.delayed(const Duration(milliseconds: 5));
      }
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial battery defaults to maxBattery (50)', () {
      final battery = container.read(pilotBatteryProvider);
      expect(battery, 50);
    });

    test('initBattery loads and applies correct stored battery level', () async {
      final batteryNotifier = container.read(pilotBatteryProvider.notifier);
      
      // Save battery value to preferences
      await prefs.setInt('dronestep_${user}_battery', 40);
      final nowStr = DateTime.now().toIso8601String();
      await prefs.setString('dronestep_${user}_battery_timestamp', nowStr);

      await batteryNotifier.initBattery(prefs, user);

      final state = container.read(pilotBatteryProvider);
      expect(state, 40);
    });

    test('initBattery applies passive recharging based on elapsed time since timestamp', () async {
      final batteryNotifier = container.read(pilotBatteryProvider.notifier);
      
      // Battery was 35, 125 seconds ago (should gain 2 charges: 125 ~/ 60 = 2)
      await prefs.setInt('dronestep_${user}_battery', 35);
      final pastTime = DateTime.now().subtract(const Duration(seconds: 125));
      await prefs.setString('dronestep_${user}_battery_timestamp', pastTime.toIso8601String());

      await batteryNotifier.initBattery(prefs, user);

      final state = container.read(pilotBatteryProvider);
      expect(state, 37); // 35 + 2 = 37

      // Recharge time should be adjusted to last calculated charge event time
      expect(batteryNotifier.lastRechargeTime.isAfter(pastTime), true);
    });

    test('spendBattery reduces battery level and persists state', () async {
      final batteryNotifier = container.read(pilotBatteryProvider.notifier);
      
      await prefs.setInt('dronestep_${user}_battery', 45);
      await prefs.setString('dronestep_${user}_battery_timestamp', DateTime.now().toIso8601String());
      await batteryNotifier.initBattery(prefs, user);

      final success = await batteryNotifier.spendBattery(5);
      expect(success, true);
      expect(container.read(pilotBatteryProvider), 40);

      // Verify persistence
      expect(prefs.getInt('dronestep_${user}_battery'), 40);
    });

    test('spendBattery fails if insufficient battery', () async {
      final batteryNotifier = container.read(pilotBatteryProvider.notifier);
      
      await prefs.setInt('dronestep_${user}_battery', 5);
      await prefs.setString('dronestep_${user}_battery_timestamp', DateTime.now().toIso8601String());
      await batteryNotifier.initBattery(prefs, user);

      final success = await batteryNotifier.spendBattery(10);
      expect(success, false);
      expect(container.read(pilotBatteryProvider), 5);
    });

    test('rewardBattery increases battery level up to maxBattery', () async {
      final batteryNotifier = container.read(pilotBatteryProvider.notifier);
      
      await prefs.setInt('dronestep_${user}_battery', 42);
      await prefs.setString('dronestep_${user}_battery_timestamp', DateTime.now().toIso8601String());
      await batteryNotifier.initBattery(prefs, user);

      await batteryNotifier.rewardBattery(5);
      expect(container.read(pilotBatteryProvider), 47);

      await batteryNotifier.rewardBattery(10);
      expect(container.read(pilotBatteryProvider), 50); // capped at maxBattery
    });
  });
}

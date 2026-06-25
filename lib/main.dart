import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'src/views/game_screen.dart';
import 'src/views/home_screen.dart';
import 'src/views/sandbox_editor.dart';
import 'src/theme/colors.dart';
import 'src/providers/game_state.dart';

import 'src/providers/audio_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(
    const ProviderScope(
      child: MainApp(),
    ),
  );
}

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> {
  @override
  void initState() {
    super.initState();
    // Initialize audio controller as soon as the app starts to register lifecycle observer
    ref.read(audioControllerProvider);
  }

  @override
  Widget build(BuildContext context) {
    final activeScreen = ref.watch(appScreenProvider);

    return MaterialApp(
      title: 'DroneStep',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: CyberTheme.darkBg,
        primaryColor: CyberTheme.neonCyan,
      ),
      home: activeScreen == AppScreen.home
          ? const HomeScreen()
          : activeScreen == AppScreen.sandboxEditor
              ? const SandboxEditorScreen()
              : const GameScreen(),
    );
  }
}


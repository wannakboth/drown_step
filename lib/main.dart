import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/views/game_screen.dart';
import 'src/views/home_screen.dart';
import 'src/views/sandbox_editor.dart';
import 'src/theme/colors.dart';
import 'src/providers/game_state.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MainApp(),
    ),
  );
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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


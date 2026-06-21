import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioController {
  final Ref _ref;
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _flyingPlayer = AudioPlayer();
  bool _isFlyingActive = false;

  AudioController(this._ref);

  void playClick() {
    final isSoundOn = _ref.read(soundOnProvider);
    if (!isSoundOn) return;
    _sfxPlayer.stop().then((_) {
      _sfxPlayer.play(AssetSource('audio/click.wav'));
    });
  }

  void playPickup() {
    final isSoundOn = _ref.read(soundOnProvider);
    if (!isSoundOn) return;
    _sfxPlayer.stop().then((_) {
      _sfxPlayer.play(AssetSource('audio/pickup.wav'));
    });
  }

  void playCrash() {
    final isSoundOn = _ref.read(soundOnProvider);
    if (!isSoundOn) return;
    _sfxPlayer.stop().then((_) {
      _sfxPlayer.play(AssetSource('audio/crash.wav'));
    });
  }

  void startFlyingLoop() {
    final isSoundOn = _ref.read(soundOnProvider);
    if (!isSoundOn) return;
    if (_isFlyingActive) return;
    _isFlyingActive = true;
    _flyingPlayer.setVolume(0.15);
    _flyingPlayer.setReleaseMode(ReleaseMode.loop);
    _flyingPlayer.play(AssetSource('audio/flying.wav')).catchError((_) {
      _isFlyingActive = false;
    });
  }

  void stopFlyingLoop() {
    if (!_isFlyingActive) return;
    _isFlyingActive = false;
    _flyingPlayer.stop().catchError((_) {});
  }

  void updateFlyingState(bool shouldFly) {
    if (shouldFly) {
      startFlyingLoop();
    } else {
      stopFlyingLoop();
    }
  }

  void dispose() {
    _sfxPlayer.dispose();
    _flyingPlayer.dispose();
  }
}

class SoundOnNotifier extends Notifier<bool> {
  SharedPreferences? _prefs;
  static const _key = 'is_sound_on';

  @override
  bool build() {
    _init();
    return true;
  }

  Future<void> _init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (_prefs != null) {
        state = _prefs!.getBool(_key) ?? true;
      }
    } catch (_) {}
  }

  void toggle() {
    state = !state;
    _prefs?.setBool(_key, state);
  }
}

final soundOnProvider = NotifierProvider<SoundOnNotifier, bool>(
  SoundOnNotifier.new,
);

final audioControllerProvider = Provider<AudioController>((ref) {
  final controller = AudioController(ref);
  ref.onDispose(() {
    controller.dispose();
  });
  return controller;
});

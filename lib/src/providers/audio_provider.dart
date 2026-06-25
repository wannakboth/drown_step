import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'game_state.dart';

class AudioController with WidgetsBindingObserver {
  final Ref _ref;
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _flyingPlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer();

  bool _isBgmPlaying = false;
  bool _isHumPlaying = false;
  bool _isFlying = false;
  bool _isAppPaused = false;
  String? _currentBgmUrl;

  AudioController(this._ref) {
    _init();
    WidgetsBinding.instance.addObserver(this);
  }

  void _init() {
    // Listen to toggles and volumes to apply changes dynamically
    _ref.listen<bool>(soundOnProvider, (prev, next) {
      _applyBgmState();
      if (_isFlying) {
        _updateFlyingSoundState();
      }
    }, fireImmediately: true);

    _ref.listen<bool>(bgmOnProvider, (prev, next) {
      _applyBgmState();
    }, fireImmediately: true);

    _ref.listen<bool>(humOnProvider, (prev, next) {
      if (_isFlying) {
        _updateFlyingSoundState();
      }
    }, fireImmediately: true);

    _ref.listen<double>(bgmVolumeProvider, (prev, next) {
      _applyBgmState();
    }, fireImmediately: true);

    _ref.listen<double>(humVolumeProvider, (prev, next) {
      if (_isHumPlaying) {
        _flyingPlayer.setVolume(next * 2.0);
      }
    }, fireImmediately: true);

    _ref.listen<double>(sfxVolumeProvider, (prev, next) {
      _sfxPlayer.setVolume(next);
    }, fireImmediately: true);

    _ref.listen<AppScreen>(appScreenProvider, (prev, next) {
      _applyBgmState();
    }, fireImmediately: true);
  }

  void _updateFlyingSoundState() {
    final soundOn = _ref.read(soundOnProvider);
    final humOn = _ref.read(humOnProvider);
    if (soundOn && humOn) {
      startFlyingLoop();
    } else {
      stopFlyingLoop();
    }
  }

  void _applyBgmState() {
    if (_isAppPaused) return; // Don't play if app is minimized

    final soundOn = _ref.read(soundOnProvider);
    final bgmOn = _ref.read(bgmOnProvider);
    final vol = _ref.read(bgmVolumeProvider);
    final screen = _ref.read(appScreenProvider);

    if (soundOn && bgmOn) {
      final String targetUrl;
      final double volMultiplier;

      // Select track and volume level depending on the active screen
      if (screen == AppScreen.game) {
        targetUrl = 'audio/construct.mp3';
        volMultiplier = 0.40; // Soft/low background volume for the game screen
      } else {
        targetUrl = 'audio/departure.mp3';
        volMultiplier = 1.0; // Full volume on home/menu screens
      }

      final targetVolume = vol * volMultiplier;

      if (!_isBgmPlaying || _currentBgmUrl != targetUrl) {
        _isBgmPlaying = true;
        _currentBgmUrl = targetUrl;
        _bgmPlayer.setReleaseMode(ReleaseMode.loop);
        _bgmPlayer.setVolume(targetVolume);
        _bgmPlayer.play(AssetSource(targetUrl)).catchError((_) {
          _isBgmPlaying = false;
          _currentBgmUrl = null;
        });
      } else {
        // Update volume on current playing track and resume it
        _bgmPlayer.setVolume(targetVolume);
        _bgmPlayer.resume();
      }
    } else {
      if (_isBgmPlaying) {
        _isBgmPlaying = false;
        _currentBgmUrl = null;
        _bgmPlayer.stop().catchError((_) {});
      }
    }
  }

  void playClick() {
    final isSoundOn = _ref.read(soundOnProvider);
    if (!isSoundOn) return;
    final vol = _ref.read(sfxVolumeProvider);
    _sfxPlayer.stop().then((_) {
      _sfxPlayer.setVolume(vol);
      _sfxPlayer.play(AssetSource('audio/click.wav'));
    });
  }

  void playPickup() {
    final isSoundOn = _ref.read(soundOnProvider);
    if (!isSoundOn) return;
    final vol = _ref.read(sfxVolumeProvider);
    _sfxPlayer.stop().then((_) {
      _sfxPlayer.setVolume(vol);
      _sfxPlayer.play(AssetSource('audio/pickup.wav'));
    });
  }

  void playCrash() {
    final isSoundOn = _ref.read(soundOnProvider);
    if (!isSoundOn) return;
    final vol = _ref.read(sfxVolumeProvider);
    _sfxPlayer.stop().then((_) {
      _sfxPlayer.setVolume(vol);
      _sfxPlayer.play(AssetSource('audio/crash.wav'));
    });
  }

  void startFlyingLoop() {
    if (_isAppPaused) return; // Don't play if app is minimized

    final soundOn = _ref.read(soundOnProvider);
    final humOn = _ref.read(humOnProvider);
    if (!soundOn || !humOn) return;

    final vol = _ref.read(humVolumeProvider);
    _flyingPlayer.setVolume(vol * 2.0); // throttle up reactor!

    if (!_isHumPlaying) {
      _isHumPlaying = true;
      _flyingPlayer.setReleaseMode(ReleaseMode.loop);
      _flyingPlayer.play(AssetSource('audio/flying.wav')).catchError((_) {
        _isHumPlaying = false;
      });
    } else {
      _flyingPlayer.resume();
    }
  }

  void stopFlyingLoop() {
    if (_isHumPlaying) {
      _isHumPlaying = false;
      _flyingPlayer.stop().catchError((_) {});
    }
  }

  void updateFlyingState(bool shouldFly) {
    _isFlying = shouldFly;
    if (shouldFly) {
      startFlyingLoop();
    } else {
      stopFlyingLoop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _isAppPaused = true;
      _bgmPlayer.stop().catchError((_) {});
      _flyingPlayer.stop().catchError((_) {});
      _sfxPlayer.stop().catchError((_) {});
      _isBgmPlaying = false;
      _isHumPlaying = false;
      _currentBgmUrl = null;
    } else if (state == AppLifecycleState.resumed) {
      _isAppPaused = false;
      _applyBgmState();
      if (_isFlying) {
        _updateFlyingSoundState();
      }
    }
  }

  void pauseForAd() {
    _isAppPaused = true;
    _bgmPlayer.pause().catchError((_) {});
    _flyingPlayer.pause().catchError((_) {});
    _sfxPlayer.pause().catchError((_) {});
  }

  void resumeAfterAd() {
    _isAppPaused = false;
    _applyBgmState();
    if (_isFlying) {
      _updateFlyingSoundState();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sfxPlayer.dispose();
    _flyingPlayer.dispose();
    _bgmPlayer.dispose();
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

class BgmOnNotifier extends Notifier<bool> {
  SharedPreferences? _prefs;
  static const _key = 'is_bgm_on';

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

final bgmOnProvider = NotifierProvider<BgmOnNotifier, bool>(BgmOnNotifier.new);

class HumOnNotifier extends Notifier<bool> {
  SharedPreferences? _prefs;
  static const _key = 'is_hum_on';

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

final humOnProvider = NotifierProvider<HumOnNotifier, bool>(HumOnNotifier.new);

class SfxVolumeNotifier extends Notifier<double> {
  SharedPreferences? _prefs;
  static const _key = 'sfx_volume';

  @override
  double build() {
    _init();
    return 0.7;
  }

  Future<void> _init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (_prefs != null) {
        state = _prefs!.getDouble(_key) ?? 0.7;
      }
    } catch (_) {}
  }

  void setVolume(double val) {
    state = val.clamp(0.0, 1.0);
    _prefs?.setDouble(_key, state);
  }
}

final sfxVolumeProvider = NotifierProvider<SfxVolumeNotifier, double>(
  SfxVolumeNotifier.new,
);

class BgmVolumeNotifier extends Notifier<double> {
  SharedPreferences? _prefs;
  static const _key = 'bgm_volume';

  @override
  double build() {
    _init();
    return 0.4;
  }

  Future<void> _init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (_prefs != null) {
        state = _prefs!.getDouble(_key) ?? 0.4;
      }
    } catch (_) {}
  }

  void setVolume(double val) {
    state = val.clamp(0.0, 1.0);
    _prefs?.setDouble(_key, state);
  }
}

final bgmVolumeProvider = NotifierProvider<BgmVolumeNotifier, double>(
  BgmVolumeNotifier.new,
);

class HumVolumeNotifier extends Notifier<double> {
  SharedPreferences? _prefs;
  static const _key = 'hum_volume';

  @override
  double build() {
    _init();
    return 0.3;
  }

  Future<void> _init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (_prefs != null) {
        state = _prefs!.getDouble(_key) ?? 0.3;
      }
    } catch (_) {}
  }

  void setVolume(double val) {
    state = val.clamp(0.0, 1.0);
    _prefs?.setDouble(_key, state);
  }
}

final humVolumeProvider = NotifierProvider<HumVolumeNotifier, double>(
  HumVolumeNotifier.new,
);

final audioControllerProvider = Provider<AudioController>((ref) {
  final controller = AudioController(ref);
  ref.onDispose(() {
    controller.dispose();
  });
  return controller;
});

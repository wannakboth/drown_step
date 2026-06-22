import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioController {
  final Ref _ref;
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _flyingPlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer();

  bool _isBgmPlaying = false;
  bool _isHumPlaying = false;

  AudioController(this._ref) {
    _init();
  }

  void _init() {
    // Listen to toggles and volumes to apply changes dynamically
    _ref.listen<bool>(soundOnProvider, (prev, next) {
      _applyBgmState();
      _applyHumState();
    }, fireImmediately: true);

    _ref.listen<bool>(bgmOnProvider, (prev, next) {
      _applyBgmState();
    }, fireImmediately: true);

    _ref.listen<bool>(humOnProvider, (prev, next) {
      _applyHumState();
    }, fireImmediately: true);

    _ref.listen<double>(bgmVolumeProvider, (prev, next) {
      _bgmPlayer.setVolume(next);
    }, fireImmediately: true);

    _ref.listen<double>(humVolumeProvider, (prev, next) {
      if (_isHumPlaying) {
        _flyingPlayer.setVolume(next);
      }
    }, fireImmediately: true);

    _ref.listen<double>(sfxVolumeProvider, (prev, next) {
      _sfxPlayer.setVolume(next);
    }, fireImmediately: true);
  }

  void _applyBgmState() {
    final soundOn = _ref.read(soundOnProvider);
    final bgmOn = _ref.read(bgmOnProvider);
    final vol = _ref.read(bgmVolumeProvider);

    if (soundOn && bgmOn) {
      if (!_isBgmPlaying) {
        _isBgmPlaying = true;
        _bgmPlayer.setReleaseMode(ReleaseMode.loop);
        _bgmPlayer.setVolume(vol);
        _bgmPlayer
            .play(UrlSource('https://archive.org/download/synthwave-artifacts-retro-wave-2020/retro-wave-synthwave-01.mp3'))
            .catchError((_) {
          _isBgmPlaying = false;
        });
      }
    } else {
      if (_isBgmPlaying) {
        _isBgmPlaying = false;
        _bgmPlayer.stop().catchError((_) {});
      }
    }
  }

  void _applyHumState() {
    final soundOn = _ref.read(soundOnProvider);
    final humOn = _ref.read(humOnProvider);
    final vol = _ref.read(humVolumeProvider);

    if (soundOn && humOn) {
      if (!_isHumPlaying) {
        _isHumPlaying = true;
        _flyingPlayer.setReleaseMode(ReleaseMode.loop);
        _flyingPlayer.setVolume(vol);
        _flyingPlayer.play(AssetSource('audio/flying.wav')).catchError((_) {
          _isHumPlaying = false;
        });
      }
    } else {
      if (_isHumPlaying) {
        _isHumPlaying = false;
        _flyingPlayer.stop().catchError((_) {});
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
    final soundOn = _ref.read(soundOnProvider);
    if (!soundOn) return;

    final vol = _ref.read(humVolumeProvider);
    _flyingPlayer.setVolume(vol * 2.0); // throttle up reactor!
    
    if (!_isHumPlaying) {
      _isHumPlaying = true;
      _flyingPlayer.setReleaseMode(ReleaseMode.loop);
      _flyingPlayer.play(AssetSource('audio/flying.wav')).catchError((_) {
        _isHumPlaying = false;
      });
    }
  }

  void stopFlyingLoop() {
    final soundOn = _ref.read(soundOnProvider);
    final humOn = _ref.read(humOnProvider);
    final vol = _ref.read(humVolumeProvider);

    if (soundOn && humOn) {
      _flyingPlayer.setVolume(vol); // throttle down to ambient hum volume
    } else {
      if (_isHumPlaying) {
        _isHumPlaying = false;
        _flyingPlayer.stop().catchError((_) {});
      }
    }
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

final bgmOnProvider = NotifierProvider<BgmOnNotifier, bool>(
  BgmOnNotifier.new,
);

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

final humOnProvider = NotifierProvider<HumOnNotifier, bool>(
  HumOnNotifier.new,
);

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

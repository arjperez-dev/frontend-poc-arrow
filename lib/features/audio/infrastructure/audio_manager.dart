import 'package:flutter/widgets.dart';

import '../../settings/infrastructure/settings_dependencies.dart';
import '../application/background_music_controller.dart';
import '../application/game_audio_controller.dart';
import '../application/game_audio_event.dart';
import 'audio_players_audio_port.dart';
import 'audio_players_music_port.dart';

/// Single, app-lifetime owner of the SFX and music players.
///
/// Created once and reused for every level/retry/next-level navigation —
/// never recreated per screen. Recreating a fresh [GameAudioController] and
/// [BackgroundMusicController] (and their underlying native AudioPlayers) on
/// every [GameScreen] mount, with nothing disposing the old ones, was what
/// leaked native players and eventually crashed the app.
class AudioManager extends WidgetsBindingObserver {
  AudioManager._() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final AudioManager instance = AudioManager._();

  Future<GameAudioController>? _gameAudioController;
  Future<BackgroundMusicController>? _musicController;

  Future<GameAudioController> _getGameAudioController() {
    return _gameAudioController ??= _createGameAudioController();
  }

  Future<BackgroundMusicController> _getMusicController() {
    return _musicController ??= _createMusicController();
  }

  static Future<GameAudioController> _createGameAudioController() async {
    return GameAudioController(
      audioPort: AudioPlayersAudioPort(),
      getPlayerSettings:
          await SettingsDependencies.createGetPlayerSettingsUseCase(),
    );
  }

  static Future<BackgroundMusicController> _createMusicController() async {
    return BackgroundMusicController(
      musicPort: AudioPlayersMusicPort(),
      getPlayerSettings:
          await SettingsDependencies.createGetPlayerSettingsUseCase(),
    );
  }

  Future<void> playGameAudio(GameAudioEvent event) async {
    final controller = await _getGameAudioController();
    await controller.play(event);
  }

  // Reference-counted: pushReplacementNamed (used by "next level") disposes
  // the old GameScreen while mounting a new one, so an old screen's stop()
  // and a new screen's start() race each other on this same singleton. Only
  // the first claim actually starts playback and only the last release
  // actually stops it, so the music survives the overlap regardless of which
  // call lands first.
  int _musicClaims = 0;

  Future<void> startMusic() async {
    final isFirstClaim = _musicClaims == 0;
    _musicClaims++;
    if (!isFirstClaim) {
      return;
    }
    final controller = await _getMusicController();
    await controller.start();
  }

  Future<void> stopMusic() async {
    if (_musicClaims == 0) {
      return;
    }
    _musicClaims--;
    if (_musicClaims > 0) {
      return;
    }
    final controller = await _getMusicController();
    await controller.stop();
  }

  // Separate from _musicClaims: claims track which screen wants music, this
  // tracks whether the OS backgrounded the app. Leaving claims untouched here
  // means the music resumes on its own when the app comes back to the
  // foreground, without the still-active GameScreen having to do anything.
  bool _musicPausedForBackground = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pauseMusicForBackground();
    } else if (state == AppLifecycleState.resumed) {
      _resumeMusicFromBackground();
    }
  }

  Future<void> _pauseMusicForBackground() async {
    if (_musicClaims == 0 || _musicPausedForBackground) {
      return;
    }
    _musicPausedForBackground = true;
    final controller = await _getMusicController();
    await controller.stop();
  }

  Future<void> _resumeMusicFromBackground() async {
    if (!_musicPausedForBackground) {
      return;
    }
    _musicPausedForBackground = false;
    if (_musicClaims == 0) {
      return;
    }
    final controller = await _getMusicController();
    await controller.start();
  }
}

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../application/audio_port.dart';
import '../application/game_audio_event.dart';

/// Real sound-effects adapter backed by the `audioplayers` package.
/// Each [GameAudioEvent] maps to a short asset under `assets/audio/`.
///
/// Uses a small pool of players instead of one shared instance: SFX events
/// can fire in quick succession (e.g. move then blocked), and stop()+play()
/// on the same player while the previous clip is still draining is what
/// produced the crackling/sped-up playback this class used to have.
class AudioPlayersAudioPort implements AudioPort {
  AudioPlayersAudioPort({int poolSize = 3})
    : _players = List.generate(poolSize, (_) => AudioPlayer()) {
    for (final player in _players) {
      player.setAudioContext(_audioContext);
      player.setVolume(_effectsVolume);
    }
  }

  final List<AudioPlayer> _players;
  int _nextPlayerIndex = 0;

  static const double _effectsVolume = 0.25;
  static final AudioContext _audioContext = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
  );

  static const Map<GameAudioEvent, String> _assetByEvent = {
    GameAudioEvent.move: 'audio/move.mp3',
    GameAudioEvent.blocked: 'audio/blocked.mp3',
    GameAudioEvent.victory: 'audio/victory.mp3',
    GameAudioEvent.defeat: 'audio/defeat.mp3',
  };

  @override
  Future<void> play(GameAudioEvent event) async {
    final asset = _assetByEvent[event];
    if (asset == null) {
      return;
    }
    final player = _players[_nextPlayerIndex];
    _nextPlayerIndex = (_nextPlayerIndex + 1) % _players.length;
    try {
      await player.stop();
      await player.play(AssetSource(asset));
    } catch (error) {
      debugPrint('AudioPlayersAudioPort failed for $event: $error');
    }
  }

  Future<void> dispose() async {
    for (final player in _players) {
      await player.dispose();
    }
  }
}

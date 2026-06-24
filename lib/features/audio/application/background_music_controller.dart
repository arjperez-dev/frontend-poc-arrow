import '../../settings/application/get_player_settings_use_case.dart';
import 'music_port.dart';

class BackgroundMusicController {
  const BackgroundMusicController({
    required MusicPort musicPort,
    required GetPlayerSettingsUseCase getPlayerSettings,
  }) : _musicPort = musicPort,
       _getPlayerSettings = getPlayerSettings;

  final MusicPort _musicPort;
  final GetPlayerSettingsUseCase _getPlayerSettings;

  Future<void> start() async {
    final settings = await _getPlayerSettings();
    if (!settings.musicEnabled) {
      return;
    }
    await _musicPort.start();
  }

  Future<void> stop() => _musicPort.stop();
}

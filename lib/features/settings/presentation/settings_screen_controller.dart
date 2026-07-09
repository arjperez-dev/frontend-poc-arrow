import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/get_auth_session_use_case.dart';
import '../../auth/application/logout_use_case.dart';
import '../../auth/domain/auth_session.dart';
import '../../progress/application/reset_local_progress_use_case.dart';
import '../../progress/application/reset_remote_progress_use_case.dart';
import '../application/get_player_settings_use_case.dart';
import '../application/save_player_settings_use_case.dart';
import '../domain/player_settings.dart';

enum SettingsScreenLoadState { loading, ready, failed }

enum RemoteResetResult { success, offline, unauthenticated, failed }

typedef SyncProgressAction = Future<void> Function();

class SettingsScreenController extends ChangeNotifier {
  SettingsScreenController({
    required GetPlayerSettingsUseCase getPlayerSettings,
    required SavePlayerSettingsUseCase savePlayerSettings,
    required ResetLocalProgressUseCase resetLocalProgress,
    ResetRemoteProgressUseCase? resetRemoteProgress,
    GetAuthSessionUseCase? getAuthSession,
    LogoutUseCase? logout,
    SyncProgressAction? syncProgress,
  }) : _getPlayerSettings = getPlayerSettings,
       _savePlayerSettings = savePlayerSettings,
       _resetLocalProgress = resetLocalProgress,
       _resetRemoteProgress = resetRemoteProgress,
       _getAuthSession = getAuthSession,
       _logout = logout,
       _syncProgress = syncProgress;

  final GetPlayerSettingsUseCase _getPlayerSettings;
  final SavePlayerSettingsUseCase _savePlayerSettings;
  final ResetLocalProgressUseCase _resetLocalProgress;
  final ResetRemoteProgressUseCase? _resetRemoteProgress;
  final GetAuthSessionUseCase? _getAuthSession;
  final LogoutUseCase? _logout;
  final SyncProgressAction? _syncProgress;

  SettingsScreenLoadState _loadState = SettingsScreenLoadState.loading;
  PlayerSettings _settings = PlayerSettings.defaults();
  AuthSession? _authSession;
  bool _syncing = false;
  String? _syncMessage;
  bool _resettingRemote = false;

  SettingsScreenLoadState get loadState => _loadState;
  PlayerSettings get settings => _settings;
  AuthSession? get authSession => _authSession;
  bool get isLoggedIn => _authSession != null;
  bool get syncing => _syncing;
  String? get syncMessage => _syncMessage;
  bool get resettingRemote => _resettingRemote;
  bool get canResetRemoteProgress => _resetRemoteProgress != null && isLoggedIn;

  Future<void> load() async {
    _loadState = SettingsScreenLoadState.loading;
    notifyListeners();

    try {
      _settings = await _getPlayerSettings();
      _authSession = await _getAuthSession?.call();
      _loadState = SettingsScreenLoadState.ready;
      notifyListeners();
    } catch (_) {
      _loadState = SettingsScreenLoadState.failed;
      notifyListeners();
    }
  }

  Future<void> setSoundEnabled(bool value) async {
    await _save(_settings.copyWith(soundEnabled: value));
  }

  Future<void> setMusicEnabled(bool value) async {
    await _save(_settings.copyWith(musicEnabled: value));
  }

  Future<void> setLanguage(String? languageCode) async {
    await _save(
      _settings.copyWith(
        languageCode: languageCode,
        clearLanguage: languageCode == null,
      ),
    );
  }

  Future<void> resetProgress() {
    return _resetLocalProgress();
  }

  Future<RemoteResetResult> resetRemoteProgress() async {
    if (!isLoggedIn) {
      return RemoteResetResult.unauthenticated;
    }
    final resetRemoteProgress = _resetRemoteProgress;
    if (resetRemoteProgress == null) {
      return RemoteResetResult.unauthenticated;
    }
    _resettingRemote = true;
    notifyListeners();
    try {
      await resetRemoteProgress();
      return RemoteResetResult.success;
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        return RemoteResetResult.unauthenticated;
      }
      if (error.statusCode == null) {
        await _resetLocalProgress();
        return RemoteResetResult.offline;
      }
      return RemoteResetResult.failed;
    } catch (_) {
      return RemoteResetResult.failed;
    } finally {
      _resettingRemote = false;
      notifyListeners();
    }
  }

  Future<void> refreshAuthSession() async {
    _authSession = await _getAuthSession?.call();
    notifyListeners();
  }

  Future<void> logout() async {
    await _logout?.call();
    _authSession = null;
    _syncMessage = null;
    notifyListeners();
  }

  Future<bool> syncProgress() async {
    final syncProgress = _syncProgress;
    if (syncProgress == null || _authSession == null) {
      return false;
    }
    _syncing = true;
    _syncMessage = null;
    notifyListeners();
    try {
      await syncProgress();
      _syncMessage = 'success';
      _syncing = false;
      notifyListeners();
      return true;
    } catch (_) {
      _syncMessage = 'failed';
      _syncing = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _save(PlayerSettings updatedSettings) async {
    _settings = updatedSettings;
    notifyListeners();
    await _savePlayerSettings(updatedSettings);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';
import 'package:frontend_poc_arrow/core/theme/app_theme.dart';
import 'package:frontend_poc_arrow/features/auth/application/get_auth_session_use_case.dart';
import 'package:frontend_poc_arrow/features/auth/application/logout_use_case.dart';
import 'package:frontend_poc_arrow/features/auth/application/token_storage.dart';
import 'package:frontend_poc_arrow/features/auth/domain/auth_session.dart';
import 'package:frontend_poc_arrow/features/auth/domain/authenticated_user.dart';
import 'package:frontend_poc_arrow/core/network/api_exception.dart';
import 'package:frontend_poc_arrow/features/game/presentation/game_ui_keys.dart';
import 'package:frontend_poc_arrow/features/progress/application/local_progress_repository.dart';
import 'package:frontend_poc_arrow/features/progress/application/remote_progress_repository.dart';
import 'package:frontend_poc_arrow/features/progress/application/reset_local_progress_use_case.dart';
import 'package:frontend_poc_arrow/features/progress/application/reset_remote_progress_use_case.dart';
import 'package:frontend_poc_arrow/features/progress/application/save_level_completion_use_case.dart';
import 'package:frontend_poc_arrow/features/progress/domain/local_progress.dart';
import 'package:frontend_poc_arrow/features/progress/domain/remote_progress_entry.dart';
import 'package:frontend_poc_arrow/features/progress/infrastructure/shared_preferences_local_progress_repository.dart';
import 'package:frontend_poc_arrow/features/settings/application/get_player_settings_use_case.dart';
import 'package:frontend_poc_arrow/features/settings/application/save_player_settings_use_case.dart';
import 'package:frontend_poc_arrow/features/settings/application/settings_repository.dart';
import 'package:frontend_poc_arrow/features/settings/domain/player_settings.dart';
import 'package:frontend_poc_arrow/features/settings/infrastructure/shared_preferences_settings_repository.dart';
import 'package:frontend_poc_arrow/features/settings/presentation/settings_screen.dart';
import 'package:frontend_poc_arrow/features/settings/presentation/settings_screen_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('should_persist_sound_setting_when_toggled', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesSettingsRepository(preferences);
    final saveSettings = SavePlayerSettingsUseCase(repository);
    final getSettings = GetPlayerSettingsUseCase(repository);

    await saveSettings(
      const PlayerSettings(soundEnabled: false, musicEnabled: false),
    );

    final settings = await getSettings();
    expect(settings.soundEnabled, isFalse);
    expect(settings.musicEnabled, isFalse);
  });

  test('should_reset_local_progress_when_confirmed', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SharedPreferencesSettingsRepository(preferences);
    final progressRepository = SharedPreferencesLocalProgressRepository(
      preferences,
    );
    await SavePlayerSettingsUseCase(settingsRepository)(
      const PlayerSettings(soundEnabled: false, musicEnabled: true),
    );
    await SaveLevelCompletionUseCase(progressRepository)(
      levelNumber: 1,
      score: 990,
      moves: 1,
      timeSeconds: 0,
    );

    await progressRepository.resetProgress();

    final settings = await settingsRepository.getSettings();
    final progress = await progressRepository.getProgress();
    expect(settings.soundEnabled, isFalse);
    expect(settings.musicEnabled, isTrue);
    expect(progress.completedLevelNumbers, isEmpty);
    expect(progress.bestResultsByLevel, isEmpty);
    expect(progress.lastUnlockedLevel, 1);
  });

  testWidgets('should_reset_local_progress_when_confirmed_in_settings_screen', (
    tester,
  ) async {
    final progressRepository = _FakeLocalProgressRepository();
    final settingsRepository = _FakeSettingsRepository(
      const PlayerSettings(soundEnabled: false, musicEnabled: true),
    );
    final controller = SettingsScreenController(
      getPlayerSettings: GetPlayerSettingsUseCase(settingsRepository),
      savePlayerSettings: SavePlayerSettingsUseCase(settingsRepository),
      resetLocalProgress: ResetLocalProgressUseCase(progressRepository),
    );

    await tester.pumpWidget(_TestSettingsApp(controller: controller));
    await _pumpUntilFound(tester, find.byKey(GameUiKeys.soundSwitch));
    await tester.scrollUntilVisible(
      find.byKey(GameUiKeys.resetProgressButton),
      300,
      scrollable: find.byType(Scrollable),
    );

    await tester.tap(find.byKey(GameUiKeys.resetProgressButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GameUiKeys.confirmResetProgressButton));
    await tester.pumpAndSettle();

    expect(progressRepository.resetCount, 1);
    expect(settingsRepository.settings.soundEnabled, isFalse);
    expect(settingsRepository.settings.musicEnabled, isTrue);

    controller.dispose();
  });

  test(
    'should_show_logged_in_status_and_logout_from_settings_controller',
    () async {
      final tokenStorage = _FakeTokenStorage();
      final controller = SettingsScreenController(
        getPlayerSettings: GetPlayerSettingsUseCase(
          _FakeSettingsRepository(PlayerSettings.defaults()),
        ),
        savePlayerSettings: SavePlayerSettingsUseCase(
          _FakeSettingsRepository(PlayerSettings.defaults()),
        ),
        resetLocalProgress: ResetLocalProgressUseCase(
          _FakeLocalProgressRepository(),
        ),
        getAuthSession: GetAuthSessionUseCase(tokenStorage),
        logout: LogoutUseCase(tokenStorage),
      );

      await controller.load();
      expect(controller.isLoggedIn, isTrue);

      await controller.logout();
      expect(controller.isLoggedIn, isFalse);

      controller.dispose();
    },
  );

  test('should_report_sync_failure_without_clearing_local_settings', () async {
    final settingsRepository = _FakeSettingsRepository(
      const PlayerSettings(soundEnabled: true, musicEnabled: true),
    );
    final controller = SettingsScreenController(
      getPlayerSettings: GetPlayerSettingsUseCase(settingsRepository),
      savePlayerSettings: SavePlayerSettingsUseCase(settingsRepository),
      resetLocalProgress: ResetLocalProgressUseCase(
        _FakeLocalProgressRepository(),
      ),
      getAuthSession: GetAuthSessionUseCase(_FakeTokenStorage()),
      syncProgress: () async => throw Exception('Backend unavailable'),
    );

    await controller.load();
    final result = await controller.syncProgress();

    expect(result, isFalse);
    expect(controller.syncMessage, 'failed');
    expect(controller.settings.musicEnabled, isTrue);

    controller.dispose();
  });

  test('should_reset_remote_and_local_progress_when_remote_succeeds', () async {
    final localProgressRepository = _FakeLocalProgressRepository();
    final remoteProgressRepository = _FakeRemoteProgressRepository();
    final controller = SettingsScreenController(
      getPlayerSettings: GetPlayerSettingsUseCase(
        _FakeSettingsRepository(PlayerSettings.defaults()),
      ),
      savePlayerSettings: SavePlayerSettingsUseCase(
        _FakeSettingsRepository(PlayerSettings.defaults()),
      ),
      resetLocalProgress: ResetLocalProgressUseCase(localProgressRepository),
      resetRemoteProgress: ResetRemoteProgressUseCase(
        remoteProgressRepository: remoteProgressRepository,
        localProgressRepository: localProgressRepository,
      ),
      getAuthSession: GetAuthSessionUseCase(_FakeTokenStorage()),
    );

    await controller.load();
    final result = await controller.resetRemoteProgress();

    expect(result, RemoteResetResult.success);
    expect(remoteProgressRepository.resetCount, 1);
    expect(localProgressRepository.resetCount, 1);

    controller.dispose();
  });

  test(
    'should_clear_local_progress_only_when_backend_is_unreachable',
    () async {
      final localProgressRepository = _FakeLocalProgressRepository();
      final remoteProgressRepository = _FakeRemoteProgressRepository(
        error: const ApiException(message: 'Network request failed: offline'),
      );
      final controller = SettingsScreenController(
        getPlayerSettings: GetPlayerSettingsUseCase(
          _FakeSettingsRepository(PlayerSettings.defaults()),
        ),
        savePlayerSettings: SavePlayerSettingsUseCase(
          _FakeSettingsRepository(PlayerSettings.defaults()),
        ),
        resetLocalProgress: ResetLocalProgressUseCase(
          localProgressRepository,
        ),
        resetRemoteProgress: ResetRemoteProgressUseCase(
          remoteProgressRepository: remoteProgressRepository,
          localProgressRepository: localProgressRepository,
        ),
        getAuthSession: GetAuthSessionUseCase(_FakeTokenStorage()),
      );

      await controller.load();
      final result = await controller.resetRemoteProgress();

      expect(result, RemoteResetResult.offline);
      expect(localProgressRepository.resetCount, 1);

      controller.dispose();
    },
  );

  test(
    'should_report_unauthenticated_without_clearing_local_progress_on_401',
    () async {
      final localProgressRepository = _FakeLocalProgressRepository();
      final remoteProgressRepository = _FakeRemoteProgressRepository(
        error: const ApiException(message: 'Unauthorized', statusCode: 401),
      );
      final controller = SettingsScreenController(
        getPlayerSettings: GetPlayerSettingsUseCase(
          _FakeSettingsRepository(PlayerSettings.defaults()),
        ),
        savePlayerSettings: SavePlayerSettingsUseCase(
          _FakeSettingsRepository(PlayerSettings.defaults()),
        ),
        resetLocalProgress: ResetLocalProgressUseCase(
          localProgressRepository,
        ),
        resetRemoteProgress: ResetRemoteProgressUseCase(
          remoteProgressRepository: remoteProgressRepository,
          localProgressRepository: localProgressRepository,
        ),
        getAuthSession: GetAuthSessionUseCase(_FakeTokenStorage()),
      );

      await controller.load();
      final result = await controller.resetRemoteProgress();

      expect(result, RemoteResetResult.unauthenticated);
      expect(localProgressRepository.resetCount, 0);

      controller.dispose();
    },
  );

  test(
    'should_report_unauthenticated_and_disable_action_when_logged_out',
    () async {
      final localProgressRepository = _FakeLocalProgressRepository();
      final remoteProgressRepository = _FakeRemoteProgressRepository();
      final controller = SettingsScreenController(
        getPlayerSettings: GetPlayerSettingsUseCase(
          _FakeSettingsRepository(PlayerSettings.defaults()),
        ),
        savePlayerSettings: SavePlayerSettingsUseCase(
          _FakeSettingsRepository(PlayerSettings.defaults()),
        ),
        resetLocalProgress: ResetLocalProgressUseCase(
          localProgressRepository,
        ),
        resetRemoteProgress: ResetRemoteProgressUseCase(
          remoteProgressRepository: remoteProgressRepository,
          localProgressRepository: localProgressRepository,
        ),
      );

      await controller.load();
      expect(controller.canResetRemoteProgress, isFalse);
      final result = await controller.resetRemoteProgress();

      expect(result, RemoteResetResult.unauthenticated);
      expect(remoteProgressRepository.resetCount, 0);
      expect(localProgressRepository.resetCount, 0);

      controller.dispose();
    },
  );

  test(
    'should_report_generic_failure_without_clearing_local_progress',
    () async {
      final localProgressRepository = _FakeLocalProgressRepository();
      final remoteProgressRepository = _FakeRemoteProgressRepository(
        error: const ApiException(message: 'Server error', statusCode: 500),
      );
      final controller = SettingsScreenController(
        getPlayerSettings: GetPlayerSettingsUseCase(
          _FakeSettingsRepository(PlayerSettings.defaults()),
        ),
        savePlayerSettings: SavePlayerSettingsUseCase(
          _FakeSettingsRepository(PlayerSettings.defaults()),
        ),
        resetLocalProgress: ResetLocalProgressUseCase(
          localProgressRepository,
        ),
        resetRemoteProgress: ResetRemoteProgressUseCase(
          remoteProgressRepository: remoteProgressRepository,
          localProgressRepository: localProgressRepository,
        ),
        getAuthSession: GetAuthSessionUseCase(_FakeTokenStorage()),
      );

      await controller.load();
      final result = await controller.resetRemoteProgress();

      expect(result, RemoteResetResult.failed);
      expect(localProgressRepository.resetCount, 0);

      controller.dispose();
    },
  );

  test('should_persist_language_when_changed', () async {
    final settingsRepository = _FakeSettingsRepository(
      const PlayerSettings(soundEnabled: true, musicEnabled: false),
    );
    final controller = SettingsScreenController(
      getPlayerSettings: GetPlayerSettingsUseCase(settingsRepository),
      savePlayerSettings: SavePlayerSettingsUseCase(settingsRepository),
      resetLocalProgress: ResetLocalProgressUseCase(
        _FakeLocalProgressRepository(),
      ),
    );

    await controller.load();
    await controller.setLanguage('es');

    expect(controller.settings.languageCode, 'es');
    expect(settingsRepository.settings.languageCode, 'es');

    controller.dispose();
  });
  
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Expected widget was not found: $finder');
}

class _TestSettingsApp extends StatelessWidget {
  const _TestSettingsApp({required this.controller});

  final SettingsScreenController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsScreen(controller: controller),
    );
  }
}

class _FakeLocalProgressRepository implements LocalProgressRepository {
  int resetCount = 0;

  @override
  Future<LocalProgress> getProgress() async {
    return LocalProgress.initial();
  }

  @override
  Future<void> resetProgress() async {
    resetCount += 1;
  }

  @override
  Future<void> saveProgress(LocalProgress progress) async {}

  @override
  Future<String?> getLastSyncedUserId() async => null;

  @override
  Future<void> setLastSyncedUserId(String? userId) async {}
}

class _FakeRemoteProgressRepository implements RemoteProgressRepository {
  _FakeRemoteProgressRepository({this.error});

  final Object? error;
  int resetCount = 0;

  @override
  Future<List<RemoteProgressEntry>> getMyProgress() async => const [];

  @override
  Future<void> syncProgress({
    required String levelId,
    required bool completed,
    required int? bestScore,
    required int? bestMoves,
    required int? bestTimeSeconds,
  }) async {}

  @override
  Future<void> resetProgress() async {
    final error = this.error;
    if (error != null) {
      throw error;
    }
    resetCount += 1;
  }
}

class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository(this.settings);

  PlayerSettings settings;

  @override
  Future<PlayerSettings> getSettings() async {
    return settings;
  }

  @override
  Future<void> saveSettings(PlayerSettings settings) async {
    this.settings = settings;
  }
}

class _FakeTokenStorage implements TokenStorage {
  AuthSession? session = const AuthSession(
    accessToken: 'token',
    user: AuthenticatedUser(
      id: 'user-1',
      email: 'player@example.com',
      displayName: 'Player',
      role: 'PLAYER',
    ),
  );

  @override
  Future<void> clearSession() async {
    session = null;
  }

  @override
  Future<String?> getAccessToken() async {
    return session?.accessToken;
  }

  @override
  Future<AuthSession?> getSession() async {
    return session;
  }

  @override
  Future<void> saveSession(AuthSession session) async {
    this.session = session;
  }
}

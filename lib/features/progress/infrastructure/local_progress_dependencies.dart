import 'package:shared_preferences/shared_preferences.dart';

import '../application/get_best_level_result_use_case.dart';
import '../application/get_local_progress_use_case.dart';
import '../application/is_level_unlocked_use_case.dart';
import '../application/local_progress_repository.dart';
import '../application/notify_remote_level_completion_use_case.dart';
import '../application/reset_local_progress_use_case.dart';
import '../application/reset_remote_progress_use_case.dart';
import '../application/save_level_completion_use_case.dart';
import '../application/sync_progress_on_login_use_case.dart';
import '../application/sync_progress_use_case.dart';
import '../../../core/network/network_dependencies.dart';
import '../../auth/infrastructure/auth_dependencies.dart';
import '../../leaderboard/infrastructure/leaderboard_dependencies.dart';
import 'api_remote_level_repository.dart';
import 'api_remote_progress_repository.dart';
import 'shared_preferences_local_progress_repository.dart';

class LocalProgressDependencies {
  const LocalProgressDependencies._();

  static Future<LocalProgressRepository> createRepository() async {
    return SharedPreferencesLocalProgressRepository(
      await SharedPreferences.getInstance(),
    );
  }

  static Future<GetLocalProgressUseCase> createGetLocalProgressUseCase() async {
    return GetLocalProgressUseCase(await createRepository());
  }

  static Future<SaveLevelCompletionUseCase>
  createSaveLevelCompletionUseCase() async {
    return SaveLevelCompletionUseCase(await createRepository());
  }

  static Future<IsLevelUnlockedUseCase> createIsLevelUnlockedUseCase() async {
    return IsLevelUnlockedUseCase(await createRepository());
  }

  static Future<GetBestLevelResultUseCase>
  createGetBestLevelResultUseCase() async {
    return GetBestLevelResultUseCase(await createRepository());
  }

  static Future<ResetLocalProgressUseCase>
  createResetLocalProgressUseCase() async {
    return ResetLocalProgressUseCase(await createRepository());
  }

  static Future<ResetRemoteProgressUseCase>
  createResetRemoteProgressUseCase() async {
    final apiClient = await NetworkDependencies.createApiClient();
    return ResetRemoteProgressUseCase(
      remoteProgressRepository: ApiRemoteProgressRepository(apiClient),
      localProgressRepository: await createRepository(),
    );
  }

  static Future<SyncProgressUseCase> createSyncProgressUseCase() async {
    final apiClient = await NetworkDependencies.createApiClient();
    return SyncProgressUseCase(
      localProgressRepository: await createRepository(),
      remoteProgressRepository: ApiRemoteProgressRepository(apiClient),
      remoteLevelRepository: ApiRemoteLevelRepository(apiClient),
    );
  }

  static Future<SyncProgressOnLoginUseCase>
  createSyncProgressOnLoginUseCase() async {
    return SyncProgressOnLoginUseCase(
      localProgressRepository: await createRepository(),
      syncProgress: await createSyncProgressUseCase(),
    );
  }

  static Future<NotifyRemoteLevelCompletionUseCase>
  createNotifyRemoteLevelCompletionUseCase() async {
    return NotifyRemoteLevelCompletionUseCase(
      tokenStorage: await AuthDependencies.createTokenStorage(),
      syncProgress: await createSyncProgressUseCase(),
      submitLeaderboardScore:
          await LeaderboardDependencies.createSubmitLeaderboardScoreUseCase(),
    );
  }
}

import '../../../core/network/network_dependencies.dart';
import '../../auth/infrastructure/auth_dependencies.dart';
import '../../progress/infrastructure/api_remote_level_repository.dart';
import '../application/get_leaderboard_for_level_number_use_case.dart';
import '../application/submit_leaderboard_score_use_case.dart';
import 'api_leaderboard_repository.dart';

class LeaderboardDependencies {
  const LeaderboardDependencies._();

  static Future<GetLeaderboardForLevelNumberUseCase>
  createGetLeaderboardForLevelNumberUseCase() async {
    final apiClient = await NetworkDependencies.createApiClient();
    return GetLeaderboardForLevelNumberUseCase(
      leaderboardRepository: ApiLeaderboardRepository(apiClient),
      remoteLevelRepository: ApiRemoteLevelRepository(apiClient),
    );
  }

  static Future<SubmitLeaderboardScoreUseCase>
  createSubmitLeaderboardScoreUseCase() async {
    final apiClient = await NetworkDependencies.createApiClient();
    return SubmitLeaderboardScoreUseCase(
      leaderboardRepository: ApiLeaderboardRepository(apiClient),
      remoteLevelRepository: ApiRemoteLevelRepository(apiClient),
      tokenStorage: await AuthDependencies.createTokenStorage(),
    );
  }
}

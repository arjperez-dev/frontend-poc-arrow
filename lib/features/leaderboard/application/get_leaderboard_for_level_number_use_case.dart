import '../../progress/application/remote_level_repository.dart';
import '../domain/leaderboard_entry.dart';
import 'leaderboard_repository.dart';

/// Fetches the leaderboard for a LOCAL level number by first resolving it to
/// the backend level id, mirroring [SubmitLeaderboardScoreUseCase]'s
/// resolution flow. Returns an empty list when the backend has no mapping
/// for the number (remote unavailable or level unknown remotely) — the
/// caller renders that as "leaderboard unavailable", never as an error.
class GetLeaderboardForLevelNumberUseCase {
  const GetLeaderboardForLevelNumberUseCase({
    required LeaderboardRepository leaderboardRepository,
    required RemoteLevelRepository remoteLevelRepository,
  }) : _leaderboardRepository = leaderboardRepository,
       _remoteLevelRepository = remoteLevelRepository;

  final LeaderboardRepository _leaderboardRepository;
  final RemoteLevelRepository _remoteLevelRepository;

  Future<List<LeaderboardEntry>> call(int levelNumber) async {
    final levelIdsByNumber = await _remoteLevelRepository.getLevelIdsByNumber();
    final levelId = levelIdsByNumber[levelNumber];
    if (levelId == null) {
      return const <LeaderboardEntry>[];
    }
    return _leaderboardRepository.getForLevel(levelId);
  }
}

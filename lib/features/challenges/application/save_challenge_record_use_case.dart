import '../domain/challenge.dart';
import 'challenge_records_repository.dart';

class SaveChallengeRecordUseCase {
  const SaveChallengeRecordUseCase(this._repository);

  final ChallengeRecordsRepository _repository;

  /// Returns true when [score] set a new best for ([challenge], [levelNumber]).
  Future<bool> call({
    required Challenge challenge,
    required int levelNumber,
    required int score,
  }) {
    return _repository.saveRecord(
      challenge: challenge,
      levelNumber: levelNumber,
      score: score,
    );
  }
}

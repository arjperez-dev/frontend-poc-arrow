import '../domain/challenge.dart';
import 'challenge_records_repository.dart';

class GetChallengeRecordsUseCase {
  const GetChallengeRecordsUseCase(this._repository);

  final ChallengeRecordsRepository _repository;

  Future<Map<int, int>> call(Challenge challenge) {
    return _repository.getRecords(challenge);
  }
}

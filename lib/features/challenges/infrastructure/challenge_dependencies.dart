import 'package:shared_preferences/shared_preferences.dart';

import '../application/challenge_records_repository.dart';
import '../application/get_challenge_records_use_case.dart';
import '../application/save_challenge_record_use_case.dart';
import 'shared_preferences_challenge_records_repository.dart';

class ChallengeDependencies {
  const ChallengeDependencies._();

  static Future<ChallengeRecordsRepository> _createRepository() async {
    return SharedPreferencesChallengeRecordsRepository(
      await SharedPreferences.getInstance(),
    );
  }

  static Future<GetChallengeRecordsUseCase>
  createGetChallengeRecordsUseCase() async {
    return GetChallengeRecordsUseCase(await _createRepository());
  }

  static Future<SaveChallengeRecordUseCase>
  createSaveChallengeRecordUseCase() async {
    return SaveChallengeRecordUseCase(await _createRepository());
  }
}

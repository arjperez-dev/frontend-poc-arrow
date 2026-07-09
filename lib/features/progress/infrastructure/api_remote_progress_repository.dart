import '../../../core/network/api_client.dart';
import '../application/remote_progress_repository.dart';
import '../domain/remote_progress_entry.dart';

class ApiRemoteProgressRepository implements RemoteProgressRepository {
  const ApiRemoteProgressRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<RemoteProgressEntry>> getMyProgress() async {
    final response = await _apiClient.get('/progress/me', authenticated: true);
    if (response is! List) {
      throw const FormatException('Invalid progress response.');
    }
    return response
        .whereType<Map<String, Object?>>()
        .map(_entryFromJson)
        .toList(growable: false);
  }

  @override
  Future<void> syncProgress({
    required String levelId,
    required bool completed,
    required int? bestScore,
    required int? bestMoves,
    required int? bestTimeSeconds,
  }) async {
    await _apiClient.post(
      '/progress/sync',
      authenticated: true,
      body: {
        'levelId': levelId,
        'completed': completed,
        'bestScore': bestScore,
        'bestMoves': bestMoves,
        'bestTimeSeconds': bestTimeSeconds,
      },
    );
  }

  @override
  Future<void> resetProgress() async {
    await _apiClient.delete('/progress', authenticated: true);
  }

  RemoteProgressEntry _entryFromJson(Map<String, Object?> json) {
    return RemoteProgressEntry(
      levelId: json['levelId']?.toString() ?? '',
      completed: json['completed'] == true,
      bestScore: (json['bestScore'] as num?)?.toInt(),
      bestMoves: (json['bestMoves'] as num?)?.toInt(),
      bestTimeSeconds: (json['bestTimeSeconds'] as num?)?.toInt(),
    );
  }
}

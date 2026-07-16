import '../../../core/network/api_client.dart';
import '../application/remote_level_definition_repository.dart';
import 'manual_level_dto.dart';

/// Fetches additional, real, playable levels from the backend
/// (`GET /levels`, `number >= 1000` per
/// `backend-poc-arrow/docs/DYNAMIC_LEVELS_CONTRACT.md`) and maps them into
/// [ManualLevelDto] using the same parsing as local assets.
///
/// Best-effort: a malformed entry is skipped, and any failure (network error,
/// unexpected response shape) resolves to an empty list rather than throwing,
/// mirroring the existing remote-fetch behavior in
/// `ApiRemoteLevelRepository`.
class ApiRemoteLevelDefinitionRepository
    implements RemoteLevelDefinitionRepository {
  const ApiRemoteLevelDefinitionRepository(this._apiClient);

  static const int _remoteLevelNumberFloor = 1000;

  final ApiClient _apiClient;

  @override
  Future<List<ManualLevelDto>> fetchRemoteLevels() async {
    final Object? response;
    try {
      response = await _apiClient.get('/levels');
    } catch (_) {
      return const [];
    }

    if (response is! List) {
      return const [];
    }

    final levels = <ManualLevelDto>[];
    for (final item in response) {
      if (item is! Map<String, Object?>) {
        continue;
      }
      final number = (item['number'] as num?)?.toInt();
      if (number == null || number < _remoteLevelNumberFloor) {
        continue;
      }
      try {
        levels.add(ManualLevelDto.fromJson(item));
      } catch (_) {
        continue;
      }
    }
    return levels;
  }
}

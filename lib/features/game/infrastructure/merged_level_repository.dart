import '../application/level_repository.dart';
import '../application/remote_level_definition_repository.dart';
import '../domain/level.dart';
import '../domain/level_definition_validator.dart';
import 'level_definition_mapper.dart';
import 'manual_level_dto.dart';
import 'remote_level_cache.dart';

/// Offline-first level source (Phase 34.4): local bundled levels always load
/// and are authoritative; remote levels (Phase 34.3, number >= 1000) are
/// appended for numbers not present locally, cached for offline replay, and
/// never override or break local levels.
///
/// A remote fetch that fails or is unreachable is silently ignored (falls
/// back to the last cache, or local-only with no cache) — degrading to local
/// levels must never break level selection or gameplay.
class MergedLevelRepository implements LevelRepository {
  const MergedLevelRepository({
    required LevelRepository localLevelRepository,
    required RemoteLevelDefinitionRepository remoteLevelDefinitionRepository,
    RemoteLevelCache remoteLevelCache = const RemoteLevelCache(),
    LevelDefinitionMapper levelDefinitionMapper = const LevelDefinitionMapper(),
    LevelDefinitionValidator levelDefinitionValidator =
        const LevelDefinitionValidator(),
  }) : _localLevelRepository = localLevelRepository,
       _remoteLevelDefinitionRepository = remoteLevelDefinitionRepository,
       _remoteLevelCache = remoteLevelCache,
       _levelDefinitionMapper = levelDefinitionMapper,
       _levelDefinitionValidator = levelDefinitionValidator;

  final LevelRepository _localLevelRepository;
  final RemoteLevelDefinitionRepository _remoteLevelDefinitionRepository;
  final RemoteLevelCache _remoteLevelCache;
  final LevelDefinitionMapper _levelDefinitionMapper;
  final LevelDefinitionValidator _levelDefinitionValidator;

  @override
  Future<List<Level>> getManualLevels() async {
    final localLevels = await _localLevelRepository.getManualLevels();
    final remoteDtos = await _resolveRemoteLevels();

    final localNumbers = {
      for (final level in localLevels)
        if (level.number != null) level.number,
    };

    final remoteLevels = <Level>[];
    for (final dto in remoteDtos) {
      if (localNumbers.contains(dto.number)) {
        continue;
      }
      try {
        remoteLevels.add(
          _levelDefinitionValidator.validate(_levelDefinitionMapper.toDomain(dto)),
        );
      } catch (_) {
        continue;
      }
    }

    return [...localLevels, ...remoteLevels];
  }

  @override
  Future<Level?> getManualLevelByNumber(int number) async {
    final levels = await getManualLevels();
    for (final level in levels) {
      if (level.number == number) {
        return level;
      }
    }
    return null;
  }

  /// Fetches remote levels best-effort. A non-empty fetch is treated as fresh
  /// truth and refreshes the cache; an empty/failed fetch falls back to the
  /// last cached levels so a transient outage or backend hiccup never
  /// discards previously downloaded remote content.
  Future<List<ManualLevelDto>> _resolveRemoteLevels() async {
    List<ManualLevelDto> fetched;
    try {
      fetched = await _remoteLevelDefinitionRepository.fetchRemoteLevels();
    } catch (_) {
      fetched = const [];
    }

    if (fetched.isNotEmpty) {
      try {
        await _remoteLevelCache.writeCachedLevels(fetched);
      } catch (_) {
        // Cache write failures must never affect gameplay.
      }
      return fetched;
    }

    try {
      return await _remoteLevelCache.readCachedLevels();
    } catch (_) {
      return const [];
    }
  }
}

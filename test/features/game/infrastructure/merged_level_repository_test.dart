import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/application/level_repository.dart';
import 'package:frontend_poc_arrow/features/game/application/remote_level_definition_repository.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_graph.dart';
import 'package:frontend_poc_arrow/features/game/domain/level.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/manual_level_dto.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/merged_level_repository.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/remote_level_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

ManualLevelDto _dto(int number, {List<Map<String, Object?>> nodes = const []}) {
  return ManualLevelDto.fromJson({
    'number': number,
    'name': 'Level $number',
    'difficulty': 'easy',
    'definitionJson': {
      'nodes': nodes,
      'edges': <Object?>[],
      'arrows': <Object?>[],
      'blockedEdges': <Object?>[],
      'metadata': {'mode': nodes.any((n) => (n['z'] as int? ?? 0) != 0) ? '3d' : '2d'},
    },
  });
}

class _FakeLocalLevelRepository implements LevelRepository {
  _FakeLocalLevelRepository(this.levels);

  final List<Level> levels;

  @override
  Future<List<Level>> getManualLevels() async => levels;

  @override
  Future<Level?> getManualLevelByNumber(int number) async {
    for (final level in levels) {
      if (level.number == number) return level;
    }
    return null;
  }
}

class _FakeRemoteLevelDefinitionRepository
    implements RemoteLevelDefinitionRepository {
  _FakeRemoteLevelDefinitionRepository({this.levels = const [], this.error});

  final List<ManualLevelDto> levels;
  final Object? error;

  @override
  Future<List<ManualLevelDto>> fetchRemoteLevels() async {
    if (error != null) throw error!;
    return levels;
  }
}

Level _localLevel(int number) {
  return Level(
    id: 'manual-${number.toString().padLeft(3, '0')}',
    number: number,
    name: 'Local $number',
    boardGraph: BoardGraph(nodes: const [], edges: const []),
    arrows: const [],
    metadata: {'number': number, 'difficulty': 'easy'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('should_append_remote_levels_with_numbers_not_present_locally', () async {
    final repository = MergedLevelRepository(
      localLevelRepository: _FakeLocalLevelRepository([_localLevel(1)]),
      remoteLevelDefinitionRepository: _FakeRemoteLevelDefinitionRepository(
        levels: [_dto(1000), _dto(1001)],
      ),
    );

    final levels = await repository.getManualLevels();

    expect(levels.map((l) => l.number), [1, 1000, 1001]);
  });

  test('should_keep_local_level_when_remote_number_conflicts', () async {
    final repository = MergedLevelRepository(
      localLevelRepository: _FakeLocalLevelRepository([_localLevel(1)]),
      remoteLevelDefinitionRepository: _FakeRemoteLevelDefinitionRepository(
        levels: [_dto(1)],
      ),
    );

    final levels = await repository.getManualLevels();

    expect(levels, hasLength(1));
    expect(levels.single.name, 'Local 1');
  });

  test('should_fall_back_to_local_only_when_remote_fetch_fails_and_no_cache', () async {
    final repository = MergedLevelRepository(
      localLevelRepository: _FakeLocalLevelRepository([_localLevel(1)]),
      remoteLevelDefinitionRepository: _FakeRemoteLevelDefinitionRepository(
        error: Exception('network down'),
      ),
    );

    final levels = await repository.getManualLevels();

    expect(levels.map((l) => l.number), [1]);
  });

  test('should_serve_cached_remote_levels_when_fetch_returns_empty', () async {
    const cache = RemoteLevelCache();
    await cache.writeCachedLevels([_dto(1000)]);

    final repository = MergedLevelRepository(
      localLevelRepository: _FakeLocalLevelRepository([_localLevel(1)]),
      remoteLevelDefinitionRepository: _FakeRemoteLevelDefinitionRepository(),
      remoteLevelCache: cache,
    );

    final levels = await repository.getManualLevels();

    expect(levels.map((l) => l.number), [1, 1000]);
  });

  test('should_preserve_2d_3d_routing_for_merged_remote_levels', () async {
    final repository = MergedLevelRepository(
      localLevelRepository: _FakeLocalLevelRepository([_localLevel(1)]),
      remoteLevelDefinitionRepository: _FakeRemoteLevelDefinitionRepository(
        levels: [
          _dto(
            1001,
            nodes: [
              {'id': 'n0', 'x': 0, 'y': 0, 'z': 0},
              {'id': 'n1', 'x': 0, 'y': 0, 'z': 1},
            ],
          ),
        ],
      ),
    );

    final levels = await repository.getManualLevels();
    final remoteLevel = levels.firstWhere((l) => l.number == 1001);

    expect(remoteLevel.boardGraph.isMultiLayer, isTrue);
  });
}

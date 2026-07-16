import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/core/network/api_client.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/api_remote_level_definition_repository.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/asset_level_repository.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/local_level_data_source.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/asset_text_loader.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/merged_level_repository.dart';
import 'package:frontend_poc_arrow/features/game/presentation/level_mode_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 34.5: proves the full backend-driven-levels path end-to-end using
/// the real local asset repository (levels 1-30), the real
/// [ApiRemoteLevelDefinitionRepository] mapping logic, and the real
/// [MergedLevelRepository] merge/cache policy — only the HTTP transport is
/// faked. Also asserts the regressions the phase file requires: local levels
/// stay intact and playable even when the backend is unreachable, and 2D/3D
/// routing is preserved for merged remote levels.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  AssetLevelRepository createLocalRepository() {
    return AssetLevelRepository(
      localLevelDataSource: LocalLevelDataSource(
        assetTextLoader: const RootBundleAssetTextLoader(),
      ),
    );
  }

  const remoteLevelsResponse = [
    {
      'number': 1000,
      'name': 'Remote First Exit',
      'difficulty': 'easy',
      'definitionJson': {
        'nodes': [
          {'id': 'n0_0', 'x': 0, 'y': 0},
          {'id': 'n1_0', 'x': 1, 'y': 0},
        ],
        'edges': <Object?>[],
        'arrows': <Object?>[],
        'blockedEdges': <Object?>[],
        'metadata': {'mode': '2d'},
      },
    },
    {
      'number': 1001,
      'name': 'Remote Vertical Post',
      'difficulty': 'medium',
      'definitionJson': {
        'nodes': [
          {'id': 'n0_0_0', 'x': 0, 'y': 0, 'z': 0},
          {'id': 'n0_0_1', 'x': 0, 'y': 0, 'z': 1},
        ],
        'edges': <Object?>[],
        'arrows': <Object?>[],
        'blockedEdges': <Object?>[],
        'metadata': {'mode': '3d'},
      },
    },
  ];

  test(
    'should_download_merge_and_route_an_extra_2d_and_3d_level_end_to_end',
    () async {
      final repository = MergedLevelRepository(
        localLevelRepository: createLocalRepository(),
        remoteLevelDefinitionRepository: ApiRemoteLevelDefinitionRepository(
          _FakeApiClient(response: remoteLevelsResponse),
        ),
      );

      final levels = await repository.getManualLevels();
      final numbers = levels.map((l) => l.number).toSet();

      expect(numbers.containsAll([1000, 1001]), isTrue);
      expect(numbers.length, 32); // local 1-30 + remote 1000, 1001.

      final remote2d = levels.firstWhere((l) => l.number == 1000);
      final remote3d = levels.firstWhere((l) => l.number == 1001);
      expect(isThreeDLevel(remote2d), isFalse);
      expect(isThreeDLevel(remote3d), isTrue);

      final twoD = filterLevelsByGameMode(levels, wantThreeD: false);
      final threeD = filterLevelsByGameMode(levels, wantThreeD: true);
      expect(twoD.any((l) => l.number == 1000), isTrue);
      expect(threeD.any((l) => l.number == 1001), isTrue);
      expect(twoD.any((l) => l.number == 1001), isFalse);
      expect(threeD.any((l) => l.number == 1000), isFalse);
    },
  );

  test(
    'should_load_all_local_levels_unchanged_when_backend_is_unreachable',
    () async {
      final repository = MergedLevelRepository(
        localLevelRepository: createLocalRepository(),
        remoteLevelDefinitionRepository: ApiRemoteLevelDefinitionRepository(
          _FakeApiClient(error: Exception('network down')),
        ),
      );

      final localOnly = await createLocalRepository().getManualLevels();
      final merged = await repository.getManualLevels();

      expect(merged.length, localOnly.length);
      expect(
        merged.map((l) => l.number).toList(),
        localOnly.map((l) => l.number).toList(),
      );
      expect(merged.map((l) => l.number).toSet(), {
        for (var i = 1; i <= 30; i++) i,
      });
    },
  );

  test(
    'should_serve_cached_remote_levels_offline_after_a_prior_successful_fetch',
    () async {
      final firstRunRepository = MergedLevelRepository(
        localLevelRepository: createLocalRepository(),
        remoteLevelDefinitionRepository: ApiRemoteLevelDefinitionRepository(
          _FakeApiClient(response: remoteLevelsResponse),
        ),
      );
      await firstRunRepository.getManualLevels();

      final offlineRepository = MergedLevelRepository(
        localLevelRepository: createLocalRepository(),
        remoteLevelDefinitionRepository: ApiRemoteLevelDefinitionRepository(
          _FakeApiClient(error: Exception('backend down')),
        ),
      );

      final levels = await offlineRepository.getManualLevels();
      final numbers = levels.map((l) => l.number).toSet();

      expect(numbers.containsAll([1000, 1001]), isTrue);
    },
  );
}

class _FakeApiClient implements ApiClient {
  _FakeApiClient({this.response, this.error});

  final Object? response;
  final Object? error;

  @override
  Future<Object?> get(String path, {bool authenticated = false}) async {
    if (error != null) {
      throw error!;
    }
    return response;
  }

  @override
  Future<Object?> post(
    String path, {
    Object? body,
    bool authenticated = false,
  }) async => null;

  @override
  Future<Object?> put(
    String path, {
    Object? body,
    bool authenticated = false,
  }) async => null;

  @override
  Future<Object?> delete(String path, {bool authenticated = false}) async =>
      null;
}

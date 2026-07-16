import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/core/network/api_client.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/api_remote_level_definition_repository.dart';

void main() {
  test(
    'should_map_2d_and_3d_remote_levels_preserving_z_when_response_is_valid',
    () async {
      final repository = ApiRemoteLevelDefinitionRepository(
        _FakeApiClient(response: [
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
          // Local level; must be excluded (number < 1000).
          {
            'number': 1,
            'name': 'Local Level',
            'difficulty': 'easy',
            'definitionJson': {
              'nodes': <Object?>[],
              'edges': <Object?>[],
              'arrows': <Object?>[],
              'blockedEdges': <Object?>[],
              'metadata': <String, Object?>{},
            },
          },
        ]),
      );

      final levels = await repository.fetchRemoteLevels();

      expect(levels, hasLength(2));
      expect(levels[0].number, 1000);
      expect(levels[0].definitionJson.nodes.every((n) => n.z == 0), isTrue);
      expect(levels[1].number, 1001);
      expect(
        levels[1].definitionJson.nodes.any((n) => n.z != 0),
        isTrue,
      );
    },
  );

  test(
    'should_skip_malformed_entry_while_keeping_valid_ones',
    () async {
      final repository = ApiRemoteLevelDefinitionRepository(
        _FakeApiClient(response: [
          {
            'number': 1000,
            // Missing 'name' -> malformed, should be skipped.
            'difficulty': 'easy',
            'definitionJson': {
              'nodes': <Object?>[],
              'edges': <Object?>[],
              'arrows': <Object?>[],
              'blockedEdges': <Object?>[],
              'metadata': <String, Object?>{},
            },
          },
          {
            'number': 1001,
            'name': 'Valid Remote Level',
            'difficulty': 'easy',
            'definitionJson': {
              'nodes': <Object?>[],
              'edges': <Object?>[],
              'arrows': <Object?>[],
              'blockedEdges': <Object?>[],
              'metadata': <String, Object?>{},
            },
          },
        ]),
      );

      final levels = await repository.fetchRemoteLevels();

      expect(levels, hasLength(1));
      expect(levels.single.number, 1001);
    },
  );

  test(
    'should_return_empty_list_when_network_call_fails',
    () async {
      final repository = ApiRemoteLevelDefinitionRepository(
        _FakeApiClient(error: Exception('network down')),
      );

      final levels = await repository.fetchRemoteLevels();

      expect(levels, isEmpty);
    },
  );

  test(
    'should_return_empty_list_when_response_shape_is_unexpected',
    () async {
      final repository = ApiRemoteLevelDefinitionRepository(
        _FakeApiClient(response: {'unexpected': 'object'}),
      );

      final levels = await repository.fetchRemoteLevels();

      expect(levels, isEmpty);
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

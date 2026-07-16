import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'manual_level_dto.dart';

/// Persists the last successfully fetched Phase 34.3 remote levels so they
/// stay playable offline. Best-effort: any read/decode failure is treated as
/// "no cache" rather than thrown, matching [RemoteLevelDefinitionRepository]'s
/// own tolerance for malformed data.
class RemoteLevelCache {
  const RemoteLevelCache();

  static const _cacheKey = 'remote_levels.cache.v1';

  Future<List<ManualLevelDto>> readCachedLevels() async {
    final preferences = await SharedPreferences.getInstance();
    final source = preferences.getString(_cacheKey);
    if (source == null) {
      return const [];
    }
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) {
        return const [];
      }
      final levels = <ManualLevelDto>[];
      for (final item in decoded) {
        if (item is! Map<String, Object?>) {
          continue;
        }
        try {
          levels.add(ManualLevelDto.fromJson(item));
        } catch (_) {
          continue;
        }
      }
      return levels;
    } catch (_) {
      return const [];
    }
  }

  Future<void> writeCachedLevels(List<ManualLevelDto> levels) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode(levels.map(_toJson).toList(growable: false));
    await preferences.setString(_cacheKey, encoded);
  }

  Map<String, Object?> _toJson(ManualLevelDto dto) {
    return {
      'number': dto.number,
      'name': dto.name,
      'difficulty': dto.difficulty,
      'definitionJson': {
        'nodes': dto.definitionJson.nodes
            .map((node) => {'id': node.id, 'x': node.x, 'y': node.y, 'z': node.z})
            .toList(growable: false),
        'edges': dto.definitionJson.edges
            .map(
              (edge) => {
                'id': edge.id,
                'fromNodeId': edge.fromNodeId,
                'toNodeId': edge.toNodeId,
              },
            )
            .toList(growable: false),
        'arrows': dto.definitionJson.arrows
            .map(
              (arrow) => {
                'id': arrow.id,
                'occupiedEdges': arrow.occupiedEdges,
                'startNodeId': arrow.startNodeId,
                'endNodeId': arrow.endNodeId,
                'direction': arrow.direction,
              },
            )
            .toList(growable: false),
        'blockedEdges': dto.definitionJson.blockedEdges,
        'metadata': dto.definitionJson.metadata,
      },
    };
  }
}

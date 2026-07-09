import 'dart:convert';

class ManualLevelCollectionDto {
  const ManualLevelCollectionDto({required this.levels});

  final List<ManualLevelDto> levels;

  factory ManualLevelCollectionDto.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Manual levels asset must be a JSON object.');
    }

    return ManualLevelCollectionDto.fromJson(decoded);
  }

  factory ManualLevelCollectionDto.fromJson(Map<String, Object?> json) {
    final levels = json['levels'];
    if (levels is! List<Object?>) {
      throw const FormatException(
        'Manual levels asset requires a levels list.',
      );
    }

    return ManualLevelCollectionDto(
      levels: levels
          .map(_requiredObject('manual level'))
          .map(ManualLevelDto.fromJson)
          .toList(growable: false),
    );
  }
}

class ManualLevelDto {
  const ManualLevelDto({
    required this.number,
    required this.name,
    required this.difficulty,
    required this.definitionJson,
  });

  final int number;
  final String name;
  final String difficulty;
  final ManualLevelDefinitionDto definitionJson;

  factory ManualLevelDto.fromJson(Map<String, Object?> json) {
    return ManualLevelDto(
      number: _requiredInt(json, 'number'),
      name: _requiredString(json, 'name'),
      difficulty: _requiredString(json, 'difficulty'),
      definitionJson: ManualLevelDefinitionDto.fromJson(
        _requiredObject('definitionJson')(json['definitionJson']),
      ),
    );
  }
}

class ManualLevelDefinitionDto {
  const ManualLevelDefinitionDto({
    required this.nodes,
    required this.edges,
    required this.arrows,
    required this.blockedEdges,
    required this.metadata,
  });

  final List<ManualGraphNodeDto> nodes;
  final List<ManualGraphEdgeDto> edges;
  final List<ManualArrowPathDto> arrows;
  final List<String> blockedEdges;
  final Map<String, Object?> metadata;

  factory ManualLevelDefinitionDto.fromJson(Map<String, Object?> json) {
    return ManualLevelDefinitionDto(
      nodes: _requiredList(json, 'nodes')
          .map(_requiredObject('node'))
          .map(ManualGraphNodeDto.fromJson)
          .toList(growable: false),
      edges: _requiredList(json, 'edges')
          .map(_requiredObject('edge'))
          .map(ManualGraphEdgeDto.fromJson)
          .toList(growable: false),
      arrows: _requiredList(json, 'arrows')
          .map(_requiredObject('arrow'))
          .map(ManualArrowPathDto.fromJson)
          .toList(growable: false),
      blockedEdges: _requiredList(
        json,
        'blockedEdges',
      ).map(_requiredStringValue('blockedEdge')).toList(growable: false),
      metadata: Map<String, Object?>.from(
        _requiredObject('metadata')(json['metadata']),
      ),
    );
  }
}

class ManualGraphNodeDto {
  const ManualGraphNodeDto({
    required this.id,
    required this.x,
    required this.y,
    this.z = 0,
  });

  final String id;
  final int x;
  final int y;

  /// Layer axis. Optional in JSON; absent means z=0 (a 2D level).
  final int z;

  factory ManualGraphNodeDto.fromJson(Map<String, Object?> json) {
    return ManualGraphNodeDto(
      id: _requiredString(json, 'id'),
      x: _requiredInt(json, 'x'),
      y: _requiredInt(json, 'y'),
      z: _optionalInt(json, 'z') ?? 0,
    );
  }
}

class ManualGraphEdgeDto {
  const ManualGraphEdgeDto({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
  });

  final String id;
  final String fromNodeId;
  final String toNodeId;

  factory ManualGraphEdgeDto.fromJson(Map<String, Object?> json) {
    return ManualGraphEdgeDto(
      id: _requiredString(json, 'id'),
      fromNodeId: _requiredString(json, 'fromNodeId'),
      toNodeId: _requiredString(json, 'toNodeId'),
    );
  }
}

class ManualArrowPathDto {
  const ManualArrowPathDto({
    required this.id,
    required this.occupiedEdges,
    required this.startNodeId,
    required this.endNodeId,
    required this.direction,
  });

  final String id;
  final List<String> occupiedEdges;
  final String startNodeId;
  final String endNodeId;
  final String direction;

  factory ManualArrowPathDto.fromJson(Map<String, Object?> json) {
    return ManualArrowPathDto(
      id: _requiredString(json, 'id'),
      occupiedEdges: _requiredList(
        json,
        'occupiedEdges',
      ).map(_requiredStringValue('occupiedEdge')).toList(growable: false),
      startNodeId: _requiredString(json, 'startNodeId'),
      endNodeId: _requiredString(json, 'endNodeId'),
      direction: _requiredString(json, 'direction'),
    );
  }
}

List<Object?> _requiredList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('Required list key "$key" is missing.');
  }
  return value;
}

Map<String, Object?> Function(Object?) _requiredObject(String label) {
  return (Object? value) {
    if (value is! Map<String, Object?>) {
      throw FormatException('Required object "$label" is missing.');
    }
    return value;
  };
}

String _requiredString(Map<String, Object?> json, String key) {
  return _requiredStringValue(key)(json[key]);
}

String Function(Object?) _requiredStringValue(String label) {
  return (Object? value) {
    if (value is! String || value.isEmpty) {
      throw FormatException('Required string "$label" is missing.');
    }
    return value;
  };
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Required integer "$key" is missing.');
  }
  return value;
}

int? _optionalInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! int) {
    throw FormatException('Optional integer "$key" must be an int.');
  }
  return value;
}

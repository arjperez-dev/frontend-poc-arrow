import '../infrastructure/manual_level_dto.dart';

/// Read-only fetch of additional, real, playable levels served by the
/// backend (Phase 34.1 contract: `number >= 1000`). No merge into the
/// playable level list happens here (34.4's concern) — this port only
/// produces validated [ManualLevelDto] objects.
abstract interface class RemoteLevelDefinitionRepository {
  Future<List<ManualLevelDto>> fetchRemoteLevels();
}

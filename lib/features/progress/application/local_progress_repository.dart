import '../domain/local_progress.dart';

abstract interface class LocalProgressRepository {
  Future<LocalProgress> getProgress();

  Future<void> saveProgress(LocalProgress progress);

  Future<void> resetProgress();

  Future<String?> getLastSyncedUserId();

  Future<void> setLastSyncedUserId(String? userId);
}

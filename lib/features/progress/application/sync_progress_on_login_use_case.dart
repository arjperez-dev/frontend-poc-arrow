import 'local_progress_repository.dart';
import 'sync_progress_use_case.dart';

/// Reconciles local progress with the newly logged-in user's remote
/// progress, guarding against leaking a different user's local unlocks.
///
/// If the previously synced user differs from [userId], local progress is
/// cleared before syncing so the new user starts from their own remote
/// state (or level 1) instead of inheriting the prior user's progress.
/// Otherwise (anonymous/guest session or same user), the existing
/// [SyncProgressUseCase] merge policy applies as-is.
class SyncProgressOnLoginUseCase {
  const SyncProgressOnLoginUseCase({
    required LocalProgressRepository localProgressRepository,
    required SyncProgressUseCase syncProgress,
  }) : _localProgressRepository = localProgressRepository,
       _syncProgress = syncProgress;

  final LocalProgressRepository _localProgressRepository;
  final SyncProgressUseCase _syncProgress;

  Future<void> call(String userId) async {
    final lastSyncedUserId = await _localProgressRepository.getLastSyncedUserId();
    if (lastSyncedUserId != null && lastSyncedUserId != userId) {
      await _localProgressRepository.resetProgress();
    }

    await _syncProgress();
    await _localProgressRepository.setLastSyncedUserId(userId);
  }
}

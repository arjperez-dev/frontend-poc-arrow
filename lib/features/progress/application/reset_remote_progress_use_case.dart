import 'local_progress_repository.dart';
import 'remote_progress_repository.dart';

class ResetRemoteProgressUseCase {
  const ResetRemoteProgressUseCase({
    required RemoteProgressRepository remoteProgressRepository,
    required LocalProgressRepository localProgressRepository,
  }) : _remoteProgressRepository = remoteProgressRepository,
       _localProgressRepository = localProgressRepository;

  final RemoteProgressRepository _remoteProgressRepository;
  final LocalProgressRepository _localProgressRepository;

  Future<void> call() async {
    await _remoteProgressRepository.resetProgress();
    await _localProgressRepository.resetProgress();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';
import 'package:frontend_poc_arrow/features/leaderboard/application/get_leaderboard_for_level_number_use_case.dart';
import 'package:frontend_poc_arrow/features/leaderboard/application/leaderboard_repository.dart';
import 'package:frontend_poc_arrow/features/leaderboard/domain/leaderboard_entry.dart';
import 'package:frontend_poc_arrow/features/leaderboard/presentation/leaderboard_screen.dart';
import 'package:frontend_poc_arrow/features/progress/application/remote_level_repository.dart';

void main() {
  test('should_fetch_leaderboard_when_level_number_maps_to_backend_id',
      () async {
    final repository = _FakeLeaderboardRepository(
      entriesByLevelId: {
        'remote-level-1': const [
          LeaderboardEntry(
            id: 'entry-1',
            levelId: 'remote-level-1',
            displayName: 'Ada',
            score: 990,
            moves: 2,
            timeSeconds: 0,
          ),
        ],
      },
    );
    final useCase = GetLeaderboardForLevelNumberUseCase(
      leaderboardRepository: repository,
      remoteLevelRepository: _FakeRemoteLevelRepository(),
    );

    final entries = await useCase(1);

    expect(entries, hasLength(1));
    expect(entries.single.displayName, 'Ada');
    expect(repository.requestedLevelId, 'remote-level-1');
  });

  test('should_return_empty_when_level_number_has_no_backend_mapping',
      () async {
    final repository = _FakeLeaderboardRepository(entriesByLevelId: const {});
    final useCase = GetLeaderboardForLevelNumberUseCase(
      leaderboardRepository: repository,
      remoteLevelRepository: _FakeRemoteLevelRepository(),
    );

    final entries = await useCase(99);

    expect(entries, isEmpty);
    expect(repository.requestedLevelId, isNull,
        reason: 'leaderboard must not be queried without a backend id');
  });

  testWidgets('should_render_injected_entries_without_touching_network',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LeaderboardScreen(
          levelNumber: 1,
          loadEntries: (_) async => const [
            LeaderboardEntry(
              id: 'entry-1',
              levelId: 'remote-level-1',
              displayName: 'Ada',
              score: 990,
              moves: 2,
              timeSeconds: 0,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('990'), findsOneWidget);
  });
}

class _FakeRemoteLevelRepository implements RemoteLevelRepository {
  @override
  Future<Map<int, String>> getLevelIdsByNumber() async {
    return const {1: 'remote-level-1'};
  }
}

class _FakeLeaderboardRepository implements LeaderboardRepository {
  _FakeLeaderboardRepository({required this.entriesByLevelId});

  final Map<String, List<LeaderboardEntry>> entriesByLevelId;
  String? requestedLevelId;

  @override
  Future<List<LeaderboardEntry>> getForLevel(String levelId) async {
    requestedLevelId = levelId;
    return entriesByLevelId[levelId] ?? const <LeaderboardEntry>[];
  }

  @override
  Future<void> submitScore({
    required String levelId,
    required int score,
    required int moves,
    required int timeSeconds,
  }) async {}
}

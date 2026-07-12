import 'package:flutter/material.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';

import '../../../core/app/app_settings_scope.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/game_route_args.dart';
import '../../../core/theme/app_theme.dart';
import '../../challenges/domain/challenge.dart';
import '../../challenges/infrastructure/challenge_dependencies.dart';
import '../../game/domain/level.dart';
import '../../game/infrastructure/local_level_dependencies.dart';
import '../../game/presentation/game_ui_keys.dart';
import '../../game/presentation/level_mode_filter.dart';
import '../../progress/domain/local_progress.dart';
import '../../progress/infrastructure/local_progress_dependencies.dart';
import '../../settings/domain/game_mode.dart';

typedef LoadLocalLevels = Future<List<Level>> Function();
typedef LoadLocalProgress = Future<LocalProgress> Function();
typedef LoadChallengeRecords =
    Future<Map<int, int>> Function(Challenge challenge);

class LevelSelectionScreen extends StatefulWidget {
  const LevelSelectionScreen({
    this.loadLevels,
    this.loadProgress,
    this.loadChallengeRecords,
    this.challenge,
    super.key,
  });

  final LoadLocalLevels? loadLevels;
  final LoadLocalProgress? loadProgress;
  final LoadChallengeRecords? loadChallengeRecords;

  /// When set, opening a level starts it with this challenge modifier.
  /// Level filtering and unlocking are unchanged (same locks as campaign),
  /// but the score shown per card is the CHALLENGE best — or nothing at all
  /// for levels not yet played in this challenge (never the campaign best).
  final Challenge? challenge;

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen> {
  late Future<_LevelSelectionData> _screenDataFuture;

  @override
  void initState() {
    super.initState();
    _screenDataFuture = _loadScreenData();
  }

  Future<_LevelSelectionData> _loadScreenData() async {
    final loadLevels =
        widget.loadLevels ??
        LocalLevelDependencies.createGetLocalLevelsUseCase().call;
    final loadProgress =
        widget.loadProgress ??
        (await LocalProgressDependencies.createGetLocalProgressUseCase()).call;

    final challenge = widget.challenge;
    Map<int, int>? challengeRecords;
    if (challenge != null) {
      final loadRecords =
          widget.loadChallengeRecords ??
          (await ChallengeDependencies.createGetChallengeRecordsUseCase()).call;
      challengeRecords = await loadRecords(challenge);
    }

    return _LevelSelectionData(
      levels: await loadLevels(),
      progress: await loadProgress(),
      challengeRecords: challengeRecords,
    );
  }

  void _retry() {
    setState(() {
      _screenDataFuture = _loadScreenData();
    });
  }

  /// Opens a level and refreshes progress when control returns — covers the
  /// in-app button, the app-bar back arrow, and the Android system back button,
  /// since `Navigator.push` completes on any pop.
  Future<void> _openLevel(BuildContext context, int? levelNumber) async {
    final challenge = widget.challenge;
    await Navigator.of(context).pushNamed(
      AppRoutes.game,
      arguments: challenge == null
          ? levelNumber
          : GameRouteArgs(levelNumber: levelNumber, challenge: challenge),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _screenDataFuture = _loadScreenData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final gameMode =
        AppSettingsScope.maybeOf(context)?.gameMode ?? GameMode.twoD;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.levels)),
      body: SafeArea(
        child: FutureBuilder<_LevelSelectionData>(
          future: _screenDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _LoadingState(message: localizations.loadingLevel);
            }

            if (snapshot.hasError) {
              return _ErrorState(onRetry: _retry);
            }

            final screenData =
                snapshot.data ??
                _LevelSelectionData(
                  levels: const <Level>[],
                  progress: LocalProgress.initial(),
                );
            final levels = filterLevelsByGameMode(
              screenData.levels,
              wantThreeD: gameMode == GameMode.threeD,
            );
            final progress = screenData.progress;
            final challenge = widget.challenge;
            final levelList = ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: levels.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final level = levels[index];
                final levelNumber = level.number ?? 0;
                final isUnlocked = isLevelUnlockedForMode(
                  progress,
                  levelNumber,
                  gameMode,
                );
                return _LevelCard(
                  level: level,
                  displayNumber: displayNumberFor(levelNumber, gameMode),
                  isUnlocked: isUnlocked,
                  isCompleted: progress.isCompleted(levelNumber),
                  // Challenge mode shows the CHALLENGE best (or nothing when
                  // this level hasn't been played in this challenge yet) —
                  // never the campaign best.
                  bestScore: challenge == null
                      ? progress.bestResultFor(levelNumber)?.score
                      : screenData.challengeRecords?[levelNumber],
                  isChallengeBest: challenge != null,
                  onTap: isUnlocked
                      ? () => _openLevel(context, level.number)
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(localizations.levelLocked)),
                          );
                        },
                );
              },
            );
            if (challenge == null) {
              return levelList;
            }
            // Challenge banner: which modifier the picked level will run.
            final challengeName = switch (challenge) {
              Challenge.timeAttack => localizations.challengeTimeAttack,
              Challenge.moveLimit => localizations.challengeMoveLimit,
              Challenge.perfectRun => localizations.challengePerfectRun,
            };
            return Column(
              children: [
                Container(
                  key: GameUiKeys.challengeBanner,
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.neonPink.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.neonPink.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    '${localizations.challenges}: $challengeName',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.softText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(child: levelList),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LevelSelectionData {
  const _LevelSelectionData({
    required this.levels,
    required this.progress,
    this.challengeRecords,
  });

  /// Best score per level for the active challenge; null in campaign mode.
  final Map<int, int>? challengeRecords;

  final List<Level> levels;
  final LocalProgress progress;
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.displayNumber,
    required this.isUnlocked,
    required this.isCompleted,
    required this.bestScore,
    this.isChallengeBest = false,
    required this.onTap,
  });

  final Level level;
  final int displayNumber;
  final bool isUnlocked;
  final bool isCompleted;
  final int? bestScore;

  /// Labels [bestScore] as the challenge best instead of the campaign best.
  final bool isChallengeBest;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final number = level.number ?? 0;
    final difficulty = level.metadata['difficulty']?.toString() ?? '-';
    final localizations = AppLocalizations.of(context);
    final status = isCompleted
        ? localizations.completed
        : isUnlocked
        ? localizations.unlocked
        : localizations.locked;
    final accent = isCompleted
        ? AppTheme.neonMint
        : isUnlocked
        ? AppTheme.pastelAmber
        : AppTheme.mutedText;

    return Card(
      key: GameUiKeys.levelCard(number),
      color: isUnlocked ? null : AppTheme.surface.withValues(alpha: 0.58),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$displayNumber',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ).copyWith(color: accent),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level $displayNumber',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.softText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      difficulty.toUpperCase(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.pastelAmber,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      bestScore == null
                          ? status
                          : isChallengeBest
                          ? '$status - ${localizations.challengeBest}: $bestScore'
                          : '$status - ${localizations.bestScore}: $bestScore',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isUnlocked ? Icons.chevron_right_rounded : Icons.lock_rounded,
                color: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  localizations.levelNotFound,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onRetry,
                  child: Text(localizations.retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

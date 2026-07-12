import 'package:flutter/material.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';

import '../../../core/app/app_settings_scope.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../game/domain/level.dart';
import '../../game/infrastructure/local_level_dependencies.dart';
import '../../game/presentation/game_ui_keys.dart';
import '../../game/presentation/level_mode_filter.dart';
import '../../progress/domain/local_progress.dart';
import '../../progress/infrastructure/local_progress_dependencies.dart';
import '../../settings/domain/game_mode.dart';

typedef LoadLocalLevels = Future<List<Level>> Function();
typedef LoadLocalProgress = Future<LocalProgress> Function();

class LevelSelectionScreen extends StatefulWidget {
  const LevelSelectionScreen({this.loadLevels, this.loadProgress, super.key});

  final LoadLocalLevels? loadLevels;
  final LoadLocalProgress? loadProgress;

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

    return _LevelSelectionData(
      levels: await loadLevels(),
      progress: await loadProgress(),
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
    await Navigator.of(
      context,
    ).pushNamed(AppRoutes.game, arguments: levelNumber);
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
            return ListView.separated(
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
                  bestScore: progress.bestResultFor(levelNumber)?.score,
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
          },
        ),
      ),
    );
  }
}

class _LevelSelectionData {
  const _LevelSelectionData({required this.levels, required this.progress});

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
    required this.onTap,
  });

  final Level level;
  final int displayNumber;
  final bool isUnlocked;
  final bool isCompleted;
  final int? bestScore;
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

import 'package:flutter/material.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';
import '../../audio/application/background_music_controller.dart';
import '../../../core/app/app_settings_scope.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/game_route_args.dart';
import '../../../core/theme/app_theme.dart';
import '../../audio/infrastructure/audio_manager.dart';
import '../../challenges/domain/challenge.dart';
import '../../challenges/infrastructure/challenge_dependencies.dart';
import '../../settings/domain/game_mode.dart';
import '../application/level_progression.dart';
import '../domain/game_session.dart';
import '../domain/level.dart';
import '../infrastructure/local_level_dependencies.dart';
import '../../progress/infrastructure/local_progress_dependencies.dart';
import 'game_screen_controller.dart';
import 'game_ui_keys.dart';
import 'level_mode_filter.dart';
import 'widgets/graph_board.dart';
import 'widgets/graph_3d_board.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.levelNumber,
    this.challenge,
    this.loadLevelByNumber,
    this.loadLevels,
    this.saveLevelCompletion,
    this.notifyRemoteLevelCompletion,
    this.getBestLevelResult,
    this.playGameAudio,
    this.backgroundMusicController,
    this.saveChallengeRecord,
    this.getChallengeBestScore,
    this.enableBoardAnimations = true,
    super.key,
  });

  final int? levelNumber;

  /// Active challenge modifier, or null for normal campaign play.
  final Challenge? challenge;

  final LoadLevelByNumber? loadLevelByNumber;

  /// Loads the full level list so the screen can place the current level in
  /// its mode's complexity-sorted [LevelProgression] (display number in the
  /// app bar, next level on victory). Best-effort: when it fails, the screen
  /// falls back to internal-number ordering.
  final Future<List<Level>> Function()? loadLevels;

  final SaveLevelCompletion? saveLevelCompletion;
  final NotifyRemoteLevelCompletion? notifyRemoteLevelCompletion;
  final GetBestLevelResult? getBestLevelResult;
  final PlayGameAudio? playGameAudio;
  final BackgroundMusicController? backgroundMusicController;
  final SaveChallengeRecord? saveChallengeRecord;
  final GetChallengeBestScore? getChallengeBestScore;

  /// When false (widget tests), the board renders resolved state without
  /// starting animation tickers, and the Time Attack clock does not run on a
  /// real Timer (tests drive it via [GameScreenController.advanceClock]).
  final bool enableBoardAnimations;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameScreenController? _controller;

  // Complexity-sorted progression of the played level's OWN mode (2D or 3D,
  // partitioned by the level itself, never mixed). Null until loaded or when
  // the level list can't be loaded — display then falls back to the
  // arithmetic internal-number mapping.
  LevelProgression? _progression;
  // Only set when a [BackgroundMusicController] is injected (tests). In
  // production music is owned by the app-lifetime [AudioManager] singleton,
  // so there's nothing screen-local to stop/dispose for it.
  BackgroundMusicController? _injectedMusicController;
  bool _ownsMusicLifecycle = false;

  // While a finger is touching the board, the page must not scroll — an
  // ancestor ListView competing for the same pointers is what makes
  // pinch-to-zoom on the board feel unresponsive (see GraphBoard's
  // onInteractionActiveChanged doc comment).
  bool _lockPageScroll = false;

  @override
  void initState() {
    super.initState();
    _createController();
  }

  Future<void> _createController() async {
    final challenge = widget.challenge;
    final controller = GameScreenController(
      levelNumber: widget.levelNumber,
      loadLevelByNumber:
          widget.loadLevelByNumber ??
          (await LocalLevelDependencies.createGetLocalLevelByNumberUseCase())
              .call,
      saveLevelCompletion:
          widget.saveLevelCompletion ??
          (await LocalProgressDependencies.createSaveLevelCompletionUseCase())
              .call,
      notifyRemoteLevelCompletion:
          widget.notifyRemoteLevelCompletion ??
          (await LocalProgressDependencies.createNotifyRemoteLevelCompletionUseCase())
              .call,
      getBestLevelResult:
          widget.getBestLevelResult ??
          (await LocalProgressDependencies.createGetBestLevelResultUseCase())
              .call,
      playGameAudio:
          widget.playGameAudio ?? AudioManager.instance.playGameAudio,
      challenge: challenge,
      saveChallengeRecord: challenge == null
          ? null
          : widget.saveChallengeRecord ??
                (await ChallengeDependencies.createSaveChallengeRecordUseCase())
                    .call,
      getChallengeBestScore: challenge == null
          ? null
          : widget.getChallengeBestScore ?? await _productionChallengeBest(),
      enableChallengeTimer: widget.enableBoardAnimations,
    );
    if (!mounted) {
      controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
    });

    final injectedMusicController = widget.backgroundMusicController;
    if (injectedMusicController != null) {
      if (!mounted) {
        await injectedMusicController.stop();
      } else {
        _injectedMusicController = injectedMusicController;
        await injectedMusicController.start();
      }
    } else if (widget.enableBoardAnimations) {
      _ownsMusicLifecycle = true;
      if (mounted) {
        await AudioManager.instance.startMusic();
      }
    }

    await controller.load();
    await _loadProgression(controller);
  }

  /// Builds the progression for the played level's own mode. Best-effort:
  /// a failure leaves `_progression` null and the screen on the
  /// internal-number fallback — gameplay itself is unaffected.
  Future<void> _loadProgression(GameScreenController controller) async {
    final level = controller.level;
    if (level == null) {
      return;
    }
    try {
      final loadLevels =
          widget.loadLevels ??
          (await LocalLevelDependencies.createGetLocalLevelsUseCase()).call;
      final allLevels = await loadLevels();
      final sameModeLevels = filterLevelsByGameMode(
        allLevels,
        wantThreeD: isThreeDLevel(level),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _progression = LevelProgression.fromLevels(sameModeLevels);
      });
    } catch (_) {
      // Fall back to internal-number ordering.
    }
  }

  static Future<GetChallengeBestScore> _productionChallengeBest() async {
    final getRecords =
        await ChallengeDependencies.createGetChallengeRecordsUseCase();
    return (Challenge challenge, int levelNumber) async {
      final records = await getRecords(challenge);
      return records[levelNumber];
    };
  }

  @override
  void dispose() {
    if (_injectedMusicController != null) {
      _injectedMusicController!.stop();
    } else if (_ownsMusicLifecycle) {
      AudioManager.instance.stopMusic();
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      final localizations = AppLocalizations.of(context);
      return Scaffold(
        appBar: AppBar(title: Text(localizations.loadingLevel)),
        body: SafeArea(
          child: _LoadingState(message: localizations.loadingLevel),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final navigator = Navigator.of(context);
        await controller.completionSettled;
        if (!mounted) {
          return;
        }
        navigator.pop(result);
      },
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final localizations = AppLocalizations.of(context);
          final gameMode =
              AppSettingsScope.maybeOf(context)?.gameMode ?? GameMode.twoD;
          final internalNumber = controller.level?.number;
          final progression = _progression;
          // The progression drives display number and next level only when
          // it actually contains the played level; otherwise (not loaded,
          // failed to load, or a level outside the loaded list) everything
          // falls back to the arithmetic internal-number mapping.
          final inProgression = internalNumber != null &&
              progression?.displayNumberOf(internalNumber) != null;
          final title = internalNumber == null
              ? localizations.loadingLevel
              : inProgression
              ? 'Level ${progression!.displayNumberOf(internalNumber)}'
              : 'Level ${displayNumberFor(internalNumber, gameMode)}';

          // Next level follows the sorted progression (easiest → hardest),
          // not internal-number order. Fallback mirrors the pre-resequencing
          // behavior.
          final nextInternal = internalNumber == null
              ? null
              : inProgression
              ? progression!.nextInternalAfter(internalNumber)
              : hasNextLevelFor(internalNumber, gameMode)
              ? internalNumber + 1
              : null;
          final nextDisplayNumber = nextInternal == null
              ? 0
              : inProgression
              ? progression!.displayNumberOf(nextInternal) ??
                    displayNumberFor(nextInternal, gameMode)
              : displayNumberFor(nextInternal, gameMode);

          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: SafeArea(
              child: switch (controller.loadState) {
                GameScreenLoadState.loading => _LoadingState(
                  message: localizations.loadingLevel,
                ),
                GameScreenLoadState.notFound => _LevelNotFoundState(
                  onBackToLevels: _backToLevels,
                ),
                GameScreenLoadState.failed => _LevelNotFoundState(
                  onBackToLevels: _backToLevels,
                ),
                GameScreenLoadState.ready => _GameReadyView(
                  controller: controller,
                  hasNextLevel: nextInternal != null,
                  nextLevelDisplayNumber: nextDisplayNumber,
                  animateBoard: widget.enableBoardAnimations,
                  onBackToLevels: _backToLevels,
                  onNextLevel: _openNextLevel,
                  onOpenLeaderboard: _openLeaderboard,
                  lockPageScroll: _lockPageScroll,
                  onBoardInteractionActiveChanged: (active) {
                    if (active != _lockPageScroll) {
                      setState(() => _lockPageScroll = active);
                    }
                  },
                ),
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _backToLevels() async {
    final navigator = Navigator.of(context);
    final challenge = widget.challenge;
    await _controller?.completionSettled;
    if (!mounted) {
      return;
    }
    navigator.pushNamedAndRemoveUntil(
      AppRoutes.levels,
      (route) => route.settings.name == AppRoutes.home,
      arguments: challenge,
    );
  }

  Future<void> _openNextLevel() async {
    final navigator = Navigator.of(context);
    final currentNumber = _controller?.level?.number ?? 0;
    // Progression order (easiest → hardest), falling back to internal-number
    // order when the progression isn't available.
    final nextLevelNumber =
        _progression?.nextInternalAfter(currentNumber) ?? (currentNumber + 1);
    final challenge = widget.challenge;
    await _controller?.completionSettled;
    if (!mounted) {
      return;
    }
    navigator.pushReplacementNamed(
      AppRoutes.game,
      arguments: challenge == null
          ? nextLevelNumber
          : GameRouteArgs(levelNumber: nextLevelNumber, challenge: challenge),
    );
  }

  void _openLeaderboard() {
    final levelNumber = _controller?.level?.number;
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.leaderboard, arguments: levelNumber);
  }
}

// ---------------------------------------------------------------------------
// Game ready view — board + HUD + overlays
// ---------------------------------------------------------------------------

class _GameReadyView extends StatelessWidget {
  const _GameReadyView({
    required this.controller,
    required this.hasNextLevel,
    required this.nextLevelDisplayNumber,
    required this.animateBoard,
    required this.onBackToLevels,
    required this.onNextLevel,
    required this.onOpenLeaderboard,
    required this.lockPageScroll,
    required this.onBoardInteractionActiveChanged,
  });

  final GameScreenController controller;

  /// Computed by [GameScreen] from the mode's complexity-sorted progression
  /// (with an internal-number fallback while it loads).
  final bool hasNextLevel;
  final int nextLevelDisplayNumber;

  final bool animateBoard;
  final VoidCallback onBackToLevels;
  final VoidCallback onNextLevel;
  final VoidCallback onOpenLeaderboard;

  /// When true, an in-progress touch on the board means the page itself must
  /// not scroll (see GameScreen's `_lockPageScroll` doc comment).
  final bool lockPageScroll;
  final ValueChanged<bool> onBoardInteractionActiveChanged;

  @override
  Widget build(BuildContext context) {
    final session = controller.session!;
    final level = controller.level!;
    final localizations = AppLocalizations.of(context);

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(20),
          physics: lockPageScroll
              ? const NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
          children: [
            _GameHud(session: session, controller: controller),
            const SizedBox(height: 18),
            if (level.boardGraph.isMultiLayer)
              Graph3DBoard(
                session: session,
                lastActivatedArrowId: controller.lastActivatedArrowId,
                flashingArrowId: controller.flashingArrowId,
                animate: animateBoard,
                onArrowActivated: controller.activateArrow,
                onInteractionActiveChanged: onBoardInteractionActiveChanged,
              )
            else
              GraphBoard(
                session: session,
                lastActivatedArrowId: null,
                flashingArrowId: controller.flashingArrowId,
                animate: animateBoard,
                onArrowActivated: controller.activateArrow,
                onInteractionActiveChanged: onBoardInteractionActiveChanged,
              ),
            const SizedBox(height: 18),
            if (!controller.isVictory && !controller.isGameOver)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: GameUiKeys.backToLevelsButton,
                      onPressed: onBackToLevels,
                      child: Text(localizations.backToLevels),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: GameUiKeys.retryButton,
                      onPressed: controller.restart,
                      child: Text(localizations.retry),
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (controller.isVictory)
          _VictoryOverlay(
            score: session.score.value,
            moves: session.movesCount,
            bestScore: controller.challenge == null
                ? controller.bestResult?.score
                : controller.challengeBestScore,
            isChallenge: controller.challenge != null,
            isNewChallengeRecord: controller.isNewChallengeRecord,
            hasNextLevel: hasNextLevel,
            nextLevelDisplayNumber: nextLevelDisplayNumber,
            onRetry: controller.restart,
            onBackToLevels: onBackToLevels,
            onNextLevel: onNextLevel,
            onOpenLeaderboard: onOpenLeaderboard,
          )
        else if (controller.isGameOver)
          _GameOverOverlay(
            score: session.score.value,
            mistakes: session.mistakeCount,
            challengeFailReason: controller.challengeFailReason,
            onRetry: controller.restart,
            onBackToLevels: onBackToLevels,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// HUD — moves, score, lives
// ---------------------------------------------------------------------------

class _GameHud extends StatelessWidget {
  const _GameHud({required this.session, required this.controller});

  final GameSession session;
  final GameScreenController controller;

  String _formatClock(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    // Challenge chip: one extra stat that names the active constraint.
    final (String, String)? challengeStat = switch (controller.challenge) {
      Challenge.timeAttack => (
        localizations.timeLeft,
        _formatClock(controller.remainingSeconds ?? 0),
      ),
      Challenge.moveLimit => (
        localizations.movesLeft,
        '${controller.remainingMoves ?? 0}',
      ),
      Challenge.perfectRun => (localizations.flawless, '✓'),
      null => null,
    };

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            key: GameUiKeys.movesLabel,
            label: localizations.moves,
            value: '${session.movesCount}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            key: GameUiKeys.scoreLabel,
            label: localizations.score,
            value: '${session.score.value}',
          ),
        ),
        if (challengeStat != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              key: GameUiKeys.challengeStatChip,
              label: challengeStat.$1,
              value: challengeStat.$2,
            ),
          ),
        ] else ...[
          // Hearts are campaign-only: a challenge is judged by its own
          // constraint (clock / budget / flawlessness), so the HUD shows the
          // challenge stat in place of the lives card.
          const SizedBox(width: 8),
          _LivesCard(key: GameUiKeys.livesLabel, lives: session.livesRemaining),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}

class _LivesCard extends StatelessWidget {
  const _LivesCard({required this.lives, super.key});

  final int lives;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          children: [
            Text(
              AppLocalizations.of(context).lives,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final filled = i < lives;
                return Icon(
                  filled ? Icons.favorite : Icons.favorite_border,
                  color: filled ? Colors.redAccent : Colors.grey,
                  size: 20,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Victory overlay
// ---------------------------------------------------------------------------

class _VictoryOverlay extends StatelessWidget {
  const _VictoryOverlay({
    required this.score,
    required this.moves,
    required this.bestScore,
    required this.isChallenge,
    required this.isNewChallengeRecord,
    required this.hasNextLevel,
    required this.nextLevelDisplayNumber,
    required this.onRetry,
    required this.onBackToLevels,
    required this.onNextLevel,
    required this.onOpenLeaderboard,
  });

  final int score;
  final int moves;
  final int? bestScore;

  /// Challenge victories show the challenge best and hide the leaderboard
  /// (challenge results never touch the campaign leaderboard, by design).
  final bool isChallenge;
  final bool isNewChallengeRecord;

  final bool hasNextLevel;
  final int nextLevelDisplayNumber;
  final VoidCallback onRetry;
  final VoidCallback onBackToLevels;
  final VoidCallback onNextLevel;
  final VoidCallback onOpenLeaderboard;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Positioned.fill(
      child: ColoredBox(
        color: AppTheme.background.withValues(alpha: 0.78),
        child: Center(
          child: Card(
            key: GameUiKeys.victoryCard,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    localizations.victory,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontFamily: 'PixelGame', fontSize: 30),
                  ),
                  const SizedBox(height: 12),
                  if (isChallenge && isNewChallengeRecord)
                    Text(
                      localizations.newRecord,
                      style: const TextStyle(
                        color: AppTheme.neonMint,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  Text('${localizations.score}: $score'),
                  Text('${localizations.moves}: $moves'),
                  if (bestScore != null)
                    Text(
                      isChallenge
                          ? '${localizations.challengeBest}: $bestScore'
                          : '${localizations.bestScore}: $bestScore',
                    ),
                  const SizedBox(height: 18),
                  FilledButton(
                    key: GameUiKeys.retryButton,
                    onPressed: onRetry,
                    child: Text(localizations.retry),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    key: GameUiKeys.backToLevelsButton,
                    onPressed: onBackToLevels,
                    child: Text(localizations.backToLevels),
                  ),
                  if (!isChallenge) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      key: GameUiKeys.leaderboardButton,
                      onPressed: onOpenLeaderboard,
                      child: Text(localizations.leaderboard),
                    ),
                  ],
                  if (hasNextLevel) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      key: GameUiKeys.nextLevelButton,
                      onPressed: onNextLevel,
                      child: Text(
                        '${localizations.nextLevel}: $nextLevelDisplayNumber',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Game-over overlay
// ---------------------------------------------------------------------------

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({
    required this.score,
    required this.mistakes,
    required this.challengeFailReason,
    required this.onRetry,
    required this.onBackToLevels,
  });

  final int score;
  final int mistakes;

  /// Non-null when a challenge caused the failure — selects a specific
  /// message (time up / out of moves / broken perfect run).
  final ChallengeFailReason? challengeFailReason;

  final VoidCallback onRetry;
  final VoidCallback onBackToLevels;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final message = switch (challengeFailReason) {
      ChallengeFailReason.timeUp => localizations.challengeFailedTimeUp,
      ChallengeFailReason.outOfMoves =>
        localizations.challengeFailedOutOfMoves,
      ChallengeFailReason.mistake => localizations.challengeFailedMistake,
      ChallengeFailReason.livesOut || null => localizations.gameOverMessage,
    };

    return Positioned.fill(
      child: ColoredBox(
        color: AppTheme.background.withValues(alpha: 0.82),
        child: Center(
          child: Card(
            key: GameUiKeys.gameOverCard,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    localizations.gameOver,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontFamily: 'PixelGame', fontSize: 30),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text('${localizations.score}: $score'),
                  Text('${localizations.mistakes}: $mistakes'),
                  const SizedBox(height: 18),
                  FilledButton(
                    key: GameUiKeys.retryButton,
                    onPressed: onRetry,
                    child: Text(localizations.retry),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    key: GameUiKeys.backToLevelsButton,
                    onPressed: onBackToLevels,
                    child: Text(localizations.backToLevels),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading / not-found states
// ---------------------------------------------------------------------------

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

class _LevelNotFoundState extends StatelessWidget {
  const _LevelNotFoundState({required this.onBackToLevels});

  final VoidCallback onBackToLevels;

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
                  key: GameUiKeys.backToLevelsButton,
                  onPressed: onBackToLevels,
                  child: Text(localizations.backToLevels),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

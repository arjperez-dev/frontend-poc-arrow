import 'package:flutter/material.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/game_session.dart';
import '../infrastructure/local_level_dependencies.dart';
import 'game_screen_controller.dart';
import 'game_ui_keys.dart';
import 'widgets/graph_board.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.levelNumber,
    this.loadLevelByNumber,
    super.key,
  });

  final int? levelNumber;
  final LoadLevelByNumber? loadLevelByNumber;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameScreenController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GameScreenController(
      levelNumber: widget.levelNumber,
      loadLevelByNumber:
          widget.loadLevelByNumber ??
          LocalLevelDependencies.createGetLocalLevelByNumberUseCase().call,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final localizations = AppLocalizations.of(context);

        return Scaffold(
          appBar: AppBar(
            title: Text(_controller.level?.name ?? localizations.loadingLevel),
          ),
          body: SafeArea(
            child: switch (_controller.loadState) {
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
                controller: _controller,
                onBackToLevels: _backToLevels,
                onNextLevel: _openNextLevel,
              ),
            },
          ),
        );
      },
    );
  }

  void _backToLevels() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.levels,
      (route) => route.settings.name == AppRoutes.home,
    );
  }

  void _openNextLevel() {
    final nextLevelNumber = (_controller.level?.number ?? 0) + 1;
    Navigator.of(
      context,
    ).pushReplacementNamed(AppRoutes.game, arguments: nextLevelNumber);
  }
}

class _GameReadyView extends StatelessWidget {
  const _GameReadyView({
    required this.controller,
    required this.onBackToLevels,
    required this.onNextLevel,
  });

  final GameScreenController controller;
  final VoidCallback onBackToLevels;
  final VoidCallback onNextLevel;

  @override
  Widget build(BuildContext context) {
    final session = controller.session!;
    final level = controller.level!;
    final localizations = AppLocalizations.of(context);

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _GameStats(session: session),
            const SizedBox(height: 18),
            GraphBoard(
              session: session,
              lastActivatedArrowId: null,
              onArrowActivated: controller.activateArrow,
            ),
            const SizedBox(height: 18),
            if (!controller.isVictory)
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
            hasNextLevel: (level.number ?? 15) < 15,
            onRetry: controller.restart,
            onBackToLevels: onBackToLevels,
            onNextLevel: onNextLevel,
          ),
      ],
    );
  }
}

class _GameStats extends StatelessWidget {
  const _GameStats({required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            key: GameUiKeys.movesLabel,
            label: localizations.moves,
            value: '${session.movesCount}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            key: GameUiKeys.scoreLabel,
            label: localizations.score,
            value: '${session.score.value}',
          ),
        ),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}

class _VictoryOverlay extends StatelessWidget {
  const _VictoryOverlay({
    required this.score,
    required this.moves,
    required this.hasNextLevel,
    required this.onRetry,
    required this.onBackToLevels,
    required this.onNextLevel,
  });

  final int score;
  final int moves;
  final bool hasNextLevel;
  final VoidCallback onRetry;
  final VoidCallback onBackToLevels;
  final VoidCallback onNextLevel;

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
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text('${localizations.score}: $score'),
                  Text('${localizations.moves}: $moves'),
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
                  if (hasNextLevel) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      key: GameUiKeys.nextLevelButton,
                      onPressed: onNextLevel,
                      child: Text(localizations.nextLevel),
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

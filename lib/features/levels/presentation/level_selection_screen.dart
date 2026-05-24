import 'package:flutter/material.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../game/domain/level.dart';
import '../../game/infrastructure/local_level_dependencies.dart';
import '../../game/presentation/game_ui_keys.dart';

typedef LoadLocalLevels = Future<List<Level>> Function();

class LevelSelectionScreen extends StatefulWidget {
  const LevelSelectionScreen({this.loadLevels, super.key});

  final LoadLocalLevels? loadLevels;

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen> {
  late Future<List<Level>> _levelsFuture;

  @override
  void initState() {
    super.initState();
    _levelsFuture = _loadLevels();
  }

  Future<List<Level>> _loadLevels() {
    final loadLevels =
        widget.loadLevels ??
        LocalLevelDependencies.createGetLocalLevelsUseCase().call;
    return loadLevels();
  }

  void _retry() {
    setState(() {
      _levelsFuture = _loadLevels();
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.levels)),
      body: SafeArea(
        child: FutureBuilder<List<Level>>(
          future: _levelsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _LoadingState(message: localizations.loadingLevel);
            }

            if (snapshot.hasError) {
              return _ErrorState(onRetry: _retry);
            }

            final levels = snapshot.data ?? const <Level>[];
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: levels.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final level = levels[index];
                return _LevelCard(
                  level: level,
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.game, arguments: level.number),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.level, required this.onTap});

  final Level level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final number = level.number ?? 0;
    final difficulty = level.metadata['difficulty']?.toString() ?? '-';

    return Card(
      key: GameUiKeys.levelCard(number),
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
                  color: AppTheme.neonMint.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.neonMint.withValues(alpha: 0.35),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: AppTheme.neonMint,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.name,
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
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.neonMint),
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

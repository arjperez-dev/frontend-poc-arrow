import 'package:flutter/material.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../game/domain/level.dart';
import '../../game/infrastructure/local_level_dependencies.dart';
import '../../game/presentation/game_ui_keys.dart';

typedef LoadLocalLevels = Future<List<Level>> Function();

/// Entry point for the main-menu "Leaderboard" button. The backend only
/// exposes a per-level leaderboard (`GET /leaderboard/:levelId`), so this
/// screen lets the player pick which level's leaderboard to view instead of
/// pushing [AppRoutes.leaderboard] with no argument (which renders empty).
class LeaderboardLevelPickerScreen extends StatefulWidget {
  const LeaderboardLevelPickerScreen({this.loadLevels, super.key});

  final LoadLocalLevels? loadLevels;

  @override
  State<LeaderboardLevelPickerScreen> createState() =>
      _LeaderboardLevelPickerScreenState();
}

class _LeaderboardLevelPickerScreenState
    extends State<LeaderboardLevelPickerScreen> {
  late final Future<List<Level>> _levelsFuture = _loadLevels();

  Future<List<Level>> _loadLevels() {
    final loadLevels =
        widget.loadLevels ??
        LocalLevelDependencies.createGetLocalLevelsUseCase().call;
    return loadLevels();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.leaderboard)),
      body: SafeArea(
        child: FutureBuilder<List<Level>>(
          future: _levelsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final levels = snapshot.data ?? const <Level>[];
            if (snapshot.hasError || levels.isEmpty) {
              return Center(child: Text(localizations.leaderboardUnavailable));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: levels.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final level = levels[index];
                final number = level.number ?? 0;
                return Card(
                  key: GameUiKeys.levelCard(number),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.neonBlue,
                      foregroundColor: AppTheme.background,
                      child: Text('$number'),
                    ),
                    title: Text(level.name),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).pushNamed(
                      AppRoutes.leaderboard,
                      arguments: number,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

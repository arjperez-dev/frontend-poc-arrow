import 'package:flutter/material.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';

import '../../../core/app/app_settings_scope.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../game/application/level_progression.dart';
import '../../game/domain/level.dart';
import '../../game/infrastructure/local_level_dependencies.dart';
import '../../game/presentation/game_ui_keys.dart';
import '../../game/presentation/level_mode_filter.dart';
import '../../settings/domain/game_mode.dart';

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

  Future<List<Level>> _loadLevels() async {
    final loadLevels =
        widget.loadLevels ??
        (await LocalLevelDependencies.createGetLocalLevelsUseCase()).call;
    return loadLevels();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final gameMode =
        AppSettingsScope.maybeOf(context)?.gameMode ?? GameMode.twoD;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.leaderboard)),
      body: SafeArea(
        child: FutureBuilder<List<Level>>(
          future: _levelsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            // Same single-mode, complexity-sorted progression as the level
            // selection screen, so both lists show identical order and
            // display numbers. 2D and 3D are filtered apart BEFORE sorting.
            final progression = LevelProgression.fromLevels(
              filterLevelsByGameMode(
                snapshot.data ?? const <Level>[],
                wantThreeD: gameMode == GameMode.threeD,
              ),
            );
            final levels = progression.levels;
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
                final displayNumber = index + 1;
                return Card(
                  key: GameUiKeys.levelCard(number),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.neonBlue,
                      foregroundColor: AppTheme.background,
                      child: Text('$displayNumber'),
                    ),
                    title: Text('Level $displayNumber'),
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

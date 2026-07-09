import 'package:flutter/material.dart';

import '../../features/auth/presentation/auth_screen.dart';
import '../../features/game/presentation/game_screen.dart';
import '../../features/levels/presentation/level_selection_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/leaderboard/presentation/leaderboard_screen.dart';
import '../../features/leaderboard/presentation/leaderboard_level_picker_screen.dart';

class AppRoutes {
  const AppRoutes._();

  static const home = '/';
  static const levels = '/levels';
  static const game = '/game';
  static const settings = '/settings';
  static const auth = '/auth';
  static const leaderboard = '/leaderboard';
  static const leaderboardLevelPicker = '/leaderboard-level-picker';

  static Route<void> onGenerateRoute(RouteSettings routeSettings) {
    final builder = switch (routeSettings.name) {
      home => (_) => const HomeScreen(),
      levels => (_) => const LevelSelectionScreen(),
      game => (_) => GameScreen(
        levelNumber: _readLevelNumber(routeSettings.arguments),
      ),
      settings => (_) => const SettingsScreen(),
      auth => (_) => const AuthScreen(),
      leaderboard => (_) => LeaderboardScreen(
        levelNumber: _readLevelNumber(routeSettings.arguments),
      ),
      leaderboardLevelPicker => (_) => const LeaderboardLevelPickerScreen(),
      _ => (_) => const HomeScreen(),
    };

    return MaterialPageRoute<void>(builder: builder, settings: routeSettings);
  }

  static int? _readLevelNumber(Object? arguments) {
    if (arguments is int) {
      return arguments;
    }
    return null;
  }
}

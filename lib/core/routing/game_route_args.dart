import '../../features/challenges/domain/challenge.dart';

/// Arguments for [AppRoutes.game] and [AppRoutes.levels]. A plain int level
/// number is still accepted everywhere for backward compatibility; this
/// object is only needed when a challenge modifier rides along.
class GameRouteArgs {
  const GameRouteArgs({required this.levelNumber, this.challenge});

  final int? levelNumber;
  final Challenge? challenge;
}

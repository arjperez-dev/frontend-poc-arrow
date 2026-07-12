import 'arrow_path.dart';
import 'game_status.dart';
import 'level.dart';
import 'score.dart';

class GameSession {
  const GameSession({
    required this.level,
    required this.arrows,
    required this.movesCount,
    required this.mistakeCount,
    required this.elapsedSeconds,
    required this.score,
    required this.status,
  });

  factory GameSession.start(Level level) {
    return GameSession(
      level: level,
      arrows: level.arrows,
      movesCount: 0,
      mistakeCount: 0,
      elapsedSeconds: 0,
      score: const Score(1000),
      status: GameStatus.playing,
    );
  }

  final Level level;
  final List<ArrowPath> arrows;

  /// Total exit attempts (successful + failed). Each player tap = 1.
  final int movesCount;

  /// Number of failed exit attempts. Drives the lives system.
  final int mistakeCount;

  final int elapsedSeconds;
  final Score score;
  final GameStatus status;

  /// Remaining lives: starts at 3, loses 1 every 2 mistakes.
  int get livesRemaining => 3 - (mistakeCount ~/ 2);

  List<ArrowPath> get activeArrows {
    return arrows.where((arrow) => arrow.isActive).toList(growable: false);
  }

  ArrowPath? arrowById(String arrowId) {
    for (final arrow in arrows) {
      if (arrow.id == arrowId) {
        return arrow;
      }
    }
    return null;
  }

  GameSession copyWith({
    List<ArrowPath>? arrows,
    int? movesCount,
    int? mistakeCount,
    int? elapsedSeconds,
    Score? score,
    GameStatus? status,
  }) {
    return GameSession(
      level: level,
      arrows: arrows ?? this.arrows,
      movesCount: movesCount ?? this.movesCount,
      mistakeCount: mistakeCount ?? this.mistakeCount,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      score: score ?? this.score,
      status: status ?? this.status,
    );
  }
}

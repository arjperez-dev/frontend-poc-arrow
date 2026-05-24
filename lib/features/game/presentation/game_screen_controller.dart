import 'package:flutter/foundation.dart';

import '../application/game_session_service.dart';
import '../application/movement_result.dart';
import '../domain/game_session.dart';
import '../domain/game_status.dart';
import '../domain/level.dart';

typedef LoadLevelByNumber = Future<Level?> Function(int levelNumber);

enum GameScreenLoadState { loading, ready, notFound, failed }

class GameScreenController extends ChangeNotifier {
  GameScreenController({
    required int? levelNumber,
    required LoadLevelByNumber loadLevelByNumber,
    GameSessionService gameSessionService = const GameSessionService(),
  }) : _levelNumber = levelNumber,
       _loadLevelByNumber = loadLevelByNumber,
       _gameSessionService = gameSessionService;

  final int? _levelNumber;
  final LoadLevelByNumber _loadLevelByNumber;
  final GameSessionService _gameSessionService;

  GameScreenLoadState _loadState = GameScreenLoadState.loading;
  Level? _level;
  GameSession? _session;
  MovementOutcome? _lastOutcome;

  GameScreenLoadState get loadState => _loadState;
  Level? get level => _level;
  GameSession? get session => _session;
  MovementOutcome? get lastOutcome => _lastOutcome;
  bool get isVictory => _session?.status == GameStatus.victory;

  Future<void> load() async {
    final levelNumber = _levelNumber;
    if (levelNumber == null || levelNumber < 1) {
      _loadState = GameScreenLoadState.notFound;
      notifyListeners();
      return;
    }

    _loadState = GameScreenLoadState.loading;
    notifyListeners();

    try {
      final loadedLevel = await _loadLevelByNumber(levelNumber);
      if (loadedLevel == null) {
        _loadState = GameScreenLoadState.notFound;
        notifyListeners();
        return;
      }

      _level = loadedLevel;
      _session = _gameSessionService.start(loadedLevel);
      _lastOutcome = null;
      _loadState = GameScreenLoadState.ready;
      notifyListeners();
    } catch (_) {
      _loadState = GameScreenLoadState.failed;
      notifyListeners();
    }
  }

  void activateArrow(String arrowId) {
    final currentSession = _session;
    if (currentSession == null || currentSession.status == GameStatus.victory) {
      return;
    }

    final result = _gameSessionService.activateArrow(currentSession, arrowId);
    _session = result.session;
    _lastOutcome = result.outcome;
    notifyListeners();
  }

  void restart() {
    final currentLevel = _level;
    if (currentLevel == null) {
      return;
    }

    _session = _gameSessionService.start(currentLevel);
    _lastOutcome = null;
    _loadState = GameScreenLoadState.ready;
    notifyListeners();
  }
}

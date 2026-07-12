import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../audio/application/game_audio_event.dart';
import '../../challenges/domain/challenge.dart';
import '../application/game_session_service.dart';
import '../application/movement_result.dart';
import '../domain/game_session.dart';
import '../domain/game_status.dart';
import '../domain/level.dart';
import '../../progress/domain/level_best_result.dart';

typedef LoadLevelByNumber = Future<Level?> Function(int levelNumber);
typedef SaveLevelCompletion =
    Future<void> Function({
      required int levelNumber,
      required int score,
      required int moves,
      required int timeSeconds,
    });
typedef NotifyRemoteLevelCompletion =
    Future<void> Function({
      required int levelNumber,
      required int score,
      required int moves,
      required int timeSeconds,
    });
typedef GetBestLevelResult = Future<LevelBestResult?> Function(int levelNumber);
typedef PlayGameAudio = Future<void> Function(GameAudioEvent event);
typedef SaveChallengeRecord =
    Future<bool> Function({
      required Challenge challenge,
      required int levelNumber,
      required int score,
    });
typedef GetChallengeBestScore =
    Future<int?> Function(Challenge challenge, int levelNumber);

enum GameScreenLoadState { loading, ready, notFound, failed }

/// Why a challenge run ended in failure (drives the game-over overlay text).
enum ChallengeFailReason { timeUp, outOfMoves, mistake, livesOut }

class GameScreenController extends ChangeNotifier {
  GameScreenController({
    required int? levelNumber,
    required LoadLevelByNumber loadLevelByNumber,
    SaveLevelCompletion? saveLevelCompletion,
    NotifyRemoteLevelCompletion? notifyRemoteLevelCompletion,
    GetBestLevelResult? getBestLevelResult,
    PlayGameAudio? playGameAudio,
    GameSessionService gameSessionService = const GameSessionService(),
    Challenge? challenge,
    SaveChallengeRecord? saveChallengeRecord,
    GetChallengeBestScore? getChallengeBestScore,
    bool enableChallengeTimer = true,
  }) : _levelNumber = levelNumber,
       _loadLevelByNumber = loadLevelByNumber,
       _saveLevelCompletion = saveLevelCompletion,
       _notifyRemoteLevelCompletion = notifyRemoteLevelCompletion,
       _getBestLevelResult = getBestLevelResult,
       _playGameAudio = playGameAudio,
       _gameSessionService = gameSessionService,
       _challenge = challenge,
       _saveChallengeRecord = saveChallengeRecord,
       _getChallengeBestScore = getChallengeBestScore,
       _enableChallengeTimer = enableChallengeTimer;

  final int? _levelNumber;
  final LoadLevelByNumber _loadLevelByNumber;
  final SaveLevelCompletion? _saveLevelCompletion;
  final NotifyRemoteLevelCompletion? _notifyRemoteLevelCompletion;
  final GetBestLevelResult? _getBestLevelResult;
  final PlayGameAudio? _playGameAudio;
  final GameSessionService _gameSessionService;
  final Challenge? _challenge;
  final SaveChallengeRecord? _saveChallengeRecord;
  final GetChallengeBestScore? _getChallengeBestScore;

  /// When false (widget tests), no periodic Timer is started; tests advance
  /// the clock via [advanceClock] (same convention as enableBoardAnimations).
  final bool _enableChallengeTimer;

  Timer? _clockTimer;

  GameScreenLoadState _loadState = GameScreenLoadState.loading;
  Level? _level;
  GameSession? _session;
  MovementOutcome? _lastOutcome;
  LevelBestResult? _bestResult;
  bool _completionSaved = false;
  Future<void>? _pendingCompletionSave;

  /// Arrow id that should flash red on the board (collision feedback).
  String? _flashingArrowId;

  /// Whether a flash animation is currently in progress (debounce guard).
  bool _isFlashing = false;

  /// Trace of the most recent resolved attempt (drives presentation animation
  /// and is asserted by tests). Rules stay in domain/application.
  GameAttemptTrace? _lastAttemptTrace;

  /// Best challenge score for this (challenge, level), and whether the last
  /// victory set a new record.
  int? _challengeBestScore;
  bool _isNewChallengeRecord = false;
  bool _challengeRecordSaved = false;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _clockTimer?.cancel();
    super.dispose();
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  GameScreenLoadState get loadState => _loadState;
  Level? get level => _level;
  GameSession? get session => _session;
  MovementOutcome? get lastOutcome => _lastOutcome;
  LevelBestResult? get bestResult => _bestResult;
  String? get flashingArrowId => _flashingArrowId;
  GameAttemptTrace? get lastAttemptTrace => _lastAttemptTrace;

  /// Resolves once the pending local completion save (if any) has settled.
  /// A no-op (already-resolved future) when no victory has occurred yet.
  Future<void> get completionSettled =>
      _pendingCompletionSave ?? Future<void>.value();

  bool get isVictory => _session?.status == GameStatus.victory;
  bool get isGameOver => _session?.status == GameStatus.failed;
  int get livesRemaining => _session?.livesRemaining ?? 3;
  int get mistakeCount => _session?.mistakeCount ?? 0;

  Challenge? get challenge => _challenge;
  int? get remainingSeconds => _session?.remainingSeconds;
  int? get remainingMoves => _session?.remainingMoves;
  int? get challengeBestScore => _challengeBestScore;
  bool get isNewChallengeRecord => _isNewChallengeRecord;

  /// Why the current failed session ended, when a challenge is active.
  ChallengeFailReason? get challengeFailReason {
    final session = _session;
    final context = session?.challenge;
    if (session == null || context == null || !isGameOver) {
      return null;
    }
    return switch (context.challenge) {
      Challenge.timeAttack
          when session.elapsedSeconds >= context.timeLimitSeconds =>
        ChallengeFailReason.timeUp,
      Challenge.moveLimit when session.movesCount > context.maxMoves =>
        ChallengeFailReason.outOfMoves,
      Challenge.perfectRun => ChallengeFailReason.mistake,
      _ => ChallengeFailReason.livesOut,
    };
  }

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
      final challenge = _challenge;
      final context = challenge == null
          ? null
          : ChallengeContext.forLevel(challenge, loadedLevel);
      _session = _gameSessionService.start(loadedLevel, challenge: context);
      // Campaign best for normal play; challenge best for challenge play —
      // the two record systems never mix.
      _bestResult =
          challenge == null ? await _getBestLevelResult?.call(levelNumber) : null;
      _challengeBestScore = challenge == null
          ? null
          : await _getChallengeBestScore?.call(challenge, levelNumber);
      _lastOutcome = null;
      _lastAttemptTrace = null;
      _completionSaved = false;
      _challengeRecordSaved = false;
      _isNewChallengeRecord = false;
      _flashingArrowId = null;
      _isFlashing = false;
      _loadState = GameScreenLoadState.ready;
      _startClockIfNeeded();
      notifyListeners();
    } catch (_) {
      _loadState = GameScreenLoadState.failed;
      notifyListeners();
    }
  }

  void _startClockIfNeeded() {
    _clockTimer?.cancel();
    _clockTimer = null;
    if (_challenge != Challenge.timeAttack || !_enableChallengeTimer) {
      return;
    }
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      advanceClock();
    });
  }

  /// Advances the session clock by one second (the rule — including Time
  /// Attack expiry — lives in [GameSessionService.tickClock]). Public so
  /// widget tests can drive time without a real Timer.
  void advanceClock() {
    final currentSession = _session;
    if (_disposed ||
        currentSession == null ||
        currentSession.status != GameStatus.playing) {
      return;
    }
    final updated = _gameSessionService.tickClock(currentSession);
    _session = updated;
    if (updated.status == GameStatus.failed) {
      _clockTimer?.cancel();
      _clockTimer = null;
      unawaited(_playGameAudio?.call(GameAudioEvent.defeat) ?? Future.value());
    }
    _safeNotify();
  }

  void activateArrow(String arrowId) {
    final currentSession = _session;
    // Guard: ignore taps while session is not active or a flash is in progress.
    if (currentSession == null ||
        currentSession.status != GameStatus.playing ||
        _isFlashing) {
      return;
    }

    final result = _gameSessionService.activateArrow(currentSession, arrowId);
    _session = result.session;
    _lastOutcome = result.outcome;
    _lastAttemptTrace = GameAttemptTrace(
      arrowId: arrowId,
      outcome: result.outcome,
    );

    unawaited(_playAudioFor(result));

    if (result.outcome == MovementOutcome.collision ||
        result.outcome == MovementOutcome.gameOver) {
      unawaited(_flashCollision(arrowId));
    }

    if (result.session.status != GameStatus.playing) {
      _clockTimer?.cancel();
      _clockTimer = null;
    }

    if (result.session.status == GameStatus.victory) {
      // Challenge victories record a challenge best INSTEAD of campaign
      // completion — no unlock, no remote sync, no leaderboard (by design).
      if (_challenge != null) {
        unawaited(_saveChallengeRecordOnce(result.session));
      } else {
        unawaited(_saveCompletionOnce(result.session));
      }
    }

    notifyListeners();
  }

  void restart() {
    final currentLevel = _level;
    if (currentLevel == null) {
      return;
    }

    final challenge = _challenge;
    final context = challenge == null
        ? null
        : ChallengeContext.forLevel(challenge, currentLevel);
    _session = _gameSessionService.start(currentLevel, challenge: context);
    _lastOutcome = null;
    _lastAttemptTrace = null;
    _completionSaved = false;
    _challengeRecordSaved = false;
    _isNewChallengeRecord = false;
    _flashingArrowId = null;
    _isFlashing = false;
    _loadState = GameScreenLoadState.ready;
    _startClockIfNeeded();
    notifyListeners();
  }

  Future<void> _saveChallengeRecordOnce(GameSession completedSession) async {
    final levelNumber = completedSession.level.number;
    final challenge = _challenge;
    final saveRecord = _saveChallengeRecord;
    if (_challengeRecordSaved ||
        levelNumber == null ||
        challenge == null ||
        saveRecord == null) {
      return;
    }

    _challengeRecordSaved = true;
    final isNewRecord = await saveRecord(
      challenge: challenge,
      levelNumber: levelNumber,
      score: completedSession.score.value,
    );
    _isNewChallengeRecord = isNewRecord;
    if (isNewRecord) {
      _challengeBestScore = completedSession.score.value;
    }
    _safeNotify();
  }

  Future<void> _flashCollision(String arrowId) async {
    _isFlashing = true;
    _flashingArrowId = arrowId;
    _safeNotify();

    await Future<void>.delayed(const Duration(milliseconds: 320));

    _flashingArrowId = null;
    _isFlashing = false;
    _safeNotify();
  }

  Future<void> _saveCompletionOnce(GameSession completedSession) async {
    final levelNumber = completedSession.level.number;
    final saveCompletion = _saveLevelCompletion;
    if (_completionSaved || levelNumber == null || saveCompletion == null) {
      return;
    }

    _completionSaved = true;
    final localSave = saveCompletion(
      levelNumber: levelNumber,
      score: completedSession.score.value,
      moves: completedSession.movesCount,
      timeSeconds: completedSession.elapsedSeconds,
    );
    _pendingCompletionSave = localSave;
    await localSave;
    unawaited(_notifyRemoteCompletionBestEffort(completedSession, levelNumber));
    _bestResult = await _getBestLevelResult?.call(levelNumber);
    _safeNotify();
  }

  Future<void> _notifyRemoteCompletionBestEffort(
    GameSession completedSession,
    int levelNumber,
  ) async {
    final notifyRemote = _notifyRemoteLevelCompletion;
    if (notifyRemote == null) {
      return;
    }
    try {
      await notifyRemote(
        levelNumber: levelNumber,
        score: completedSession.score.value,
        moves: completedSession.movesCount,
        timeSeconds: completedSession.elapsedSeconds,
      );
    } catch (_) {
      // Remote sync and leaderboard are best-effort; local victory stays valid.
    }
  }

  Future<void> _playAudioFor(MovementResult result) async {
    final playAudio = _playGameAudio;
    if (playAudio == null) {
      return;
    }

    if (result.session.status == GameStatus.victory) {
      await playAudio(GameAudioEvent.victory);
      return;
    }

    final event = switch (result.outcome) {
      MovementOutcome.escaped => GameAudioEvent.move,
      MovementOutcome.collision => GameAudioEvent.blocked,
      MovementOutcome.gameOver => GameAudioEvent.defeat,
      MovementOutcome.arrowNotFound ||
      MovementOutcome.alreadyEscaped ||
      MovementOutcome.sessionNotActive => GameAudioEvent.blocked,
    };
    await playAudio(event);
  }
}

/// A resolved attempt the presentation layer can render/animate.
/// Carries no rule logic — it only records what the domain already decided.
class GameAttemptTrace {
  const GameAttemptTrace({required this.arrowId, required this.outcome});

  final String arrowId;
  final MovementOutcome outcome;
}

import 'package:flutter/widgets.dart';

class GameUiKeys {
  const GameUiKeys._();

  static const gameBoard = Key('game-board');
  static const resetViewButton = Key('reset-view-button');
  static const movesLabel = Key('moves-label');
  static const scoreLabel = Key('score-label');
  static const livesLabel = Key('lives-label');
  static const victoryCard = Key('victory-card');
  static const gameOverCard = Key('game-over-card');
  static const retryButton = Key('retry-button');
  static const nextLevelButton = Key('next-level-button');
  static const leaderboardButton = Key('leaderboard-button');
  static const backToLevelsButton = Key('back-to-levels-button');
  static const soundSwitch = Key('sound-switch');
  static const musicSwitch = Key('music-switch');
  static const resetProgressButton = Key('reset-progress-button');
  static const confirmResetProgressButton = Key(
    'confirm-reset-progress-button',
  );
  static const resetRemoteProgressButton = Key('reset-remote-progress-button');
  static const confirmResetRemoteProgressButton = Key(
    'confirm-reset-remote-progress-button',
  );
  static const gameModeSelector = Key('settings-game-mode-selector');

  static Key levelCard(int levelNumber) => Key('level-card-$levelNumber');
}

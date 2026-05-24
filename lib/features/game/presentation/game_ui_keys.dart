import 'package:flutter/widgets.dart';

class GameUiKeys {
  const GameUiKeys._();

  static const gameBoard = Key('game-board');
  static const movesLabel = Key('moves-label');
  static const scoreLabel = Key('score-label');
  static const victoryCard = Key('victory-card');
  static const retryButton = Key('retry-button');
  static const nextLevelButton = Key('next-level-button');
  static const backToLevelsButton = Key('back-to-levels-button');

  static Key levelCard(int levelNumber) => Key('level-card-$levelNumber');
}

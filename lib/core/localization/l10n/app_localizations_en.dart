// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Nodus';

  @override
  String get play => 'Play';

  @override
  String get settings => 'Settings';

  @override
  String get levels => 'Levels';

  @override
  String get gameMode => 'Game Mode';

  @override
  String get challenges => 'Challenges';

  @override
  String get gameMode2D => '2D';

  @override
  String get gameMode3D => '3D';

  @override
  String get gameModeHint => 'Choose which level set the menu opens.';

  @override
  String get gamePlaceholder => 'Game placeholder';

  @override
  String get backendUrlLabel => 'Backend URL';

  @override
  String get homeSubtitle => 'Untangle the knot. One exit at a time.';

  @override
  String get levelSelectionPlaceholder => 'Level selection placeholder';

  @override
  String get settingsPlaceholder => 'Settings placeholder';

  @override
  String get openGame => 'Open Game';

  @override
  String get moves => 'Moves';

  @override
  String get score => 'Score';

  @override
  String get victory => 'Victory';

  @override
  String get retry => 'Retry';

  @override
  String get nextLevel => 'Next level';

  @override
  String get backToLevels => 'Back to levels';

  @override
  String get levelNotFound => 'Level not found';

  @override
  String get loadingLevel => 'Loading level';

  @override
  String get locked => 'Locked';

  @override
  String get completed => 'Completed';

  @override
  String get unlocked => 'Unlocked';

  @override
  String get bestScore => 'Best score';

  @override
  String get levelLocked => 'Complete previous levels to unlock this level.';

  @override
  String get soundEnabled => 'Sound effects';

  @override
  String get musicEnabled => 'Music';

  @override
  String get soundFoundationDescription => ' ';

  @override
  String get musicFutureDescription => ' ';

  @override
  String get language => 'Language';

  @override
  String get languageDisplayValue => 'English';

  @override
  String get languageSystemOption => 'System default';

  @override
  String get resetProgress => 'Reset local progress';

  @override
  String get resetProgressConfirmation =>
      'This clears completed levels, best scores, and unlocked progress. Settings stay unchanged.';

  @override
  String get progressReset => 'Local progress reset.';

  @override
  String get resetRemoteProgress => 'Reset remote progress';

  @override
  String get resetRemoteProgressConfirmation =>
      'This clears your progress stored on the server, then also resets local progress. Settings stay unchanged.';

  @override
  String get remoteProgressReset => 'Remote and local progress reset.';

  @override
  String get resetRemoteProgressLoginRequired =>
      'Log in to reset remote progress.';

  @override
  String get remoteResetOfflineMessage =>
      'Backend unavailable. Local progress reset only.';

  @override
  String get remoteResetFailedMessage =>
      'Could not reset remote progress. Please try again.';

  @override
  String get cancel => 'Cancel';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsSectionGamePreferences => 'Game Preferences';

  @override
  String get settingsSectionAppSettings => 'App Settings';

  @override
  String get settingsSectionData => 'Data';

  @override
  String get loadingSettings => 'Loading settings';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get logout => 'Logout';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get displayName => 'Display name';

  @override
  String get authOptional =>
      'Login is optional. It enables progress sync and leaderboard features.';

  @override
  String get loggedInAs => 'Logged in as';

  @override
  String get notLoggedIn => 'Not logged in';

  @override
  String get syncProgress => 'Sync progress';

  @override
  String get syncComplete => 'Progress sync complete.';

  @override
  String get syncUnavailable => 'Sync unavailable. Local progress is safe.';

  @override
  String get leaderboard => 'Leaderboard';

  @override
  String get leaderboardUnavailable => 'Leaderboard unavailable.';

  @override
  String get localFirstNotice => 'Local play remains available offline.';

  @override
  String get submit => 'Submit';

  @override
  String get lives => 'Lives';

  @override
  String get gameOver => 'Game Over';

  @override
  String get gameOverMessage => 'You ran out of lives.';

  @override
  String get mistakes => 'Mistakes';

  @override
  String get resetView => 'Reset view';

  @override
  String get dragToRotate => 'Drag to rotate • pinch to zoom';

  @override
  String get challengeTimeAttack => 'Time Attack';

  @override
  String get challengeTimeAttackDescription =>
      'Beat the level before the clock runs out.';

  @override
  String get challengeMoveLimit => 'Move Limit';

  @override
  String get challengeMoveLimitDescription =>
      'Clear every arrow within a fixed move budget.';

  @override
  String get challengePerfectRun => 'Perfect Run';

  @override
  String get challengePerfectRunDescription =>
      'One collision ends the run. Flawless only.';

  @override
  String get timeLeft => 'Time';

  @override
  String get movesLeft => 'Moves left';

  @override
  String get flawless => 'Flawless';

  @override
  String get challengeBest => 'Challenge best';

  @override
  String get newRecord => 'New record!';

  @override
  String get challengeFailedTimeUp => 'Time is up!';

  @override
  String get challengeFailedOutOfMoves => 'Out of moves!';

  @override
  String get challengeFailedMistake => 'A collision ended your perfect run.';
}

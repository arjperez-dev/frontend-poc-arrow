import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Nodus'**
  String get appTitle;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @levels.
  ///
  /// In en, this message translates to:
  /// **'Levels'**
  String get levels;

  /// No description provided for @gameMode.
  ///
  /// In en, this message translates to:
  /// **'Game Mode'**
  String get gameMode;

  /// No description provided for @gamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Game placeholder'**
  String get gamePlaceholder;

  /// No description provided for @backendUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Backend URL'**
  String get backendUrlLabel;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Untangle the knot. One exit at a time.'**
  String get homeSubtitle;

  /// No description provided for @levelSelectionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Level selection placeholder'**
  String get levelSelectionPlaceholder;

  /// No description provided for @settingsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Settings placeholder'**
  String get settingsPlaceholder;

  /// No description provided for @openGame.
  ///
  /// In en, this message translates to:
  /// **'Open Game'**
  String get openGame;

  /// No description provided for @moves.
  ///
  /// In en, this message translates to:
  /// **'Moves'**
  String get moves;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @victory.
  ///
  /// In en, this message translates to:
  /// **'Victory'**
  String get victory;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @nextLevel.
  ///
  /// In en, this message translates to:
  /// **'Next level'**
  String get nextLevel;

  /// No description provided for @backToLevels.
  ///
  /// In en, this message translates to:
  /// **'Back to levels'**
  String get backToLevels;

  /// No description provided for @levelNotFound.
  ///
  /// In en, this message translates to:
  /// **'Level not found'**
  String get levelNotFound;

  /// No description provided for @loadingLevel.
  ///
  /// In en, this message translates to:
  /// **'Loading level'**
  String get loadingLevel;

  /// No description provided for @locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @unlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get unlocked;

  /// No description provided for @bestScore.
  ///
  /// In en, this message translates to:
  /// **'Best score'**
  String get bestScore;

  /// No description provided for @levelLocked.
  ///
  /// In en, this message translates to:
  /// **'Complete previous levels to unlock this level.'**
  String get levelLocked;

  /// No description provided for @soundEnabled.
  ///
  /// In en, this message translates to:
  /// **'Sound effects'**
  String get soundEnabled;

  /// No description provided for @musicEnabled.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get musicEnabled;

  /// No description provided for @soundFoundationDescription.
  ///
  /// In en, this message translates to:
  /// **' '**
  String get soundFoundationDescription;

  /// No description provided for @musicFutureDescription.
  ///
  /// In en, this message translates to:
  /// **' '**
  String get musicFutureDescription;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageDisplayValue.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageDisplayValue;

  /// No description provided for @languageSystemOption.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemOption;

  /// No description provided for @resetProgress.
  ///
  /// In en, this message translates to:
  /// **'Reset local progress'**
  String get resetProgress;

  /// No description provided for @resetProgressConfirmation.
  ///
  /// In en, this message translates to:
  /// **'This clears completed levels, best scores, and unlocked progress. Settings stay unchanged.'**
  String get resetProgressConfirmation;

  /// No description provided for @progressReset.
  ///
  /// In en, this message translates to:
  /// **'Local progress reset.'**
  String get progressReset;

  /// No description provided for @resetRemoteProgress.
  ///
  /// In en, this message translates to:
  /// **'Reset remote progress'**
  String get resetRemoteProgress;

  /// No description provided for @resetRemoteProgressConfirmation.
  ///
  /// In en, this message translates to:
  /// **'This clears your progress stored on the server, then also resets local progress. Settings stay unchanged.'**
  String get resetRemoteProgressConfirmation;

  /// No description provided for @remoteProgressReset.
  ///
  /// In en, this message translates to:
  /// **'Remote and local progress reset.'**
  String get remoteProgressReset;

  /// No description provided for @resetRemoteProgressLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Log in to reset remote progress.'**
  String get resetRemoteProgressLoginRequired;

  /// No description provided for @remoteResetOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Backend unavailable. Local progress reset only.'**
  String get remoteResetOfflineMessage;

  /// No description provided for @remoteResetFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not reset remote progress. Please try again.'**
  String get remoteResetFailedMessage;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @loadingSettings.
  ///
  /// In en, this message translates to:
  /// **'Loading settings'**
  String get loadingSettings;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @authOptional.
  ///
  /// In en, this message translates to:
  /// **'Login is optional. It enables progress sync and leaderboard features.'**
  String get authOptional;

  /// No description provided for @loggedInAs.
  ///
  /// In en, this message translates to:
  /// **'Logged in as'**
  String get loggedInAs;

  /// No description provided for @notLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get notLoggedIn;

  /// No description provided for @syncProgress.
  ///
  /// In en, this message translates to:
  /// **'Sync progress'**
  String get syncProgress;

  /// No description provided for @syncComplete.
  ///
  /// In en, this message translates to:
  /// **'Progress sync complete.'**
  String get syncComplete;

  /// No description provided for @syncUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sync unavailable. Local progress is safe.'**
  String get syncUnavailable;

  /// No description provided for @leaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboard;

  /// No description provided for @leaderboardUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard unavailable.'**
  String get leaderboardUnavailable;

  /// No description provided for @localFirstNotice.
  ///
  /// In en, this message translates to:
  /// **'Local play remains available offline.'**
  String get localFirstNotice;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @lives.
  ///
  /// In en, this message translates to:
  /// **'Lives'**
  String get lives;

  /// No description provided for @gameOver.
  ///
  /// In en, this message translates to:
  /// **'Game Over'**
  String get gameOver;

  /// No description provided for @gameOverMessage.
  ///
  /// In en, this message translates to:
  /// **'You ran out of lives.'**
  String get gameOverMessage;

  /// No description provided for @mistakes.
  ///
  /// In en, this message translates to:
  /// **'Mistakes'**
  String get mistakes;

  /// No description provided for @resetView.
  ///
  /// In en, this message translates to:
  /// **'Reset view'**
  String get resetView;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

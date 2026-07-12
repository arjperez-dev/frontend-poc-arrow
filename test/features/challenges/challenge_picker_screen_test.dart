import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';
import 'package:frontend_poc_arrow/core/routing/app_routes.dart';
import 'package:frontend_poc_arrow/features/challenges/domain/challenge.dart';
import 'package:frontend_poc_arrow/features/challenges/presentation/challenge_picker_screen.dart';
import 'package:frontend_poc_arrow/features/game/presentation/game_ui_keys.dart';

void main() {
  testWidgets('should_show_all_three_challenges_and_push_levels_with_choice',
      (tester) async {
    Object? pushedArguments;
    String? pushedRoute;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ChallengePickerScreen(),
        onGenerateRoute: (settings) {
          pushedRoute = settings.name;
          pushedArguments = settings.arguments;
          // A placeholder destination keeps the test hermetic — the real
          // levels route needs SharedPreferences/assets.
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: SizedBox()),
            settings: settings,
          );
        },
      ),
    );

    expect(
      find.byKey(GameUiKeys.challengeCard(Challenge.timeAttack)),
      findsOneWidget,
    );
    expect(
      find.byKey(GameUiKeys.challengeCard(Challenge.moveLimit)),
      findsOneWidget,
    );
    expect(
      find.byKey(GameUiKeys.challengeCard(Challenge.perfectRun)),
      findsOneWidget,
    );

    await tester.tap(find.byKey(GameUiKeys.challengeCard(Challenge.moveLimit)));
    await tester.pumpAndSettle();

    expect(pushedRoute, AppRoutes.levels);
    expect(pushedArguments, Challenge.moveLimit);
  });
}

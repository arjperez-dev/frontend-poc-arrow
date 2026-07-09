import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/presentation/game_ui_keys.dart';
import 'package:frontend_poc_arrow/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('should_show_home_screen_when_app_starts', (tester) async {
    await tester.pumpWidget(const ArrowPocApp());
    await tester.pump();

    expect(find.text('Nodus'), findsOneWidget);
    expect(find.text('Levels'), findsOneWidget);
    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Game Mode'), findsOneWidget);
    expect(find.text('http://10.0.2.2:3000'), findsOneWidget);
  });

  testWidgets('should_open_level_selection_when_play_is_tapped', (
    tester,
  ) async {
    await tester.pumpWidget(const ArrowPocApp());
    await tester.pump();

    await tester.tap(find.text('Levels'));
    await _pumpUntilFound(tester, find.byKey(GameUiKeys.levelCard(1)));

    expect(find.text('Level 1'), findsOneWidget);
    expect(find.byKey(GameUiKeys.levelCard(1)), findsOneWidget);
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail(
    'Expected widget was not found: $finder. Exception: ${tester.takeException()}',
  );
}

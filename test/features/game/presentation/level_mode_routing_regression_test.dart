import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/application/get_local_levels_use_case.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/asset_level_repository.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/asset_text_loader.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/local_level_data_source.dart';
import 'package:frontend_poc_arrow/features/game/presentation/level_mode_filter.dart';
import 'package:frontend_poc_arrow/features/settings/domain/game_mode.dart';

// Regression gate for Phase 37.4: adding hex as a third mode must not
// renumber or reroute any of the 30 pre-existing 2D/3D levels — storage,
// routing, leaderboard, and backend mapping all key off the internal number.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'levels 1-30 keep their internal numbers and their existing 2D/3D mode assignment',
    () async {
      final repository = AssetLevelRepository(
        localLevelDataSource: LocalLevelDataSource(
          assetTextLoader: const RootBundleAssetTextLoader(),
        ),
      );
      final levels = await GetLocalLevelsUseCase(repository)();

      final numbers = levels.map((l) => l.number).toSet();
      expect(numbers, containsAll(List<int>.generate(30, (i) => i + 1)));

      for (final level in levels) {
        final number = level.number!;
        if (number > 30) {
          continue; // hex band, not covered by this regression gate.
        }
        final expectedMode = number <= 20 ? GameMode.twoD : GameMode.threeD;
        expect(
          modeOfLevel(level),
          expectedMode,
          reason: 'Level $number should route to $expectedMode',
        );
      }

      final twoD = filterLevelsByGameMode(levels, mode: GameMode.twoD);
      final threeD = filterLevelsByGameMode(levels, mode: GameMode.threeD);
      expect(twoD.map((l) => l.number).toSet(), Set.of(List.generate(20, (i) => i + 1)));
      expect(
        threeD.where((l) => l.number! <= 30).map((l) => l.number).toSet(),
        Set.of(List.generate(10, (i) => i + 21)),
      );
    },
  );

  test('the new hex band (31-40) never appears in the 2D or 3D lists', () async {
    final repository = AssetLevelRepository(
      localLevelDataSource: LocalLevelDataSource(
        assetTextLoader: const RootBundleAssetTextLoader(),
      ),
    );
    final levels = await GetLocalLevelsUseCase(repository)();

    final twoD = filterLevelsByGameMode(levels, mode: GameMode.twoD);
    final threeD = filterLevelsByGameMode(levels, mode: GameMode.threeD);
    final hex = filterLevelsByGameMode(levels, mode: GameMode.hex);

    expect(twoD.any((l) => l.number! >= 31), isFalse);
    expect(threeD.any((l) => l.number! >= 31), isFalse);
    expect(hex.map((l) => l.number).toSet(), Set.of(List.generate(10, (i) => i + 31)));
  });
}

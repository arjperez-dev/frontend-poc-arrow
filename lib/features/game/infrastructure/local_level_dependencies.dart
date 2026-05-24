import '../application/get_local_level_by_number_use_case.dart';
import '../application/get_local_levels_use_case.dart';
import '../application/level_repository.dart';
import 'asset_level_repository.dart';
import 'asset_text_loader.dart';
import 'local_level_data_source.dart';

class LocalLevelDependencies {
  const LocalLevelDependencies._();

  static LevelRepository createRepository() {
    return AssetLevelRepository(
      localLevelDataSource: LocalLevelDataSource(
        assetTextLoader: const RootBundleAssetTextLoader(),
      ),
    );
  }

  static GetLocalLevelsUseCase createGetLocalLevelsUseCase() {
    return GetLocalLevelsUseCase(createRepository());
  }

  static GetLocalLevelByNumberUseCase createGetLocalLevelByNumberUseCase() {
    return GetLocalLevelByNumberUseCase(createRepository());
  }
}

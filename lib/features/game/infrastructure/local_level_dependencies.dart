import '../../../core/config/app_config.dart';
import '../../../core/network/network_dependencies.dart';
import '../application/get_local_level_by_number_use_case.dart';
import '../application/get_local_levels_use_case.dart';
import '../application/level_repository.dart';
import 'api_remote_level_definition_repository.dart';
import 'asset_level_repository.dart';
import 'asset_text_loader.dart';
import 'local_level_data_source.dart';
import 'merged_level_repository.dart';

class LocalLevelDependencies {
  const LocalLevelDependencies._();

  static LevelRepository _createLocalRepository() {
    return AssetLevelRepository(
      localLevelDataSource: LocalLevelDataSource(
        assetTextLoader: const RootBundleAssetTextLoader(),
      ),
    );
  }

  /// Local levels always load. When [AppConfig.enableRemoteLevels] is on,
  /// the result is merged with best-effort backend-served levels (Phase
  /// 34.4); otherwise this preserves the pre-34.4 local-only behavior
  /// unchanged.
  static Future<LevelRepository> createRepository() async {
    final localRepository = _createLocalRepository();
    if (!AppConfig.enableRemoteLevels) {
      return localRepository;
    }

    final apiClient = await NetworkDependencies.createApiClient();
    return MergedLevelRepository(
      localLevelRepository: localRepository,
      remoteLevelDefinitionRepository: ApiRemoteLevelDefinitionRepository(
        apiClient,
      ),
    );
  }

  static Future<GetLocalLevelsUseCase> createGetLocalLevelsUseCase() async {
    return GetLocalLevelsUseCase(await createRepository());
  }

  static Future<GetLocalLevelByNumberUseCase>
  createGetLocalLevelByNumberUseCase() async {
    return GetLocalLevelByNumberUseCase(await createRepository());
  }
}

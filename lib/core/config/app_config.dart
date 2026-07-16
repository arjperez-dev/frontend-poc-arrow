class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
  static const int manualLevelCount = 30;

  /// Phase 34.4/34.5: merges backend-served dynamic levels (Phase 34.1 number
  /// band `>= 1000`) into the local level list. Still off by default —
  /// see Phase 34.5 "After Completion" notes in `harness/context/
  /// phase_registry.md`: several widget tests mount screens without
  /// injecting a fake `loadLevels`/`loadLevelByNumber`, so a true default
  /// makes `LocalLevelDependencies` attempt a real network call inside
  /// `flutter test`, which breaks the suite. Flip only after those call
  /// sites are given fakes, or `AppConfig.enableRemoteLevels` is injected
  /// into `LocalLevelDependencies` so tests can force it off explicitly.
  static const bool enableRemoteLevels = bool.fromEnvironment(
    'ENABLE_REMOTE_LEVELS',
  );
}


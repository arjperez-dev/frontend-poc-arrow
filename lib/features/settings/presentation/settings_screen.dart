import 'package:flutter/material.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/infrastructure/auth_dependencies.dart';
import '../../game/presentation/game_ui_keys.dart';
import '../../progress/infrastructure/local_progress_dependencies.dart';
import '../domain/game_mode.dart';
import '../infrastructure/settings_dependencies.dart';
import 'settings_screen_controller.dart';
import '../../../core/app/app_settings_scope.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({this.controller, super.key});

  final SettingsScreenController? controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SettingsScreenController? _controller;

  @override
  void initState() {
    super.initState();
    final providedController = widget.controller;
    if (providedController != null) {
      _controller = providedController..load();
      return;
    }
    _createController();
  }

  Future<void> _createController() async {
    final controller = SettingsScreenController(
      getPlayerSettings:
          await SettingsDependencies.createGetPlayerSettingsUseCase(),
      savePlayerSettings:
          await SettingsDependencies.createSavePlayerSettingsUseCase(),
      resetLocalProgress:
          await LocalProgressDependencies.createResetLocalProgressUseCase(),
      resetRemoteProgress:
          await LocalProgressDependencies.createResetRemoteProgressUseCase(),
      getAuthSession: await AuthDependencies.createGetAuthSessionUseCase(),
      logout: await AuthDependencies.createLogoutUseCase(),
      syncProgress:
          (await LocalProgressDependencies.createSyncProgressUseCase()).call,
    );
    if (!mounted) {
      controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
    });
    await controller.load();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.settings)),
      body: SafeArea(
        child: controller == null
            ? _LoadingState(message: localizations.loadingSettings)
            : AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  return switch (controller.loadState) {
                    SettingsScreenLoadState.loading => _LoadingState(
                      message: localizations.loadingSettings,
                    ),
                    SettingsScreenLoadState.failed => _SettingsError(
                      onRetry: controller.load,
                    ),
                    SettingsScreenLoadState.ready => _SettingsContent(
                      controller: controller,
                    ),
                  };
                },
              ),
      ),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({required this.controller});

  final SettingsScreenController controller;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final settings = controller.settings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        _SectionHeader(localizations.settingsSectionAccount),
        _AuthStatusCard(controller: controller),
        const SizedBox(height: 22),
        _SectionHeader(localizations.settingsSectionGamePreferences),
        _GameModeSelectorCard(controller: controller),
        const SizedBox(height: 12),
        _LanguageSelectorCard(controller: controller),
        const SizedBox(height: 22),
        _SectionHeader(localizations.settingsSectionAppSettings),
        _SettingsCard(
          child: SwitchListTile(
            key: GameUiKeys.soundSwitch,
            value: settings.soundEnabled,
            onChanged: controller.setSoundEnabled,
            secondary: const _SettingsIconChip(Icons.volume_up_rounded),
            title: Text(localizations.soundEnabled),
          ),
        ),
        const SizedBox(height: 12),
        _SettingsCard(
          child: SwitchListTile(
            key: GameUiKeys.musicSwitch,
            value: settings.musicEnabled,
            onChanged: controller.setMusicEnabled,
            secondary: const _SettingsIconChip(Icons.music_note_rounded),
            title: Text(localizations.musicEnabled),
          ),
        ),
        const SizedBox(height: 22),
        _SectionHeader(localizations.settingsSectionData),
        _ReadOnlyInfoCard(
          title: localizations.backendUrlLabel,
          value: AppConfig.apiBaseUrl,
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          key: GameUiKeys.resetProgressButton,
          onPressed: () => _confirmResetProgress(context),
          icon: const Icon(Icons.restart_alt_rounded),
          label: Text(localizations.resetProgress),
        ),
        const SizedBox(height: 12),
        if (controller.isLoggedIn)
          FilledButton.tonalIcon(
            key: GameUiKeys.resetRemoteProgressButton,
            onPressed: controller.resettingRemote
                ? null
                : () => _confirmResetRemoteProgress(context),
            icon: const Icon(Icons.cloud_off_rounded),
            label: Text(
              controller.resettingRemote
                  ? localizations.loadingSettings
                  : localizations.resetRemoteProgress,
            ),
          )
        else
          Text(
            localizations.resetRemoteProgressLoginRequired,
            style: const TextStyle(color: AppTheme.mutedText),
          ),
      ],
    );
  }

  Future<void> _confirmResetRemoteProgress(BuildContext context) async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(localizations.resetRemoteProgress),
          content: Text(localizations.resetRemoteProgressConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(localizations.cancel),
            ),
            FilledButton(
              key: GameUiKeys.confirmResetRemoteProgressButton,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(localizations.resetRemoteProgress),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final result = await controller.resetRemoteProgress();
    if (!context.mounted) {
      return;
    }
    final message = switch (result) {
      RemoteResetResult.success => localizations.remoteProgressReset,
      RemoteResetResult.offline => localizations.remoteResetOfflineMessage,
      RemoteResetResult.unauthenticated =>
        localizations.resetRemoteProgressLoginRequired,
      RemoteResetResult.failed => localizations.remoteResetFailedMessage,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmResetProgress(BuildContext context) async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(localizations.resetProgress),
          content: Text(localizations.resetProgressConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(localizations.cancel),
            ),
            FilledButton(
              key: GameUiKeys.confirmResetProgressButton,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(localizations.resetProgress),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    await controller.resetProgress();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(localizations.progressReset)));
  }
}

/// Small uppercase label introducing each settings section, mirroring the
/// sectioned layout of the Phase 27 mockups.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.neonMint,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

/// Rounded card surface matching the global [Card] palette (mint-tinted
/// border) but built on [Material] directly: [ListTile] asserts when placed
/// inside a color-decorated non-Material ancestor.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final content = padding == null
        ? child
        : Padding(padding: padding!, child: child);

    return Material(
      color: AppTheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.neonMint.withValues(alpha: 0.18)),
      ),
      child: content,
    );
  }
}

/// Rounded icon badge used as the leading element of toggle rows.
class _SettingsIconChip extends StatelessWidget {
  const _SettingsIconChip(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.neonMint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppTheme.neonMint, size: 22),
    );
  }
}

class _AuthStatusCard extends StatelessWidget {
  const _AuthStatusCard({required this.controller});

  final SettingsScreenController controller;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final session = controller.authSession;

    return _SettingsCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _AccountAvatar(displayName: session?.user.displayName),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session == null
                          ? localizations.notLoggedIn
                          : session.user.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.softText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      session == null
                          ? localizations.localFirstNotice
                          : localizations.loggedInAs,
                      style: const TextStyle(
                        color: AppTheme.mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (controller.syncMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              controller.syncMessage == 'success'
                  ? localizations.syncComplete
                  : localizations.syncUnavailable,
              style: const TextStyle(color: AppTheme.mutedText, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          if (session == null)
            FilledButton(
              onPressed: () async {
                await Navigator.of(context).pushNamed(AppRoutes.auth);
                await controller.refreshAuthSession();
              },
              child: Text(localizations.login),
            )
          else ...[
            FilledButton(
              onPressed: controller.syncing
                  ? null
                  : () async {
                      await controller.syncProgress();
                    },
              child: Text(
                controller.syncing
                    ? localizations.loadingSettings
                    : localizations.syncProgress,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: controller.logout,
              child: Text(localizations.logout),
            ),
          ],
        ],
      ),
    );
  }
}

/// Circular mint→blue avatar showing the player's initials, or a generic
/// person glyph when logged out — echoes the mockup profile card.
class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({this.displayName});

  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final name = displayName?.trim();
    final initials = (name == null || name.isEmpty)
        ? null
        : name
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part.characters.first.toUpperCase())
              .join();

    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppTheme.neonMint, AppTheme.neonBlue],
        ),
      ),
      alignment: Alignment.center,
      child: initials == null
          ? const Icon(
              Icons.person_rounded,
              color: AppTheme.background,
              size: 26,
            )
          : Text(
              initials,
              style: const TextStyle(
                color: AppTheme.background,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
    );
  }
}

class _ReadOnlyInfoCard extends StatelessWidget {
  const _ReadOnlyInfoCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.softText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(value),
        ],
      ),
    );
  }
}

class _LanguageSelectorCard extends StatelessWidget {
  const _LanguageSelectorCard({required this.controller});

  final SettingsScreenController controller;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final current = controller.settings.languageCode;

    return _SettingsCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.language,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.softText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButton<String?>(
            key: const Key('settings-language-dropdown'),
            isExpanded: true,
            value: current,
            onChanged: (code) async {
              await controller.setLanguage(code);
              if (!context.mounted) {
                return;
              }
              AppSettingsScope.maybeOf(
                context,
              )?.setLocale(code == null ? null : Locale(code));
            },
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(localizations.languageSystemOption),
              ),
              const DropdownMenuItem<String?>(
                value: 'en',
                child: Text('English'),
              ),
              const DropdownMenuItem<String?>(
                value: 'es',
                child: Text('Español'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GameModeSelectorCard extends StatelessWidget {
  const _GameModeSelectorCard({required this.controller});

  final SettingsScreenController controller;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final current = controller.settings.gameMode;

    return _SettingsCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.gameMode,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.softText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(localizations.gameModeHint),
          const SizedBox(height: 12),
          SegmentedButton<GameMode>(
            key: GameUiKeys.gameModeSelector,
            segments: [
              ButtonSegment(
                value: GameMode.twoD,
                label: Text(localizations.gameMode2D),
              ),
              ButtonSegment(
                value: GameMode.threeD,
                label: Text(localizations.gameMode3D),
              ),
            ],
            selected: {current},
            onSelectionChanged: (selection) async {
              final mode = selection.first;
              await controller.setGameMode(mode);
              if (!context.mounted) {
                return;
              }
              AppSettingsScope.maybeOf(context)?.setGameMode(mode);
            },
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message));
  }
}

class _SettingsError extends StatelessWidget {
  const _SettingsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Center(
      child: FilledButton(onPressed: onRetry, child: Text(localizations.retry)),
    );
  }
}

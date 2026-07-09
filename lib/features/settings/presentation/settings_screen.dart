import 'package:flutter/material.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/infrastructure/auth_dependencies.dart';
import '../../game/presentation/game_ui_keys.dart';
import '../../progress/infrastructure/local_progress_dependencies.dart';
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
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: SwitchListTile(
            key: GameUiKeys.soundSwitch,
            value: settings.soundEnabled,
            onChanged: controller.setSoundEnabled,
            title: Text(localizations.soundEnabled),
            subtitle: Text(localizations.soundFoundationDescription),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            key: GameUiKeys.musicSwitch,
            value: settings.musicEnabled,
            onChanged: controller.setMusicEnabled,
            title: Text(localizations.musicEnabled),
            subtitle: Text(localizations.musicFutureDescription),
          ),
        ),
        const SizedBox(height: 12),
        _AuthStatusCard(controller: controller),
        const SizedBox(height: 12),
        _LanguageSelectorCard(controller: controller),
        const SizedBox(height: 12),
        _ReadOnlyInfoCard(
          title: localizations.backendUrlLabel,
          value: AppConfig.apiBaseUrl,
        ),
        const SizedBox(height: 20),
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
          Text(localizations.resetRemoteProgressLoginRequired),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

class _AuthStatusCard extends StatelessWidget {
  const _AuthStatusCard({required this.controller});

  final SettingsScreenController controller;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final session = controller.authSession;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              session == null
                  ? localizations.notLoggedIn
                  : '${localizations.loggedInAs} ${session.user.displayName}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.softText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(localizations.localFirstNotice),
            if (controller.syncMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                controller.syncMessage == 'success'
                    ? localizations.syncComplete
                    : localizations.syncUnavailable,
              ),
            ],
            const SizedBox(height: 14),
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
    return Card(
      child: Padding(
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

    return Card(
      child: Padding(
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

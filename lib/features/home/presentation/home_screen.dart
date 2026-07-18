// Game name: "Nodus" (Latin for "knot" / "node"). The core mechanic is
// untangling a graph of nodes and edges, so a word that literally means
// "knot" reads as on-theme without being generic ("Puzzle", "Arrow", "Game").
// Short, pronounceable across locales, and free of the placeholder "POC"
// branding this screen previously carried.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';

import '../../../core/app/app_settings_scope.dart';
import '../../../core/config/app_config.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../game/presentation/game_ui_keys.dart';
import '../../settings/application/get_player_settings_use_case.dart';
import '../../settings/application/save_player_settings_use_case.dart';
import '../../settings/domain/game_mode.dart';
import '../../settings/infrastructure/settings_dependencies.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _backgroundController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  late final Future<GetPlayerSettingsUseCase> _getPlayerSettings =
      SettingsDependencies.createGetPlayerSettingsUseCase();
  late final Future<SavePlayerSettingsUseCase> _savePlayerSettings =
      SettingsDependencies.createSavePlayerSettingsUseCase();

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  /// Same two-call shape as the settings screen's selectors: the scope makes
  /// the change reactive app-wide immediately; the use case persists it.
  Future<void> _setGameMode(GameMode mode) async {
    AppSettingsScope.maybeOf(context)?.setGameMode(mode);
    final getSettings = await _getPlayerSettings;
    final saveSettings = await _savePlayerSettings;
    final settings = await getSettings();
    await saveSettings(settings.copyWith(gameMode: mode));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final appSettings = AppSettingsScope.maybeOf(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _MenuBackgroundPainter(_backgroundController.value),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 3),
                  _PixelWordmark(text: localizations.appTitle),
                  const SizedBox(height: 12),
                  Text(
                    localizations.homeSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.mutedText,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(flex: 2),
                  // Listen to the controller directly: AppSettingsScope's
                  // updateShouldNotify compares controller identity (stable
                  // for the app's lifetime), so a plain maybeOf read would
                  // never rebuild this screen and the toggle would appear
                  // stuck on its startup value after a tap.
                  if (appSettings == null)
                    _GameModeToggle(
                      selected: GameMode.twoD,
                      onChanged: _setGameMode,
                    )
                  else
                    ListenableBuilder(
                      listenable: appSettings,
                      builder: (context, _) => _GameModeToggle(
                        selected: appSettings.gameMode,
                        onChanged: _setGameMode,
                      ),
                    ),
                  const Spacer(flex: 2),
                  _MenuNavButton(
                    icon: Icons.grid_view_rounded,
                    label: localizations.levels,
                    accentColor: AppTheme.neonMint,
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.levels),
                  ),
                  const SizedBox(height: 10),
                  _MenuNavButton(
                    icon: Icons.leaderboard_rounded,
                    label: localizations.leaderboard,
                    accentColor: AppTheme.neonBlue,
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.leaderboardLevelPicker),
                  ),
                  const SizedBox(height: 10),
                  _MenuNavButton(
                    icon: Icons.settings_rounded,
                    label: localizations.settings,
                    accentColor: AppTheme.neonPurple,
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.settings),
                  ),
                  const SizedBox(height: 10),
                  _MenuNavButton(
                    icon: Icons.view_in_ar_rounded,
                    label: localizations.challenges,
                    accentColor: AppTheme.neonPink,
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.challenges),
                  ),
                  const Spacer(flex: 2),
                  _DebugRow(
                    label: localizations.backendUrlLabel,
                    value: AppConfig.apiBaseUrl,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuNavButton extends StatefulWidget {
  const _MenuNavButton({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback? onPressed;

  @override
  State<_MenuNavButton> createState() => _MenuNavButtonState();
}

class _MenuNavButtonState extends State<_MenuNavButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (!_enabled) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.95 : 1.0;
    final color = _enabled ? widget.accentColor : AppTheme.mutedText;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: _enabled ? 1 : 0.3),
              width: 1.5,
            ),
            boxShadow: _enabled
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: _pressed ? 0.15 : 0.28),
                      blurRadius: _pressed ? 6 : 14,
                      spreadRadius: _pressed ? 0 : 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: color, size: 21),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: _enabled ? AppTheme.softText : AppTheme.mutedText,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: color.withValues(alpha: _enabled ? 0.6 : 0.2),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Nodus title in the Pixel Game display face: neon-blue interior with a
/// darker blue border, drawn as two stacked texts (stroke pass underneath,
/// fill pass on top) since Flutter has no single-pass text outline.
class _PixelWordmark extends StatelessWidget {
  const _PixelWordmark({required this.text});

  final String text;

  static const _style = TextStyle(
    fontFamily: 'PixelGame',
    fontSize: 68,
    letterSpacing: 3,
    height: 1.0,
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: _style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..strokeJoin = StrokeJoin.round
              ..color = AppTheme.neonBlueDark,
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: _style.copyWith(color: AppTheme.neonBlue),
        ),
      ],
    );
  }
}

/// Pill-shaped 2D/3D switcher shown under the wordmark. The selected mode is
/// unmistakable: filled with its accent color, glowing shadow, dark label;
/// the unselected side stays transparent and muted.
class _GameModeToggle extends StatelessWidget {
  const _GameModeToggle({required this.selected, required this.onChanged});

  final GameMode selected;
  final ValueChanged<GameMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Center(
      child: Container(
        key: GameUiKeys.gameModeSelector,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.mutedText.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModeSegment(
              label: localizations.gameMode2D,
              accentColor: AppTheme.neonMint,
              selected: selected == GameMode.twoD,
              onTap: () => onChanged(GameMode.twoD),
            ),
            const SizedBox(width: 4),
            _ModeSegment(
              label: localizations.gameMode3D,
              accentColor: AppTheme.neonBlue,
              selected: selected == GameMode.threeD,
              onTap: () => onChanged(GameMode.threeD),
            ),
            const SizedBox(width: 4),
            _ModeSegment(
              label: localizations.gameModeHex,
              accentColor: AppTheme.neonPurple,
              selected: selected == GameMode.hex,
              onTap: () => onChanged(GameMode.hex),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    required this.label,
    required this.accentColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color accentColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.45),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          // Same pixel face as the wordmark; no synthetic bold on top of a
          // bitmap-style font.
          style: TextStyle(
            fontFamily: 'PixelGame',
            fontSize: 17,
            letterSpacing: 1,
            color: selected ? AppTheme.background : AppTheme.mutedText,
          ),
        ),
      ),
    );
  }
}

class _DebugRow extends StatelessWidget {
  const _DebugRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: AppTheme.mutedText, fontSize: 11),
          ),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.mutedText, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lightweight animated background: a handful of soft neon-tinted glows
/// drifting in slow circular orbits over the dark base color. Pure
/// [CustomPainter] geometry — no images, shaders, or physics — so it stays
/// cheap on low-end Android.
class _MenuBackgroundPainter extends CustomPainter {
  _MenuBackgroundPainter(this.t);

  final double t;

  static const _colors = [
    AppTheme.neonMint,
    AppTheme.neonBlue,
    AppTheme.neonPurple,
    AppTheme.neonPink,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppTheme.background,
    );

    final angle = t * 2 * math.pi;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.55;

    for (var i = 0; i < _colors.length; i++) {
      final orbitAngle = angle + (i * math.pi / 2);
      final orbitRadius = radius * (0.5 + 0.15 * i);
      final glowCenter = center +
          Offset(
            math.cos(orbitAngle) * orbitRadius,
            math.sin(orbitAngle) * orbitRadius * 0.6,
          );

      final paint = Paint()
        ..color = _colors[i].withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

      canvas.drawCircle(glowCenter, size.shortestSide * 0.35, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MenuBackgroundPainter oldDelegate) =>
      oldDelegate.t != t;
}

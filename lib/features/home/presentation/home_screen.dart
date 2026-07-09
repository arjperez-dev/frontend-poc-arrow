// Game name: "Nodus" (Latin for "knot" / "node"). The core mechanic is
// untangling a graph of nodes and edges, so a word that literally means
// "knot" reads as on-theme without being generic ("Puzzle", "Arrow", "Game").
// Short, pronounceable across locales, and free of the placeholder "POC"
// branding this screen previously carried.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';

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

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

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
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppTheme.neonMint, AppTheme.neonBlue],
                    ).createShader(bounds),
                    child: Text(
                      localizations.appTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ),
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
                  const Spacer(flex: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _MenuNavButton(
                          icon: Icons.grid_view_rounded,
                          label: localizations.levels,
                          accentColor: AppTheme.neonMint,
                          onPressed: () => Navigator.of(
                            context,
                          ).pushNamed(AppRoutes.levels),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MenuNavButton(
                          icon: Icons.leaderboard_rounded,
                          label: localizations.leaderboard,
                          accentColor: AppTheme.neonBlue,
                          onPressed: () => Navigator.of(
                            context,
                          ).pushNamed(AppRoutes.leaderboardLevelPicker),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MenuNavButton(
                          icon: Icons.settings_rounded,
                          label: localizations.settings,
                          accentColor: AppTheme.neonPurple,
                          onPressed: () => Navigator.of(
                            context,
                          ).pushNamed(AppRoutes.settings),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MenuNavButton(
                          icon: Icons.view_in_ar_rounded,
                          label: localizations.gameMode,
                          accentColor: AppTheme.neonPink,
                          onPressed: null,
                        ),
                      ),
                    ],
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
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: _enabled ? AppTheme.softText : AppTheme.mutedText,
                ),
              ),
            ],
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

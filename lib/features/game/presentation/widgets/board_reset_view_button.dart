import 'package:flutter/material.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../game_ui_keys.dart';

/// Reset-view button shared by the 2D and 3D boards. The [icon] differs per
/// board on purpose: recenter (pan/zoom) on the flat board, reset-rotation
/// on the perspective board.
class BoardResetViewButton extends StatelessWidget {
  const BoardResetViewButton({
    required this.onPressed,
    required this.icon,
    super.key,
  });

  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Tooltip(
      message: localizations.resetView,
      child: Material(
        color: AppTheme.surface.withValues(alpha: 0.85),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          key: GameUiKeys.resetViewButton,
          icon: Icon(icon, size: 20),
          tooltip: localizations.resetView,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

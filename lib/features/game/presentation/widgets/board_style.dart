import 'dart:ui';

import '../../../../core/theme/app_theme.dart';

/// Visual constants shared by the 2D and 3D board painters, so the two
/// renderers can never drift apart on arrow identity or collision feedback.

/// Flash color for an arrow that just collided (same on both boards).
const Color collisionFlashColor = Color(0xFFFF4444);

/// An arrow's color is a pure function of its id: the same arrow must look
/// identical on the flat board and on the perspective board.
Color arrowColorFor(String id) {
  const colors = [
    AppTheme.neonBlue,
    AppTheme.neonGreen,
    AppTheme.neonYellow,
    AppTheme.neonPink,
    AppTheme.neonPurple,
  ];
  return colors[id.hashCode.abs() % colors.length];
}

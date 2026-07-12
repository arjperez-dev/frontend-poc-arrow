import 'package:flutter/material.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../game/presentation/game_ui_keys.dart';
import '../domain/challenge.dart';

/// Entry point for the main-menu "Challenges" button: pick a challenge
/// modifier, then choose a level from the ordinary level list (same 2D/3D
/// mode and the same unlocks as campaign play — a challenge changes the
/// rules, not the content).
class ChallengePickerScreen extends StatelessWidget {
  const ChallengePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.challenges)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _ChallengeCard(
              challenge: Challenge.timeAttack,
              icon: Icons.timer_rounded,
              accentColor: AppTheme.neonBlue,
              title: localizations.challengeTimeAttack,
              description: localizations.challengeTimeAttackDescription,
            ),
            const SizedBox(height: 12),
            _ChallengeCard(
              challenge: Challenge.moveLimit,
              icon: Icons.touch_app_rounded,
              accentColor: AppTheme.neonYellow,
              title: localizations.challengeMoveLimit,
              description: localizations.challengeMoveLimitDescription,
            ),
            const SizedBox(height: 12),
            _ChallengeCard(
              challenge: Challenge.perfectRun,
              icon: Icons.workspace_premium_rounded,
              accentColor: AppTheme.neonPink,
              title: localizations.challengePerfectRun,
              description: localizations.challengePerfectRunDescription,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.description,
  });

  final Challenge challenge;
  final IconData icon;
  final Color accentColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: GameUiKeys.challengeCard(challenge),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.of(
          context,
        ).pushNamed(AppRoutes.levels, arguments: challenge),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accentColor.withValues(alpha: 0.35)),
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
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
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }
}

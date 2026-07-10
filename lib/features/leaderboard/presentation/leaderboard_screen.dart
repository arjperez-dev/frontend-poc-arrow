import 'package:flutter/material.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/leaderboard_entry.dart';
import '../infrastructure/leaderboard_dependencies.dart';

typedef LoadLeaderboardForLevel =
    Future<List<LeaderboardEntry>> Function(int levelNumber);

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    required this.levelNumber,
    this.loadEntries,
    super.key,
  });

  final int? levelNumber;

  /// Test seam (same pattern as GameScreen's injectable use cases). When
  /// null, the production use case is created via [LeaderboardDependencies].
  final LoadLeaderboardForLevel? loadEntries;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final Future<List<LeaderboardEntry>> _entriesFuture = _loadEntries();

  Future<List<LeaderboardEntry>> _loadEntries() async {
    final levelNumber = widget.levelNumber;
    if (levelNumber == null) {
      return const <LeaderboardEntry>[];
    }
    final loadEntries = widget.loadEntries ??
        (await LeaderboardDependencies
                .createGetLeaderboardForLevelNumberUseCase())
            .call;
    return loadEntries(levelNumber);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.leaderboard)),
      body: SafeArea(
        child: FutureBuilder<List<LeaderboardEntry>>(
          future: _entriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(localizations.leaderboardUnavailable));
            }
            final entries = snapshot.data ?? const <LeaderboardEntry>[];
            if (entries.isEmpty) {
              return Center(child: Text(localizations.leaderboardUnavailable));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.neonMint,
                      foregroundColor: AppTheme.background,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(entry.displayName),
                    subtitle: Text('${localizations.moves}: ${entry.moves}'),
                    trailing: Text(
                      '${entry.score}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

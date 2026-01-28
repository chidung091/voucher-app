import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../domain/player.dart';
import '../../domain/player_stats.dart';
import '../../domain/season.dart';
import '../../services/player_service.dart';
import '../../services/player_stats_service.dart';
import '../../services/season_service.dart';
import '../../widgets/error_view.dart';

class PlayerProfileScreen extends StatefulWidget {
  const PlayerProfileScreen({super.key, required this.playerId});

  final String playerId;

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  late Future<_ProfileView> _future;
  bool _showAllTime = true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProfileView> _load() async {
    final playerService = await PlayerService.create();
    final statsService = await PlayerStatsService.create();
    final seasonService = await SeasonService.create();
    final players = await playerService.listPlayers(includeDeleted: true);
    final player = players.firstWhere(
      (item) => item.id == widget.playerId,
      orElse: () => Player(
        id: widget.playerId,
        displayName: 'Unknown',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final stats = await statsService.getPlayerStats(widget.playerId);
    SeasonRow? seasonRow;
    Season? season;
    try {
      final config = await seasonService.getSeasonConfig();
      season =
          seasonService.getCurrentSeason(DateTime.now(), config.seasonType);
      final leaderboard = await seasonService.getSeasonLeaderboard(
        season.id,
        config.seasonType,
      );
      final matching = leaderboard.rows
          .where((row) => row.playerId == widget.playerId)
          .toList();
      seasonRow = matching.isEmpty ? null : matching.first;
    } catch (_) {}
    return _ProfileView(
      player: player,
      stats: stats,
      season: season,
      seasonRow: seasonRow,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProfileView>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(
            title: 'Unable to load player',
            message: snapshot.error.toString(),
            onRetry: () => setState(() => _future = _load()),
          );
        }
        final view = snapshot.data;
        if (view == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = view.stats;
        final theme = Theme.of(context);
        final showWarning = stats.totalMatches > 0 &&
            stats.eloHistory.length - 1 < stats.totalMatches;

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _HeaderCard(player: view.player, stats: stats),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Overall results',
              child: Column(
                children: [
                  _StatRow(
                    items: [
                      _StatItem(label: 'Wins', value: '${stats.wins}'),
                      _StatItem(label: 'Draws', value: '${stats.draws}'),
                      _StatItem(label: 'Losses', value: '${stats.losses}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _StatRow(
                    items: [
                      _StatItem(
                        label: 'Matches',
                        value: '${stats.totalMatches}',
                      ),
                      _StatItem(
                        label: 'Win rate',
                        value: '${stats.winRatePercent.toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Goals',
              child: _StatRow(
                items: [
                  _StatItem(label: 'GF', value: '${stats.goalsFor}'),
                  _StatItem(label: 'GA', value: '${stats.goalsAgainst}'),
                  _StatItem(label: 'GD', value: '${stats.goalDifference}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Streaks',
              child: Column(
                children: [
                  _StatRow(
                    items: [
                      _StatItem(
                        label: 'Current wins',
                        value: '${stats.currentWinStreak}',
                      ),
                      _StatItem(
                        label: 'Best wins',
                        value: '${stats.bestWinStreak}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _StatRow(
                    items: [
                      _StatItem(
                        label: 'Current losses',
                        value: '${stats.currentLoseStreak}',
                      ),
                      _StatItem(
                        label: 'Worst losses',
                        value: '${stats.worstLoseStreak}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Elo extremes',
              child: _StatRow(
                items: [
                  _StatItem(label: 'Peak', value: '${stats.peakElo}'),
                  _StatItem(label: 'Lowest', value: '${stats.lowestElo}'),
                ],
              ),
            ),
            if (view.season != null) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'This season (${view.season!.id})',
                child: view.seasonRow == null
                    ? const Text('No season data yet.')
                    : Column(
                        children: [
                          _StatRow(
                            items: [
                              _StatItem(
                                label: 'Season Elo',
                                value: '${view.seasonRow!.seasonElo}',
                              ),
                              _StatItem(
                                label: 'Delta',
                                value: _formatDelta(
                                  view.seasonRow!.deltaFromStart,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _StatRow(
                            items: [
                              _StatItem(
                                label: 'Matches',
                                value: '${view.seasonRow!.matchesPlayed}',
                              ),
                              _StatItem(
                                label: 'W-D-L',
                                value:
                                    '${view.seasonRow!.wins}-${view.seasonRow!.draws}-${view.seasonRow!.losses}',
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ],
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Elo history',
              trailing: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All time'),
                    selected: _showAllTime,
                    onSelected: (value) {
                      setState(() => _showAllTime = true);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Last 20'),
                    selected: !_showAllTime,
                    onSelected: (value) {
                      setState(() => _showAllTime = false);
                    },
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showWarning)
                    Text(
                      'Elo history may be incomplete for some matches.',
                      style: theme.textTheme.bodySmall,
                    ),
                  if (showWarning) const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: _EloChart(
                      points: _selectPoints(stats.eloHistory),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _future = _load()),
              child: const Text('Refresh'),
            ),
          ],
        );
      },
    );
  }

  List<EloPoint> _selectPoints(List<EloPoint> points) {
    if (_showAllTime) {
      return points;
    }
    if (points.length <= 21) {
      return points;
    }
    return points.sublist(points.length - 21);
  }
}

class _ProfileView {
  const _ProfileView({
    required this.player,
    required this.stats,
    this.season,
    this.seasonRow,
  });

  final Player player;
  final PlayerStats stats;
  final Season? season;
  final SeasonRow? seasonRow;
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.player, required this.stats});

  final Player player;
  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withOpacity(0.3),
                    colorScheme.secondary.withOpacity(0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Center(
                child: Text(
                  player.displayName.isNotEmpty
                      ? player.displayName.substring(0, 1).toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.displayName,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      'Skill L${player.skillLevel}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  if (player.deletedAt != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.error.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        'Deleted',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Current Elo',
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  '${stats.currentElo}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.items});

  final List<_StatItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: item,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleLarge),
      ],
    );
  }
}

class _EloChart extends StatelessWidget {
  const _EloChart({required this.points});

  final List<EloPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.length < 2) {
      return Center(
        child: Text(
          'Not enough data yet.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    final minElo = points.map((point) => point.elo).reduce(_min);
    final maxElo = points.map((point) => point.elo).reduce(_max);
    final range = maxElo - minElo;
    final padding = range == 0 ? 20 : (range * 0.1).round();
    final minY = (minElo - padding).toDouble();
    final maxY = (maxElo + padding).toDouble();

    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].elo.toDouble()));
    }

    final labelIndexes = _labelIndexes(points.length);
    final dateFormat = DateFormat('MM/dd');

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            barWidth: 2,
            color: theme.colorScheme.primary,
            dotData: const FlDotData(show: false),
          ),
        ],
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: theme.textTheme.bodySmall,
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (!labelIndexes.contains(index) || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    dateFormat.format(points[index].timestamp),
                    style: theme.textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<int> _labelIndexes(int count) {
    if (count <= 4) {
      return List<int>.generate(count, (index) => index);
    }
    return <int>[0, (count / 2).floor(), count - 1];
  }

  int _min(int a, int b) => a < b ? a : b;

  int _max(int a, int b) => a > b ? a : b;
}

String _formatDelta(int delta) {
  if (delta >= 0) {
    return '+$delta';
  }
  return '$delta';
}

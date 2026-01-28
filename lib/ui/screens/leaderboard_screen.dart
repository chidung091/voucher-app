import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../domain/player.dart';
import '../../domain/player_rating.dart';
import '../../services/match_service.dart';
import '../../services/player_service.dart';
import '../components/components.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<PlayerService> _playerServiceFuture;
  late Future<MatchService> _matchServiceFuture;
  List<Player> _players = [];
  List<PlayerRating> _ratings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _playerServiceFuture = PlayerService.create();
    _matchServiceFuture = MatchService.create();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final playerService = await _playerServiceFuture;
    final matchService = await _matchServiceFuture;
    final players = await playerService.listPlayers();
    final ratings = await matchService.getLeaderboard();
    final activeIds = players.map((player) => player.id).toSet();
    final filteredRatings =
        ratings.where((rating) => activeIds.contains(rating.playerId)).toList();
    setState(() {
      _players = players;
      _ratings = filteredRatings;
      _isLoading = false;
    });
  }

  String _playerName(String id) {
    return _players
        .firstWhere(
          (player) => player.id == id,
          orElse: () => Player(
            id: id,
            displayName: 'Unknown',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        )
        .displayName;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: _ratings.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 100),
                EmptyState(
                  icon: Icons.emoji_events_outlined,
                  title: 'No matches yet',
                  message: 'Play some matches to see the leaderboard rankings.',
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: _ratings.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const SectionHeader(title: 'Rankings');
                }

                final rating = _ratings[index - 1];
                final rank = index;
                final playerName = _playerName(rating.playerId);

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    onTap: () => context.go('/players/${rating.playerId}'),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        // Rank Badge
                        _RankBadge(rank: rank),
                        const SizedBox(width: AppSpacing.md),

                        // Player Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                playerName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              // W/D/L Stats
                              Row(
                                children: [
                                  _MiniStat(
                                    label: 'W',
                                    value: rating.wins,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  _MiniStat(
                                    label: 'D',
                                    value: rating.draws,
                                    color: colorScheme.secondary,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  _MiniStat(
                                    label: 'L',
                                    value: rating.losses,
                                    color: colorScheme.error,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ELO Display
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${rating.elo}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            Text(
                              'ELO',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.white38,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    IconData? icon;

    switch (rank) {
      case 1:
        badgeColor = const Color(0xFFFFD700); // Gold
        icon = Icons.emoji_events;
        break;
      case 2:
        badgeColor = const Color(0xFFC0C0C0); // Silver
        icon = Icons.emoji_events;
        break;
      case 3:
        badgeColor = const Color(0xFFCD7F32); // Bronze
        icon = Icons.emoji_events;
        break;
      default:
        badgeColor = Colors.white24;
        icon = null;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(rank <= 3 ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: rank <= 3
            ? Border.all(color: badgeColor.withOpacity(0.5), width: 2)
            : null,
      ),
      child: Center(
        child: icon != null
            ? Icon(icon, color: badgeColor, size: 24)
            : Text(
                '#$rank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

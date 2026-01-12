import 'package:flutter/material.dart';

import '../../domain/player.dart';
import '../../domain/player_rating.dart';
import '../../services/match_service.dart';
import '../../services/player_service.dart';

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

  @override
  void initState() {
    super.initState();
    _playerServiceFuture = PlayerService.create();
    _matchServiceFuture = MatchService.create();
    _load();
  }

  Future<void> _load() async {
    final playerService = await _playerServiceFuture;
    final matchService = await _matchServiceFuture;
    final players = await playerService.listPlayers(includeDeleted: true);
    final ratings = await matchService.getLeaderboard();
    setState(() {
      _players = players;
      _ratings = ratings;
    });
  }

  String _playerName(String id) {
    return _players.firstWhere(
      (player) => player.id == id,
      orElse: () => Player(
        id: id,
        displayName: 'Unknown',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ).displayName;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Leaderboard',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (_ratings.isEmpty)
          const Text('No matches yet.')
        else
          ..._ratings.map(
            (rating) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(_playerName(rating.playerId)),
                subtitle: Text(
                  'W ${rating.wins}  D ${rating.draws}  L ${rating.losses}',
                ),
                trailing: Text('${rating.elo}'),
              ),
            ),
          ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _load,
          child: const Text('Refresh'),
        ),
      ],
    );
  }
}

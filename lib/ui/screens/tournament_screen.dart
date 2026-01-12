import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/local_store.dart';
import '../../domain/enums.dart';
import '../../domain/player.dart';
import '../../domain/player_rating.dart';
import '../../domain/tournament.dart';
import '../../domain/tournament_match.dart';
import '../../domain/tournament_team.dart';
import '../../services/player_service.dart';
import '../../services/team_balancer.dart';
import '../../services/tournament_service.dart';

class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  late Future<PlayerService> _playerServiceFuture;
  late Future<TournamentService> _tournamentServiceFuture;
  List<Player> _players = [];
  List<Tournament> _tournaments = [];

  @override
  void initState() {
    super.initState();
    _playerServiceFuture = PlayerService.create();
    _tournamentServiceFuture = TournamentService.create();
    _load();
  }

  Future<void> _load() async {
    final playerService = await _playerServiceFuture;
    final tournamentService = await _tournamentServiceFuture;
    final players = await playerService.listPlayers();
    final tournaments = await tournamentService.listTournaments();
    setState(() {
      _players = players;
      _tournaments = tournaments;
    });
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TournamentCreateScreen(players: _players),
      ),
    );
    await _load();
  }

  Future<void> _openDetail(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TournamentDetailScreen(tournamentId: id),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Tournaments',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            FilledButton(
              onPressed: _openCreate,
              child: const Text('Create'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_tournaments.isEmpty)
          const Text('No tournaments yet.')
        else
          ..._tournaments.map(
            (tournament) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(tournament.name),
                subtitle: Text(tournament.status.toJson()),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openDetail(tournament.id),
              ),
            ),
          ),
      ],
    );
  }
}

class TournamentCreateScreen extends StatefulWidget {
  const TournamentCreateScreen({super.key, required this.players});

  final List<Player> players;

  @override
  State<TournamentCreateScreen> createState() => _TournamentCreateScreenState();
}

class _TournamentCreateScreenState extends State<TournamentCreateScreen> {
  final TextEditingController _nameController = TextEditingController();
  MatchMode _mode = MatchMode.oneVOne;
  final Set<String> _pool = {};
  bool _autoBalance = true;
  bool _finalsEnabled = true;
  Map<String, int> _ratings = {};
  String? _error;

  Future<void> _create() async {
    final service = await TournamentService.create();
    try {
      if (_autoBalance) {
        await service.createTournamentAutoBalanced(
          name: _nameController.text,
          mode: _mode,
          playerIdsPool: _pool.toList(),
          finalsEnabled: _finalsEnabled,
        );
      } else {
        final teamInputs = _randomizeTeamsFromPool();
        await service.createTournament(
          TournamentInput(
            name: _nameController.text,
            mode: _mode,
            teams: teamInputs,
            finalsEnabled: _finalsEnabled,
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    final store = await LocalStore.getInstance();
    final ratings = await store.getRatings();
    setState(() {
      _ratings = ratings.map((key, value) => MapEntry(key, value.elo));
    });
  }

  List<TournamentTeamInput> _randomizeTeamsFromPool() {
    final poolPlayers = widget.players
        .where((player) => _pool.contains(player.id))
        .toList();
    final requiredCount = _mode == MatchMode.oneVOne ? 3 : 6;
    if (poolPlayers.length < requiredCount) {
      throw ArgumentError('Select at least $requiredCount players.');
    }
    final random = Random();
    poolPlayers.shuffle(random);
    final selected = poolPlayers.take(requiredCount).toList();
    final teams = <TournamentTeamInput>[];
    for (var i = 0; i < 3; i++) {
      final members = <String>[];
      members.add(selected[i].id);
      if (_mode == MatchMode.twoVTwo) {
        members.add(selected[i + 3].id);
      }
      teams.add(
        TournamentTeamInput(
          name: 'Team ${i + 1}',
          playerIds: members,
        ),
      );
    }
    return teams;
  }

  @override
  Widget build(BuildContext context) {
    final poolPlayers = widget.players
        .where((player) => _pool.contains(player.id))
        .toList();
    TeamBalanceResult? preview;
    String? poolError;
    if (_autoBalance) {
      final entries = TeamBalancer.buildPool(
        poolPlayers,
        _ratings.map(
          (key, value) => MapEntry(
            key,
            PlayerRating(
              playerId: key,
              elo: value,
              gamesPlayed: 0,
              wins: 0,
              draws: 0,
              losses: 0,
              updatedAt: DateTime.now(),
            ),
          ),
        ),
      );
      try {
        preview = _mode == MatchMode.oneVOne
            ? TeamBalancer().balanceFor1v1(entries)
            : TeamBalancer().balanceFor2v2(entries);
      } catch (error) {
        poolError = error.toString();
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Create Tournament')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Tournament name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MatchMode>(
            value: _mode,
            items: const [
              DropdownMenuItem(
                value: MatchMode.oneVOne,
                child: Text('1v1'),
              ),
              DropdownMenuItem(
                value: MatchMode.twoVTwo,
                child: Text('2v2'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _mode = value);
            },
            decoration: const InputDecoration(
              labelText: 'Mode',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Enable finals'),
            value: _finalsEnabled,
            onChanged: (value) => setState(() => _finalsEnabled = value),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Auto balance teams'),
            value: _autoBalance,
            onChanged: (value) => setState(() => _autoBalance = value),
          ),
          const SizedBox(height: 8),
          Text(
            'Player pool',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final player in widget.players)
                FilterChip(
                  selected: _pool.contains(player.id),
                  label: Text(player.displayName),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _pool.add(player.id);
                      } else {
                        _pool.remove(player.id);
                      }
                    });
                  },
                ),
            ],
          ),
          if (poolError != null) ...[
            const SizedBox(height: 8),
            Text(poolError, style: const TextStyle(color: Colors.red)),
          ],
          if (_autoBalance && preview != null) ...[
            const SizedBox(height: 12),
            Text(
              'Preview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < preview.teams.length; i++)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('Team ${i + 1}'),
                  subtitle: Text(
                    preview.teams[i]
                        .map((entry) =>
                            '${entry.player.displayName} (${entry.elo})')
                        .join(', '),
                  ),
                  trailing: Text('Total ${preview.teamTotals[i]}'),
                ),
              ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _create,
            child: const Text('Create Tournament'),
          ),
        ],
      ),
    );
  }
}

class TournamentDetailScreen extends StatefulWidget {
  const TournamentDetailScreen({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  late Future<TournamentService> _serviceFuture;
  late Future<PlayerService> _playerServiceFuture;
  TournamentView? _view;
  List<Player> _players = [];

  @override
  void initState() {
    super.initState();
    _serviceFuture = TournamentService.create();
    _playerServiceFuture = PlayerService.create();
    _load();
  }

  Future<void> _load() async {
    final service = await _serviceFuture;
    final view = await service.getTournament(widget.tournamentId);
    final playerService = await _playerServiceFuture;
    final players = await playerService.listPlayers(includeDeleted: true);
    setState(() {
      _view = view;
      _players = players;
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

  Future<void> _recordResult(
    TournamentMatch match,
    int scoreHome,
    int scoreAway,
  ) async {
    final service = await _serviceFuture;
    await service.recordTournamentMatchResult(
      tournamentId: widget.tournamentId,
      tournamentMatchId: match.id,
      scoreHome: scoreHome,
      scoreAway: scoreAway,
    );
    await _load();
  }

  Future<void> _forfeit(
    TournamentMatch match,
    int winnerTeamIndex,
  ) async {
    final service = await _serviceFuture;
    await service.recordFinalForfeit(
      tournamentId: widget.tournamentId,
      tournamentMatchId: match.id,
      winnerTeamIndex: winnerTeamIndex,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    if (view == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(view.tournament.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Teams',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (view.tournament.status != TournamentStatus.completed) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Enable finals'),
              value: view.tournament.finalsEnabled,
              onChanged: (value) async {
                final service = await _serviceFuture;
                await service.setFinalsEnabled(
                  tournamentId: widget.tournamentId,
                  enabled: value,
                );
                await _load();
              },
            ),
          ],
          const SizedBox(height: 8),
          ...view.teams.map(
            (team) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(team.name),
                subtitle: Text(
                  team.playerIds.map(_playerName).join(', '),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Schedule',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...view.matches.map(
            (match) => _TournamentMatchCard(
              match: match,
              teams: view.teams,
              onSave: _recordResult,
              onForfeit: _forfeit,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Standings',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...view.standings.map(
            (standing) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('Team ${standing.teamIndex + 1}'),
                subtitle: Text(
                  'Pts ${standing.points}  GD ${standing.goalDifference}  GF ${standing.goalsFor}',
                ),
              ),
            ),
          ),
          if (view.tournament.status == TournamentStatus.completed &&
              view.tournament.championTeamIndex != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: const Text('Champion'),
                subtitle:
                    Text('Team ${view.tournament.championTeamIndex! + 1}'),
                trailing: const Icon(Icons.emoji_events_outlined),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TournamentMatchCard extends StatefulWidget {
  const _TournamentMatchCard({
    required this.match,
    required this.teams,
    required this.onSave,
    required this.onForfeit,
  });

  final TournamentMatch match;
  final List<TournamentTeam> teams;
  final void Function(TournamentMatch match, int scoreHome, int scoreAway)
      onSave;
  final void Function(TournamentMatch match, int winnerTeamIndex) onForfeit;

  @override
  State<_TournamentMatchCard> createState() => _TournamentMatchCardState();
}

class _TournamentMatchCardState extends State<_TournamentMatchCard> {
  final TextEditingController _scoreHome = TextEditingController(text: '0');
  final TextEditingController _scoreAway = TextEditingController(text: '0');

  @override
  void dispose() {
    _scoreHome.dispose();
    _scoreAway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = widget.teams.firstWhere(
      (team) => team.teamIndex == widget.match.homeTeamIndex,
      orElse: () => TournamentTeam(
        id: 'na',
        tournamentId: widget.match.tournamentId,
        teamIndex: widget.match.homeTeamIndex,
        name: 'TBD',
        playerIds: const [],
      ),
    );
    final away = widget.teams.firstWhere(
      (team) => team.teamIndex == widget.match.awayTeamIndex,
      orElse: () => TournamentTeam(
        id: 'na',
        tournamentId: widget.match.tournamentId,
        teamIndex: widget.match.awayTeamIndex,
        name: 'TBD',
        playerIds: const [],
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${home.name} vs ${away.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(widget.match.stage.toJson()),
            if (widget.match.status == TournamentMatchStatus.done)
              const Text('Completed'),
            if (widget.match.status != TournamentMatchStatus.done) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _scoreHome,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Home',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _scoreAway,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Away',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final homeScore = int.tryParse(_scoreHome.text) ?? 0;
                      final awayScore = int.tryParse(_scoreAway.text) ?? 0;
                      widget.onSave(widget.match, homeScore, awayScore);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
              if (widget.match.stage == TournamentStage.finalStage &&
                  widget.match.homeTeamIndex >= 0 &&
                  widget.match.awayTeamIndex >= 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () =>
                          widget.onForfeit(widget.match, home.teamIndex),
                      child: const Text('Forfeit home'),
                    ),
                    TextButton(
                      onPressed: () =>
                          widget.onForfeit(widget.match, away.teamIndex),
                      child: const Text('Forfeit away'),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

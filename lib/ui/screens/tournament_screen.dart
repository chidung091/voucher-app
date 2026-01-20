import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/local_store.dart';
import '../../domain/club.dart';
import '../../domain/enums.dart';
import '../../domain/player.dart';
import '../../domain/player_rating.dart';
import '../../domain/tournament.dart';
import '../../domain/tournament_match.dart';
import '../../domain/tournament_team.dart';
import '../../services/club_service.dart';
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
    final poolPlayers =
        widget.players.where((player) => _pool.contains(player.id)).toList();
    final minPlayers = _mode == MatchMode.oneVOne ? 2 : 3;
    if (poolPlayers.length < minPlayers) {
      throw ArgumentError('Select at least $minPlayers players.');
    }
    final random = Random();
    poolPlayers.shuffle(random);
    final teams = <TournamentTeamInput>[];
    if (_mode == MatchMode.oneVOne) {
      for (var i = 0; i < poolPlayers.length; i++) {
        teams.add(
          TournamentTeamInput(
            name: 'Team ${i + 1}',
            playerIds: [poolPlayers[i].id],
          ),
        );
      }
      return teams;
    }
    var teamIndex = 0;
    for (var i = 0; i + 1 < poolPlayers.length; i += 2) {
      teams.add(
        TournamentTeamInput(
          name: 'Team ${teamIndex + 1}',
          playerIds: [poolPlayers[i].id, poolPlayers[i + 1].id],
        ),
      );
      teamIndex += 1;
    }
    if (poolPlayers.length.isOdd) {
      teams.add(
        TournamentTeamInput(
          name: 'Team ${teamIndex + 1}',
          playerIds: [poolPlayers.last.id],
        ),
      );
    }
    return teams;
  }

  @override
  Widget build(BuildContext context) {
    final poolPlayers =
        widget.players.where((player) => _pool.contains(player.id)).toList();
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
                  title: Text(
                    'Team ${i + 1} (${preview.teams[i].length == 1 ? 'Solo' : 'Duo'})',
                  ),
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
  List<Club> _clubs = [];

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
    final clubService = await ClubService.create();
    final clubs = await clubService.listClubs(includeDeleted: true);
    setState(() {
      _view = view;
      _players = players;
      _clubs = clubs;
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

  Future<void> _recordResult(
    TournamentMatch match,
    int scoreHome,
    int scoreAway,
    MatchRatingMode ratingMode,
    double eloMultiplier,
  ) async {
    try {
      final service = await _serviceFuture;
      await service.recordTournamentMatchResult(
        tournamentId: widget.tournamentId,
        tournamentMatchId: match.id,
        scoreHome: scoreHome,
        scoreAway: scoreAway,
        ratingMode: ratingMode,
        eloMultiplier: eloMultiplier,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
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

  Future<void> _autoAssignAll() async {
    final service = await _serviceFuture;
    await service.autoAssignClubs(
      tournamentId: widget.tournamentId,
      force: true,
    );
    await _load();
  }

  Future<void> _autoAssignMatch(TournamentMatch match) async {
    final service = await _serviceFuture;
    await service.updateTournamentMatchClubAssignment(
      tournamentId: widget.tournamentId,
      matchId: match.id,
      mode: ClubAssignmentMode.auto,
      homeClubId: null,
      awayClubId: null,
      homeStars: null,
      awayStars: null,
    );
    await service.autoAssignClubs(
      tournamentId: widget.tournamentId,
      force: true,
      matchIds: {match.id},
    );
    await _load();
  }

  Future<void> _manualAssignMatch(
    TournamentMatch match,
    Club homeClub,
    Club awayClub,
  ) async {
    final service = await _serviceFuture;
    await service.updateTournamentMatchClubAssignment(
      tournamentId: widget.tournamentId,
      matchId: match.id,
      mode: ClubAssignmentMode.manual,
      homeClubId: homeClub.id,
      awayClubId: awayClub.id,
      homeStars: homeClub.stars,
      awayStars: awayClub.stars,
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
    const canDelete = true;
    return Scaffold(
      appBar: AppBar(
        title: Text(view.tournament.name),
        actions: [
          if (canDelete)
            IconButton(
              tooltip: 'Delete tournament',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete tournament'),
                    content: const Text(
                      'This will remove the tournament and its schedule.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                try {
                  final service = await _serviceFuture;
                  await service.deleteTournament(
                    tournamentId: widget.tournamentId,
                  );
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error.toString())),
                  );
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Teams',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset tournament results'),
                  content: const Text(
                    'This will delete all results and recalculate Elo for the remaining matches.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (confirm != true) return;
              final service = await _serviceFuture;
              await service.resetTournamentResults(
                tournamentId: widget.tournamentId,
              );
              await _load();
            },
            child: const Text('Reset results'),
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
                  '${team.playerIds.map(_playerName).join(', ')} '
                  '(${team.playerIds.length == 1 ? 'Solo' : 'Duo'})',
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Schedule',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: _clubs.any((club) => club.deletedAt == null)
                    ? _autoAssignAll
                    : null,
                child: const Text('Auto-assign clubs now'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_clubs.where((club) => club.deletedAt == null).isEmpty)
            Card(
              child: ListTile(
                title: const Text('No clubs yet'),
                subtitle: const Text('Add clubs to enable auto-assignments.'),
                trailing: TextButton(
                  onPressed: () => context.go('/clubs'),
                  child: const Text('Open Clubs'),
                ),
              ),
            ),
          ...view.matches.map(
            (match) => _TournamentMatchCard(
              match: match,
              teams: view.teams,
              clubs: _clubs,
              playerName: _playerName,
              onSave: _recordResult,
              onForfeit: _forfeit,
              onAutoAssign: _autoAssignMatch,
              onManualAssign: _manualAssignMatch,
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
    required this.clubs,
    required this.playerName,
    required this.onSave,
    required this.onForfeit,
    required this.onAutoAssign,
    required this.onManualAssign,
  });

  final TournamentMatch match;
  final List<TournamentTeam> teams;
  final List<Club> clubs;
  final String Function(String id) playerName;
  final Future<void> Function(
    TournamentMatch match,
    int scoreHome,
    int scoreAway,
    MatchRatingMode ratingMode,
    double eloMultiplier,
  ) onSave;
  final Future<void> Function(TournamentMatch match, int winnerTeamIndex)
      onForfeit;
  final Future<void> Function(TournamentMatch match) onAutoAssign;
  final Future<void> Function(
    TournamentMatch match,
    Club homeClub,
    Club awayClub,
  ) onManualAssign;

  @override
  State<_TournamentMatchCard> createState() => _TournamentMatchCardState();
}

class _TournamentMatchCardState extends State<_TournamentMatchCard> {
  final TextEditingController _scoreHome = TextEditingController(text: '0');
  final TextEditingController _scoreAway = TextEditingController(text: '0');
  bool _overrideRatingMode = false;
  MatchRatingMode _ratingMode = MatchRatingMode.tournament;

  @override
  void dispose() {
    _scoreHome.dispose();
    _scoreAway.dispose();
    super.dispose();
  }

  MatchRatingMode _effectiveRatingMode() {
    return _overrideRatingMode ? _ratingMode : MatchRatingMode.tournament;
  }

  double _effectiveMultiplier() {
    return _effectiveRatingMode().defaultMultiplier();
  }

  Club? _clubById(String? id) {
    if (id == null) return null;
    for (final club in widget.clubs) {
      if (club.id == id) return club;
    }
    return null;
  }

  String _teamPlayersLabel(TournamentTeam team) {
    if (team.playerIds.isEmpty) return 'TBD';
    return team.playerIds.map(widget.playerName).join('+');
  }

  String _teamSizeLabel(TournamentTeam team) {
    if (team.playerIds.length == 1) return 'Solo';
    if (team.playerIds.length == 2) return 'Duo';
    return 'TBD';
  }

  String _starsLabel(double? stars) {
    return stars == null ? '--' : _formatStars(stars);
  }

  String _formatStars(double value) {
    return '${value.toStringAsFixed(1)}★';
  }

  String _assignmentText(String side, Club? club, double? assignedStars) {
    final starsText =
        assignedStars == null ? '--' : _formatStars(assignedStars);
    final clubName = club?.name ?? 'No club';
    final mismatch =
        club != null && assignedStars != null && club.stars != assignedStars;
    final clubStars = mismatch ? ' (${_formatStars(club.stars)})' : '';
    return '$side: $starsText / $clubName$clubStars';
  }

  Future<void> _editClubs(Club? homeClub, Club? awayClub) async {
    final activeClubs = widget.clubs
        .where((club) => club.deletedAt == null)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    var auto = widget.match.clubAssignmentMode == ClubAssignmentMode.auto;
    Club? selectedHome =
        homeClub ?? (activeClubs.isNotEmpty ? activeClubs[0] : null);
    Club? selectedAway = awayClub ??
        (activeClubs.length > 1
            ? activeClubs[1]
            : (activeClubs.isEmpty ? null : activeClubs.first));

    final result = await showDialog<_ClubAssignmentResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Club assignment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Auto assign'),
                value: auto,
                onChanged: (value) => setState(() => auto = value),
              ),
              if (auto)
                Text(
                  'Auto uses Elo ranking to set stars and clubs.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (!auto) ...[
                const SizedBox(height: 8),
                if (activeClubs.isEmpty)
                  const Text('No clubs available.')
                else ...[
                  DropdownButtonFormField<Club>(
                    value: selectedHome,
                    decoration: const InputDecoration(labelText: 'Home club'),
                    items: activeClubs
                        .map(
                          (club) => DropdownMenuItem(
                            value: club,
                            child: Text(
                                '${club.name} - ${_formatStars(club.stars)}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => selectedHome = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Club>(
                    value: selectedAway,
                    decoration: const InputDecoration(labelText: 'Away club'),
                    items: activeClubs
                        .map(
                          (club) => DropdownMenuItem(
                            value: club,
                            child: Text(
                                '${club.name} - ${_formatStars(club.stars)}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => selectedAway = value),
                  ),
                ],
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: auto
                  ? () => Navigator.of(context).pop(
                        _ClubAssignmentResult(auto: true),
                      )
                  : (selectedHome == null || selectedAway == null)
                      ? null
                      : () => Navigator.of(context).pop(
                            _ClubAssignmentResult(
                              auto: false,
                              homeClub: selectedHome,
                              awayClub: selectedAway,
                            ),
                          ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    if (result.auto) {
      await widget.onAutoAssign(widget.match);
    } else if (result.homeClub != null && result.awayClub != null) {
      await widget.onManualAssign(
        widget.match,
        result.homeClub!,
        result.awayClub!,
      );
    }
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
        playerIds: const ['unknown'],
      ),
    );
    final away = widget.teams.firstWhere(
      (team) => team.teamIndex == widget.match.awayTeamIndex,
      orElse: () => TournamentTeam(
        id: 'na',
        tournamentId: widget.match.tournamentId,
        teamIndex: widget.match.awayTeamIndex,
        name: 'TBD',
        playerIds: const ['unknown'],
      ),
    );
    final homeClub = _clubById(widget.match.homeClubId);
    final awayClub = _clubById(widget.match.awayClubId);
    final modeLabel =
        widget.match.clubAssignmentMode == ClubAssignmentMode.manual
            ? 'MANUAL'
            : 'AUTO';
    final hasSoloHandicap = home.playerIds.length != away.playerIds.length &&
        (home.playerIds.length == 1 || away.playerIds.length == 1);
    final matchupLabel = '${_teamPlayersLabel(home)} [${_teamSizeLabel(home)}] '
        '${_starsLabel(widget.match.homeAssignedStars)} '
        'vs ${_teamPlayersLabel(away)} [${_teamSizeLabel(away)}] '
        '${_starsLabel(widget.match.awayAssignedStars)}';

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
            Row(
              children: [
                Text(widget.match.stage.toJson()),
                const SizedBox(width: 8),
                Text(
                  modeLabel,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                if (hasSoloHandicap) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Solo team receives +0.5 star handicap.',
                    child: const Icon(
                      Icons.info_outline,
                      size: 16,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              matchupLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(_assignmentText(
                'Home', homeClub, widget.match.homeAssignedStars)),
            Text(_assignmentText(
                'Away', awayClub, widget.match.awayAssignedStars)),
            TextButton(
              onPressed: widget.match.status == TournamentMatchStatus.done
                  ? null
                  : () => _editClubs(homeClub, awayClub),
              child: const Text('Edit clubs'),
            ),
            if (widget.match.status == TournamentMatchStatus.done)
              const Text('Completed'),
            if (widget.match.status != TournamentMatchStatus.done) ...[
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Override rating mode'),
                value: _overrideRatingMode,
                onChanged: (value) {
                  setState(() => _overrideRatingMode = value);
                },
              ),
              if (_overrideRatingMode) ...[
                const SizedBox(height: 4),
                DropdownButtonFormField<MatchRatingMode>(
                  value: _ratingMode,
                  items: const [
                    DropdownMenuItem(
                      value: MatchRatingMode.friendly,
                      child: Text('Friendly'),
                    ),
                    DropdownMenuItem(
                      value: MatchRatingMode.ranked,
                      child: Text('Ranked'),
                    ),
                    DropdownMenuItem(
                      value: MatchRatingMode.tournament,
                      child: Text('Tournament'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _ratingMode = value);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Rating mode',
                  ),
                ),
              ],
              Text(
                'Multiplier: ${_effectiveMultiplier().toStringAsFixed(1)}x',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _scoreHome,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Home',
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
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      final homeScore = int.tryParse(_scoreHome.text) ?? 0;
                      final awayScore = int.tryParse(_scoreAway.text) ?? 0;
                      await widget.onSave(
                        widget.match,
                        homeScore,
                        awayScore,
                        _effectiveRatingMode(),
                        _effectiveMultiplier(),
                      );
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
                      onPressed: () async {
                        await widget.onForfeit(
                          widget.match,
                          home.teamIndex,
                        );
                      },
                      child: const Text('Forfeit home'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await widget.onForfeit(
                          widget.match,
                          away.teamIndex,
                        );
                      },
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

class _ClubAssignmentResult {
  const _ClubAssignmentResult({
    required this.auto,
    this.homeClub,
    this.awayClub,
  });

  final bool auto;
  final Club? homeClub;
  final Club? awayClub;
}

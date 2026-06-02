import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../data/local_store.dart';
import '../../domain/club.dart';
import '../../domain/enums.dart';
import '../../domain/player.dart';
import '../../domain/player_rating.dart';
import '../../domain/tournament.dart';
import '../../domain/tournament_match.dart';
import '../../domain/tournament_standings.dart';
import '../../domain/tournament_team.dart';
import '../../services/club_service.dart';
import '../../services/player_service.dart';
import '../../services/team_balancer.dart';
import '../../services/tournament_service.dart';
import '../components/components.dart';

String _formatMatchMode(MatchMode mode) {
  return mode == MatchMode.oneVOne ? '1v1' : '2v2';
}

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
            PrimaryButton(
              onPressed: _openCreate,
              label: 'Create',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_tournaments.isEmpty)
          const Text('No tournaments yet.')
        else
          ..._tournaments.map(
            (tournament) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: CustomListTile(
                  title: tournament.name,
                  subtitle: tournament.status.toJson(),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDetail(tournament.id),
                ),
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
  String? _forceSoloPlayerId;

  Future<void> _create() async {
    final service = await TournamentService.create();
    try {
      if (_autoBalance) {
        await service.createTournamentAutoBalanced(
          name: _nameController.text,
          mode: _mode,
          playerIdsPool: _pool.toList(),
          finalsEnabled: _finalsEnabled,
          forceSoloPlayerId: _forceSoloPlayerId,
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

    // If we have a forced solo player in 2v2 odd scenario, ensure they are last (solo)
    // The current logic creates teams of 2 then the last one is solo.
    if (_mode == MatchMode.twoVTwo &&
        poolPlayers.length.isOdd &&
        _forceSoloPlayerId != null) {
      final soloIndex =
          poolPlayers.indexWhere((p) => p.id == _forceSoloPlayerId);
      if (soloIndex != -1) {
        final solo = poolPlayers.removeAt(soloIndex);
        poolPlayers
            .add(solo); // Move to end to be picked as the last team (solo)
      }
    }

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
            : TeamBalancer().balanceFor2v2(
                entries,
                forceSoloPlayerId: _forceSoloPlayerId,
              );
      } catch (error) {
        poolError = error.toString();
      }
    }

    final showSoloPicker =
        _mode == MatchMode.twoVTwo && poolPlayers.length.isOdd;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Tournament')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CustomTextField(
            controller: _nameController,
            label: 'Tournament name',
          ),
          const SizedBox(height: 12),
          DropdownField<MatchMode>(
            value: _mode,
            items: const [MatchMode.oneVOne, MatchMode.twoVTwo],
            displayBuilder: _formatMatchMode,
            itemBuilder: (mode) => Text(_formatMatchMode(mode)),
            onSelected: (value) {
              if (value == null) return;
              setState(() {
                _mode = value;
                if (!showSoloPicker) _forceSoloPlayerId = null;
              });
            },
            label: 'Mode',
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
                        if (_forceSoloPlayerId == player.id) {
                          _forceSoloPlayerId = null;
                        }
                      }
                    });
                  },
                ),
            ],
          ),
          if (showSoloPicker) ...[
            const SizedBox(height: 16),
            DropdownField<String?>(
              value: _forceSoloPlayerId,
              items: <String?>[null, ...poolPlayers.map((p) => p.id)],
              displayBuilder: (id) {
                final player = poolPlayers.firstWhere((p) => p.id == id);
                return 'Solo: ${player.displayName}';
              },
              itemBuilder: (id) {
                if (id == null) return const Text('Auto-detect Solo Player');
                final p = poolPlayers.firstWhere((p) => p.id == id);
                return Text('Solo: ${p.displayName}');
              },
              onSelected: (value) {
                setState(() => _forceSoloPlayerId = value);
              },
              label: 'Designate Solo Player (Optional)',
            ),
          ],
          if (poolError != null) ...[
            const SizedBox(height: 8),
            Text(
              poolError,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
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
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            onPressed: _create,
            label: 'Create Tournament',
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
    final activeClubs = _clubs.where((club) => club.deletedAt == null).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
                    builder: (context) => CustomDialog(
                      title: 'Delete tournament',
                      content: const Text(
                        'This will remove the tournament and its schedule.',
                      ),
                      actions: [
                        SecondaryButton(
                          label: 'Cancel',
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                        DangerButton(
                          label: 'Delete',
                          onPressed: () => Navigator.of(context).pop(true),
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
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.sports_soccer_outlined), text: 'Matches'),
              Tab(icon: Icon(Icons.leaderboard_outlined), text: 'Standings'),
              Tab(icon: Icon(Icons.groups_outlined), text: 'Teams'),
            ],
          ),
        ),
        body: Column(
          children: [
            _TournamentSummaryBar(
              view: view,
              onResetResults: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => CustomDialog(
                    title: 'Reset tournament results',
                    content: const Text(
                      'This will delete all results and recalculate Elo for the remaining matches.',
                    ),
                    actions: [
                      SecondaryButton(
                        label: 'Cancel',
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      DangerButton(
                        label: 'Reset',
                        onPressed: () => Navigator.of(context).pop(true),
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
              onFinalsChanged:
                  view.tournament.status == TournamentStatus.completed
                      ? null
                      : (value) async {
                          final service = await _serviceFuture;
                          await service.setFinalsEnabled(
                            tournamentId: widget.tournamentId,
                            enabled: value,
                          );
                          await _load();
                        },
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _TournamentMatchesTab(
                    view: view,
                    clubs: _clubs,
                    activeClubCount: activeClubs.length,
                    playerName: _playerName,
                    onOpenClubs: () => context.go('/clubs'),
                    onAutoAssignAll:
                        activeClubs.isEmpty ? null : _autoAssignAll,
                    onSave: _recordResult,
                    onForfeit: _forfeit,
                    onAutoAssign: _autoAssignMatch,
                    onManualAssign: _manualAssignMatch,
                  ),
                  _TournamentStandingsTab(
                    view: view,
                    playerName: _playerName,
                  ),
                  _TournamentTeamsTab(
                    view: view,
                    playerName: _playerName,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TournamentSummaryBar extends StatelessWidget {
  const _TournamentSummaryBar({
    required this.view,
    required this.onResetResults,
    required this.onFinalsChanged,
  });

  final TournamentView view;
  final VoidCallback onResetResults;
  final ValueChanged<bool>? onFinalsChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final completed = view.matches
        .where((match) => match.status == TournamentMatchStatus.done);

    return Material(
      color: colorScheme.surface,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  _InfoPill(
                    icon: Icons.flag_outlined,
                    label: view.tournament.status.toJson(),
                  ),
                  _InfoPill(
                    icon: Icons.grid_view_outlined,
                    label: _formatMatchMode(view.tournament.mode),
                  ),
                  _InfoPill(
                    icon: Icons.groups_outlined,
                    label: '${view.teams.length} teams',
                  ),
                  _InfoPill(
                    icon: Icons.sports_soccer_outlined,
                    label: '${completed.length}/${view.matches.length} played',
                  ),
                ],
              ),
            ),
            Tooltip(
              message: 'Reset results',
              child: IconButton.outlined(
                onPressed: onResetResults,
                icon: const Icon(Icons.restart_alt_outlined),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            if (onFinalsChanged != null)
              Tooltip(
                message: 'Enable finals',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events_outlined, size: 18),
                    Switch(
                      value: view.tournament.finalsEnabled,
                      onChanged: onFinalsChanged,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentMatchesTab extends StatelessWidget {
  const _TournamentMatchesTab({
    required this.view,
    required this.clubs,
    required this.activeClubCount,
    required this.playerName,
    required this.onOpenClubs,
    required this.onAutoAssignAll,
    required this.onSave,
    required this.onForfeit,
    required this.onAutoAssign,
    required this.onManualAssign,
  });

  final TournamentView view;
  final List<Club> clubs;
  final int activeClubCount;
  final String Function(String id) playerName;
  final VoidCallback onOpenClubs;
  final Future<void> Function()? onAutoAssignAll;
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
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Schedule',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: onAutoAssignAll,
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: const Text('Auto clubs'),
            ),
          ],
        ),
        if (activeClubCount == 0) ...[
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text('Add clubs to enable auto-assignments.'),
                ),
                TextButton(
                  onPressed: onOpenClubs,
                  child: const Text('Open Clubs'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        for (final match in view.matches)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _TournamentMatchCard(
              match: match,
              teams: view.teams,
              clubs: clubs,
              playerName: playerName,
              onSave: onSave,
              onForfeit: onForfeit,
              onAutoAssign: onAutoAssign,
              onManualAssign: onManualAssign,
            ),
          ),
      ],
    );
  }
}

class _TournamentStandingsTab extends StatelessWidget {
  const _TournamentStandingsTab({
    required this.view,
    required this.playerName,
  });

  final TournamentView view;
  final String Function(String id) playerName;

  TournamentTeam? _teamFor(int teamIndex) {
    for (final team in view.teams) {
      if (team.teamIndex == teamIndex) return team;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (view.tournament.status == TournamentStatus.completed &&
            view.tournament.championTeamIndex != null) ...[
          _ChampionCard(
            team: _teamFor(view.tournament.championTeamIndex!),
            playerName: playerName,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        for (var index = 0; index < view.standings.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _StandingCard(
              position: index + 1,
              standing: view.standings[index],
              team: _teamFor(view.standings[index].teamIndex),
              playerName: playerName,
            ),
          ),
      ],
    );
  }
}

class _ChampionCard extends StatelessWidget {
  const _ChampionCard({
    required this.team,
    required this.playerName,
  });

  final TournamentTeam? team;
  final String Function(String id) playerName;

  @override
  Widget build(BuildContext context) {
    final title = team?.name ?? 'Team';
    final subtitle =
        team == null ? 'Champion' : team!.playerIds.map(playerName).join(', ');

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(
            Icons.emoji_events_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Champion',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StandingCard extends StatelessWidget {
  const _StandingCard({
    required this.position,
    required this.standing,
    required this.team,
    required this.playerName,
  });

  final int position;
  final TournamentStanding standing;
  final TournamentTeam? team;
  final String Function(String id) playerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teamName = team?.name ?? 'Team ${standing.teamIndex + 1}';
    final players = team?.playerIds.map(playerName).join(', ') ?? 'Unknown';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            child: Text('$position'),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(teamName, style: theme.textTheme.titleSmall),
                Text(
                  players,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          _StandingStat(label: 'Pts', value: standing.points),
          _StandingStat(label: 'GD', value: standing.goalDifference),
          _StandingStat(label: 'GF', value: standing.goalsFor),
        ],
      ),
    );
  }
}

class _StandingStat extends StatelessWidget {
  const _StandingStat({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      child: Column(
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _TournamentTeamsTab extends StatelessWidget {
  const _TournamentTeamsTab({
    required this.view,
    required this.playerName,
  });

  final TournamentView view;
  final String Function(String id) playerName;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        for (final team in view.teams)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    child: Text('${team.teamIndex + 1}'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          team.playerIds.map(playerName).join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _InfoPill(
                    icon: team.playerIds.length == 1
                        ? Icons.person_outline
                        : Icons.group_outlined,
                    label: team.playerIds.length == 1 ? 'Solo' : 'Duo',
                  ),
                ],
              ),
            ),
          ),
      ],
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

  String _ratingModeLabel(MatchRatingMode mode) {
    switch (mode) {
      case MatchRatingMode.friendly:
        return 'Friendly';
      case MatchRatingMode.ranked:
        return 'Ranked';
      case MatchRatingMode.tournament:
        return 'Tournament';
    }
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
        builder: (context, setState) => CustomDialog(
          title: 'Club assignment',
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
            SecondaryButton(
              label: 'Cancel',
              onPressed: () => Navigator.of(context).pop(),
            ),
            PrimaryButton(
              label: 'Save',
              onPressed: auto
                  ? () => Navigator.of(context).pop(
                        const _ClubAssignmentResult(auto: true),
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
            ? 'Manual'
            : 'Auto';
    final hasSoloHandicap = home.playerIds.length != away.playerIds.length &&
        (home.playerIds.length == 1 || away.playerIds.length == 1);
    final isDone = widget.match.status == TournamentMatchStatus.done;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${home.name} vs ${away.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              _InfoPill(
                icon: widget.match.stage == TournamentStage.finalStage
                    ? Icons.emoji_events_outlined
                    : Icons.grid_view_outlined,
                label: widget.match.stage.toJson(),
              ),
              const SizedBox(width: AppSpacing.xs),
              _InfoPill(
                icon: isDone ? Icons.check_circle_outline : Icons.schedule,
                label: isDone ? 'Done' : 'Open',
              ),
              Tooltip(
                message: isDone
                    ? 'Completed matches cannot edit clubs'
                    : 'Edit clubs',
                child: IconButton(
                  onPressed:
                      isDone ? null : () => _editClubs(homeClub, awayClub),
                  icon: const Icon(Icons.shield_outlined),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackSides = constraints.maxWidth < 520;
              final homePanel = _MatchSidePanel(
                side: 'Home',
                team: home,
                players: _teamPlayersLabel(home),
                size: _teamSizeLabel(home),
                stars: _starsLabel(widget.match.homeAssignedStars),
                assignment: _assignmentText(
                  'Home',
                  homeClub,
                  widget.match.homeAssignedStars,
                ),
              );
              final awayPanel = _MatchSidePanel(
                side: 'Away',
                team: away,
                players: _teamPlayersLabel(away),
                size: _teamSizeLabel(away),
                stars: _starsLabel(widget.match.awayAssignedStars),
                assignment: _assignmentText(
                  'Away',
                  awayClub,
                  widget.match.awayAssignedStars,
                ),
              );

              if (stackSides) {
                return Column(
                  children: [
                    homePanel,
                    const SizedBox(height: AppSpacing.xs),
                    _VersusPill(label: modeLabel),
                    const SizedBox(height: AppSpacing.xs),
                    awayPanel,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: homePanel),
                  const SizedBox(width: AppSpacing.sm),
                  _VersusPill(label: modeLabel),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: awayPanel),
                ],
              );
            },
          ),
          if (hasSoloHandicap) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Solo team receives +0.5 star handicap.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          if (isDone) ...[
            const SizedBox(height: AppSpacing.sm),
            const _DoneBanner(),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Switch(
                  value: _overrideRatingMode,
                  onChanged: (value) {
                    setState(() => _overrideRatingMode = value);
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Expanded(
                  child: Text(
                    'Override rating mode',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                _InfoPill(
                  icon: Icons.speed,
                  label: '${_effectiveMultiplier().toStringAsFixed(1)}x',
                ),
              ],
            ),
            if (_overrideRatingMode) ...[
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<MatchRatingMode>(
                value: _ratingMode,
                isDense: true,
                items: MatchRatingMode.values
                    .map(
                      (mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(_ratingModeLabel(mode)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _ratingMode = value);
                },
                decoration: const InputDecoration(
                  labelText: 'Rating mode',
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _CompactScoreField(
                    controller: _scoreHome,
                    label: 'Home',
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: Text('-'),
                ),
                Expanded(
                  child: _CompactScoreField(
                    controller: _scoreAway,
                    label: 'Away',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Tooltip(
                  message: 'Save result',
                  child: IconButton.filled(
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
                    icon: const Icon(Icons.save_outlined),
                  ),
                ),
              ],
            ),
            if (widget.match.stage == TournamentStage.finalStage &&
                widget.match.homeTeamIndex >= 0 &&
                widget.match.awayTeamIndex >= 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await widget.onForfeit(
                        widget.match,
                        home.teamIndex,
                      );
                    },
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: const Text('Forfeit home'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await widget.onForfeit(
                        widget.match,
                        away.teamIndex,
                      );
                    },
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: const Text('Forfeit away'),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MatchSidePanel extends StatelessWidget {
  const _MatchSidePanel({
    required this.side,
    required this.team,
    required this.players,
    required this.size,
    required this.stars,
    required this.assignment,
  });

  final String side;
  final TournamentTeam team;
  final String players;
  final String size;
  final String stars;
  final String assignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.55),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                side,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '$size · $stars',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            team.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          Text(
            players,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            assignment,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _VersusPill extends StatelessWidget {
  const _VersusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'VS',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _DoneBanner extends StatelessWidget {
  const _DoneBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline,
              size: 16, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Completed',
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactScoreField extends StatelessWidget {
  const _CompactScoreField({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
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

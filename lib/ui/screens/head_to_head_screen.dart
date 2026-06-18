import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../domain/enums.dart';
import '../../domain/head_to_head.dart';
import '../../domain/player.dart';
import '../../services/head_to_head_service.dart';
import '../../services/match_service.dart';
import '../../services/player_service.dart';
import '../../widgets/responsive_page.dart';

class HeadToHeadScreen extends StatefulWidget {
  const HeadToHeadScreen({super.key});

  @override
  State<HeadToHeadScreen> createState() => _HeadToHeadScreenState();
}

class _HeadToHeadScreenState extends State<HeadToHeadScreen> {
  late Future<PlayerService> _playerServiceFuture;
  late Future<HeadToHeadService> _h2hServiceFuture;
  List<Player> _players = [];

  String? _playerA;
  String? _playerB;
  String? _playerC;
  String? _playerD;

  Future<HeadToHeadStats>? _h2h1v1Future;
  Future<HeadToHeadStats>? _h2h2v2Future;
  String? _error1v1;
  String? _error2v2;

  @override
  void initState() {
    super.initState();
    _playerServiceFuture = PlayerService.create();
    _h2hServiceFuture = HeadToHeadService.create();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    final playerService = await _playerServiceFuture;
    final players = await playerService.listPlayers(includeDeleted: true);
    setState(() => _players = players);
    _initSelections(players);
  }

  void _initSelections(List<Player> players) {
    if (players.isEmpty) return;
    if (_playerA == null && players.isNotEmpty) {
      _playerA = players[0].id;
    }
    if (_playerB == null && players.length >= 2) {
      _playerB = players[1].id;
    }
    if (_playerC == null && players.length >= 3) {
      _playerC = players[2].id;
    }
    if (_playerD == null && players.length >= 4) {
      _playerD = players[3].id;
    }
    _refresh1v1();
    _refresh2v2();
  }

  Future<void> _refresh1v1() async {
    final a = _playerA;
    final b = _playerB;
    if (a == null || b == null) {
      setState(() => _h2h1v1Future = null);
      return;
    }
    if (a == b) {
      setState(() {
        _error1v1 = 'Select two different players.';
        _h2h1v1Future = null;
      });
      return;
    }
    final service = await _h2hServiceFuture;
    setState(() {
      _error1v1 = null;
      _h2h1v1Future = service.getH2H1v1(a, b);
    });
  }

  Future<void> _refresh2v2() async {
    final a = _playerA;
    final b = _playerB;
    final c = _playerC;
    final d = _playerD;
    if (a == null || b == null || c == null || d == null) {
      setState(() => _h2h2v2Future = null);
      return;
    }
    final ids = [a, b, c, d];
    final unique = ids.toSet();
    if (unique.length != 4) {
      setState(() {
        _error2v2 = 'All four players must be different.';
        _h2h2v2Future = null;
      });
      return;
    }
    final service = await _h2hServiceFuture;
    setState(() {
      _error2v2 = null;
      _h2h2v2Future = service.getH2H2v2(a, b, c, d);
    });
  }

  void _normalizePairs() {
    final a = _playerA;
    final b = _playerB;
    final c = _playerC;
    final d = _playerD;
    if (a == null || b == null || c == null || d == null) return;
    final key = HeadToHeadKey.for2v2(a, b, c, d);
    setState(() {
      _playerA = key.ids[0];
      _playerB = key.ids[1];
      _playerC = key.ids[2];
      _playerD = key.ids[3];
    });
    _refresh2v2();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              tabs: [
                Tab(text: '1v1'),
                Tab(text: '2v2'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _build1v1Tab(),
                _build2v2Tab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _build1v1Tab() {
    if (_players.length < 2) {
      return const ResponsivePage(
        maxWidth: 720,
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('Add at least 2 players.'),
            ),
          ),
        ],
      );
    }
    final controls = Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _PlayerPickRow(
              label: 'Player A',
              value: _playerA,
              players: _players,
              onChanged: (value) {
                setState(() => _playerA = value);
                _refresh1v1();
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _PlayerPickRow(
              label: 'Player B',
              value: _playerB,
              players: _players,
              onChanged: (value) {
                setState(() => _playerB = value);
                _refresh1v1();
              },
            ),
            if (_error1v1 != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error1v1!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );

    return ResponsivePage(
      maxWidth: 1080,
      children: [
        ResponsiveSplit(
          breakpoint: 820,
          startFlex: 1,
          endFlex: 2,
          start: controls,
          end: _buildStatsSection(_h2h1v1Future),
        ),
      ],
    );
  }

  Widget _build2v2Tab() {
    if (_players.length < 4) {
      return const ResponsivePage(
        maxWidth: 720,
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('Add at least 4 players.'),
            ),
          ),
        ],
      );
    }
    final controls = Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Team AB',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: _normalizePairs,
                  child: const Text('Normalize pairs'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _PlayerPickRow(
              label: 'Player A',
              value: _playerA,
              players: _players,
              onChanged: (value) {
                setState(() => _playerA = value);
                _refresh2v2();
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _PlayerPickRow(
              label: 'Player B',
              value: _playerB,
              players: _players,
              onChanged: (value) {
                setState(() => _playerB = value);
                _refresh2v2();
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Team CD',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            _PlayerPickRow(
              label: 'Player C',
              value: _playerC,
              players: _players,
              onChanged: (value) {
                setState(() => _playerC = value);
                _refresh2v2();
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _PlayerPickRow(
              label: 'Player D',
              value: _playerD,
              players: _players,
              onChanged: (value) {
                setState(() => _playerD = value);
                _refresh2v2();
              },
            ),
            if (_error2v2 != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error2v2!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );

    return ResponsivePage(
      maxWidth: 1120,
      children: [
        ResponsiveSplit(
          breakpoint: 900,
          startFlex: 1,
          endFlex: 2,
          start: controls,
          end: _buildStatsSection(_h2h2v2Future),
        ),
      ],
    );
  }

  Widget _buildStatsSection(Future<HeadToHeadStats>? future) {
    if (future == null) {
      return const Text('Select players to view head-to-head stats.');
    }
    return FutureBuilder<HeadToHeadStats>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text(snapshot.error.toString());
        }
        final stats = snapshot.data;
        if (stats == null) {
          return const Text('No stats available.');
        }
        if (stats.totalMatches == 0) {
          return const Text('No matches yet for this matchup.');
        }
        final side1Label = stats.key.mode == MatchMode.oneVOne
            ? _playerLabel(stats.key.ids[0])
            : _sideLabel(stats.key.ids.sublist(0, 2));
        final side2Label = stats.key.mode == MatchMode.oneVOne
            ? _playerLabel(stats.key.ids[1])
            : _sideLabel(stats.key.ids.sublist(2, 4));
        final winRate = stats.totalMatches == 0
            ? 0.0
            : (stats.winsSide1 / stats.totalMatches) * 100;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$side1Label vs $side2Label',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Total: ${stats.totalMatches}'),
                    Text(
                      'W-D-L: ${stats.winsSide1}-${stats.draws}-${stats.winsSide2}',
                    ),
                    Text(
                      'Goals: ${stats.goalsForSide1}-${stats.goalsAgainstSide1}',
                    ),
                    Text('Win rate: ${winRate.toStringAsFixed(1)}%'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Recent matches',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...stats.recentMatches.map((summary) {
              final dateText =
                  DateFormat('MMM d, yyyy').format(summary.playedAt);
              final isFriendly = summary.ratingMode == MatchRatingMode.friendly;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    '$side1Label ${summary.scoreSide1} - ${summary.scoreSide2} $side2Label',
                  ),
                  subtitle: Text(dateText),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (summary.tournamentId != null)
                        const Chip(label: Text('Tournament')),
                      if (isFriendly)
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDelete(summary.matchId),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  String _playerLabel(String id) {
    final player = _players.firstWhere(
      (item) => item.id == id,
      orElse: () => Player(
        id: id,
        displayName: 'Unknown',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final suffix = player.deletedAt == null ? '' : ' (deleted)';
    return '${player.displayName}$suffix';
  }

  Future<void> _confirmDelete(String matchId) async {
    // simplified:
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Match'),
        content: const Text(
          'Are you sure you want to delete this match? This will recalculate Elo ratings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final matchService = await MatchService.create();
        await matchService.deleteMatch(matchId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Match deleted')),
          );
          _refresh1v1();
          _refresh2v2();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  String _sideLabel(List<String> ids) {
    if (ids.length == 1) {
      return _playerLabel(ids[0]);
    }
    final sorted = [...ids]..sort();
    return '${_playerLabel(sorted[0])} + ${_playerLabel(sorted[1])}';
  }
}

class _PlayerPickRow extends StatelessWidget {
  const _PlayerPickRow({
    required this.label,
    required this.value,
    required this.players,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<Player> players;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      items: players
          .map(
            (player) => DropdownMenuItem(
              value: player.id,
              child: Text(
                player.deletedAt == null
                    ? player.displayName
                    : '${player.displayName} (deleted)',
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

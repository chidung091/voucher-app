import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../domain/elo_config.dart';
import '../../domain/enums.dart';
import '../../domain/tournament_match.dart';
import '../../domain/tournament_team.dart';
import '../../services/player_service.dart';
import '../../services/tournament_service.dart';
import '../../widgets/responsive_page.dart';
import '../components/components.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _playerNameController = TextEditingController();
  late final Future<PlayerService> _playerServiceFuture;
  late final Future<TournamentService> _tournamentServiceFuture;
  List<_QuickTournamentMatch> _quickMatches = [];
  int _activeTournamentCount = 0;
  String? _playerError;
  String? _tournamentError;
  String? _submittingMatchId;
  bool _addingPlayer = false;
  bool _loadingTournaments = true;

  @override
  void initState() {
    super.initState();
    _playerServiceFuture = PlayerService.create();
    _tournamentServiceFuture = TournamentService.create();
    _loadTournaments();
  }

  @override
  void dispose() {
    _playerNameController.dispose();
    super.dispose();
  }

  Future<void> _addPlayer() async {
    final name = _playerNameController.text.trim();
    if (name.isEmpty) {
      setState(() => _playerError = 'Enter a player name.');
      return;
    }

    setState(() {
      _addingPlayer = true;
      _playerError = null;
    });
    try {
      final service = await _playerServiceFuture;
      await service.createPlayer(name);
      if (!mounted) return;
      _playerNameController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name added to players.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _playerError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _addingPlayer = false);
      }
    }
  }

  Future<void> _loadTournaments({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _loadingTournaments = true);
    }
    try {
      final service = await _tournamentServiceFuture;
      final tournaments = (await service.listTournaments())
          .where(
              (tournament) => tournament.status != TournamentStatus.completed)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final nextMatches = <_QuickTournamentMatch>[];
      for (final tournament in tournaments) {
        final view = await service.getTournament(tournament.id);
        TournamentMatch? nextMatch;
        for (final match in view.matches) {
          if (match.status == TournamentMatchStatus.scheduled &&
              match.homeTeamIndex >= 0 &&
              match.awayTeamIndex >= 0) {
            nextMatch = match;
            break;
          }
        }
        if (nextMatch != null) {
          nextMatches.add(_QuickTournamentMatch(view, nextMatch));
        }
      }
      if (!mounted) return;
      setState(() {
        _activeTournamentCount = tournaments.length;
        _quickMatches = nextMatches;
        _tournamentError = null;
        _loadingTournaments = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _tournamentError = error.toString();
        _loadingTournaments = false;
      });
    }
  }

  Future<void> _recordResult(
    _QuickTournamentMatch item,
    int scoreHome,
    int scoreAway,
  ) async {
    setState(() => _submittingMatchId = item.match.id);
    try {
      final service = await _tournamentServiceFuture;
      await service.recordTournamentMatchResult(
        tournamentId: item.view.tournament.id,
        tournamentMatchId: item.match.id,
        scoreHome: scoreHome,
        scoreAway: scoreAway,
      );
      await _loadTournaments(showLoading: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tournament result recorded.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not record result: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingMatchId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      maxWidth: 1120,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final introColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Home',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Add players and record tournament results without leaving this page.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                _buildQuickPlayerCard(context),
              ],
            );
            final resultsColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Active tournament results',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (!_loadingTournaments)
                      IconButton(
                        tooltip: 'Refresh tournaments',
                        onPressed: _loadTournaments,
                        icon: const Icon(Icons.refresh),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _buildTournamentResults(context),
              ],
            );

            if (constraints.maxWidth >= 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 360, child: introColumn),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(child: resultsColumn),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                introColumn,
                const SizedBox(height: AppSpacing.xl),
                resultsColumn,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickPlayerCard(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_add_alt_1_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Quick add player',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'New players start at ${EloConfig.defaultElo} ELO.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          CustomTextField(
            key: const Key('quick-player-name'),
            controller: _playerNameController,
            label: 'Player name',
            hint: 'Enter display name',
            errorText: _playerError,
            prefixIcon: const Icon(Icons.person_outline),
            onChanged: (_) {
              if (_playerError != null) {
                setState(() => _playerError = null);
              }
            },
            onSubmitted: (_) => _addPlayer(),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            key: const Key('quick-add-player'),
            label: 'Add player',
            icon: Icons.add,
            isLoading: _addingPlayer,
            onPressed: _addPlayer,
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentResults(BuildContext context) {
    if (_loadingTournaments) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tournamentError != null) {
      return AppCard(
        child: Text(
          'Could not load tournaments: $_tournamentError',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    if (_activeTournamentCount == 0) {
      return const _HomeEmptyState(
        icon: Icons.emoji_events_outlined,
        title: 'No active tournaments',
        message:
            'When a tournament is created, its next match appears here for quick scoring.',
      );
    }
    if (_quickMatches.isEmpty) {
      return const _HomeEmptyState(
        icon: Icons.hourglass_empty,
        title: 'No match ready for results',
        message: 'The active tournament has no playable scheduled match yet.',
      );
    }
    return Column(
      children: [
        for (final item in _quickMatches)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _QuickTournamentResultCard(
              key: ValueKey(item.match.id),
              item: item,
              isSubmitting: _submittingMatchId == item.match.id,
              onRecord: (scoreHome, scoreAway) =>
                  _recordResult(item, scoreHome, scoreAway),
            ),
          ),
      ],
    );
  }
}

class _QuickTournamentMatch {
  const _QuickTournamentMatch(this.view, this.match);

  final TournamentView view;
  final TournamentMatch match;

  TournamentTeam teamForIndex(int index) {
    return view.teams.firstWhere((team) => team.teamIndex == index);
  }
}

class _QuickTournamentResultCard extends StatefulWidget {
  const _QuickTournamentResultCard({
    super.key,
    required this.item,
    required this.isSubmitting,
    required this.onRecord,
  });

  final _QuickTournamentMatch item;
  final bool isSubmitting;
  final Future<void> Function(int scoreHome, int scoreAway) onRecord;

  @override
  State<_QuickTournamentResultCard> createState() =>
      _QuickTournamentResultCardState();
}

class _QuickTournamentResultCardState
    extends State<_QuickTournamentResultCard> {
  final TextEditingController _homeScore = TextEditingController(text: '0');
  final TextEditingController _awayScore = TextEditingController(text: '0');

  @override
  void dispose() {
    _homeScore.dispose();
    _awayScore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final home = item.teamForIndex(item.match.homeTeamIndex);
    final away = item.teamForIndex(item.match.awayTeamIndex);
    final isFinal = item.match.stage == TournamentStage.finalStage;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.view.tournament.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Chip(label: Text(isFinal ? 'Final' : 'Group')),
            ],
          ),
          Text(
            'Next result',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _ScoreSide(
                  teamName: home.name,
                  label: 'Home',
                  controller: _homeScore,
                  fieldKey: Key('home-score-${item.match.id}'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  'vs',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: _ScoreSide(
                  teamName: away.name,
                  label: 'Away',
                  controller: _awayScore,
                  fieldKey: Key('away-score-${item.match.id}'),
                ),
              ),
            ],
          ),
          if (isFinal) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Final results cannot be a draw.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            key: Key('record-result-${item.match.id}'),
            label: 'Record result',
            icon: Icons.check,
            isLoading: widget.isSubmitting,
            onPressed: () {
              final homeScore = int.tryParse(_homeScore.text) ?? 0;
              final awayScore = int.tryParse(_awayScore.text) ?? 0;
              widget.onRecord(homeScore, awayScore);
            },
          ),
        ],
      ),
    );
  }
}

class _ScoreSide extends StatelessWidget {
  const _ScoreSide({
    required this.teamName,
    required this.label,
    required this.controller,
    required this.fieldKey,
  });

  final String teamName;
  final String label;
  final TextEditingController controller;
  final Key fieldKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          teamName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: fieldKey,
          controller: controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: label),
        ),
      ],
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Icon(
            icon,
            size: 36,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

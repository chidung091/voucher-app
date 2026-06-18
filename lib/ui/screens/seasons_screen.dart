import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/enums.dart';
import '../../domain/player.dart';
import '../../domain/season.dart';
import '../../services/player_service.dart';
import '../../services/season_service.dart';
import '../../widgets/error_view.dart';
import '../../widgets/responsive_page.dart';

class SeasonsScreen extends StatefulWidget {
  const SeasonsScreen({super.key});

  @override
  State<SeasonsScreen> createState() => _SeasonsScreenState();
}

class _SeasonsScreenState extends State<SeasonsScreen> {
  late Future<SeasonService> _seasonServiceFuture;
  late Future<PlayerService> _playerServiceFuture;
  final TextEditingController _baselineController = TextEditingController();

  SeasonConfig? _config;
  SeasonType _seasonType = SeasonType.month;
  List<Season> _seasonOptions = [];
  String? _seasonId;
  Map<String, Player> _playerMap = {};
  Future<SeasonLeaderboard>? _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _seasonServiceFuture = SeasonService.create();
    _playerServiceFuture = PlayerService.create();
    _load();
  }

  @override
  void dispose() {
    _baselineController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final seasonService = await _seasonServiceFuture;
    final config = await seasonService.getSeasonConfig();
    final playerService = await _playerServiceFuture;
    final players = await playerService.listPlayers(includeDeleted: true);
    final seasonType = config.seasonType;
    final seasons = seasonService.listRecentSeasons(
      seasonType,
      count: _seasonCount(seasonType),
    );
    final current = seasonService.getCurrentSeason(DateTime.now(), seasonType);
    setState(() {
      _config = config;
      _seasonType = seasonType;
      _seasonOptions = seasons;
      _seasonId = current.id;
      _playerMap = {for (final player in players) player.id: player};
      _baselineController.text = config.baselineElo.toString();
    });
    _refreshLeaderboard();
  }

  int _seasonCount(SeasonType type) {
    switch (type) {
      case SeasonType.quarter:
        return 8;
      case SeasonType.year:
        return 5;
      case SeasonType.month:
      default:
        return 12;
    }
  }

  Future<void> _refreshLeaderboard() async {
    final id = _seasonId;
    if (id == null) return;
    final service = await _seasonServiceFuture;
    setState(() {
      _leaderboardFuture = service.getSeasonLeaderboard(id, _seasonType);
    });
  }

  Future<void> _updateConfig(SeasonConfig next) async {
    final service = await _seasonServiceFuture;
    final updated = next.copyWith(updatedAt: DateTime.now());
    await service.updateSeasonConfig(updated);
    setState(() => _config = updated);
    _refreshLeaderboard();
  }

  Future<void> _changeSeasonType(SeasonType type) async {
    final config = _config ?? SeasonConfig.defaults();
    final seasonService = await _seasonServiceFuture;
    final updated = config.copyWith(
      seasonType: type,
      updatedAt: DateTime.now(),
    );
    await seasonService.updateSeasonConfig(updated);
    final seasons = seasonService.listRecentSeasons(
      type,
      count: _seasonCount(type),
    );
    final current = seasonService.getCurrentSeason(DateTime.now(), type);
    setState(() {
      _config = updated;
      _seasonType = type;
      _seasonOptions = seasons;
      _seasonId = current.id;
    });
    _refreshLeaderboard();
  }

  void _updateBaseline(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Baseline Elo must be a positive number.')),
      );
      return;
    }
    final config =
        (_config ?? SeasonConfig.defaults()).copyWith(baselineElo: parsed);
    _updateConfig(config);
  }

  void _updateResetPolicy(SeasonResetPolicy policy) {
    final config =
        (_config ?? SeasonConfig.defaults()).copyWith(resetPolicy: policy);
    _updateConfig(config);
  }

  void _updateSoftAlpha(double value) {
    final config =
        (_config ?? SeasonConfig.defaults()).copyWith(softResetAlpha: value);
    setState(() => _config = config);
  }

  void _persistSoftAlpha(double value) {
    final config =
        (_config ?? SeasonConfig.defaults()).copyWith(softResetAlpha: value);
    _updateConfig(config);
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final leaderboard = _LeaderboardSection(
      future: _leaderboardFuture,
      playerMap: _playerMap,
      onRetry: _refreshLeaderboard,
    );
    final settings =
        config == null ? const SizedBox.shrink() : _buildSettingsCard(config);

    return ResponsivePage(
      maxWidth: 1120,
      children: [
        Text(
          'Seasons',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.md),
        _buildSeasonFilters(),
        const SizedBox(height: AppSpacing.lg),
        config == null
            ? leaderboard
            : ResponsiveSplit(
                breakpoint: 920,
                startFlex: 2,
                endFlex: 1,
                start: leaderboard,
                end: settings,
              ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonFilters() {
    final seasonTypeField = DropdownButtonFormField<SeasonType>(
      value: _seasonType,
      decoration: const InputDecoration(
        labelText: 'Season type',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(
          value: SeasonType.month,
          child: Text('Month'),
        ),
        DropdownMenuItem(
          value: SeasonType.quarter,
          child: Text('Quarter'),
        ),
        DropdownMenuItem(
          value: SeasonType.year,
          child: Text('Year'),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;
        _changeSeasonType(value);
      },
    );
    final seasonField = DropdownButtonFormField<String>(
      value: _seasonId,
      decoration: const InputDecoration(
        labelText: 'Season',
        border: OutlineInputBorder(),
      ),
      items: _seasonOptions
          .map(
            (season) => DropdownMenuItem(
              value: season.id,
              child: Text(season.id),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() => _seasonId = value);
        _refreshLeaderboard();
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              seasonTypeField,
              const SizedBox(height: AppSpacing.md),
              seasonField,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: seasonTypeField),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: seasonField),
          ],
        );
      },
    );
  }

  Widget _buildSettingsCard(SeasonConfig config) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Season settings', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _baselineController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Baseline Elo',
                border: OutlineInputBorder(),
              ),
              onSubmitted: _updateBaseline,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SeasonResetPolicy>(
              value: config.resetPolicy,
              decoration: const InputDecoration(
                labelText: 'Reset policy',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: SeasonResetPolicy.none,
                  child: Text('None'),
                ),
                DropdownMenuItem(
                  value: SeasonResetPolicy.hardReset,
                  child: Text('Hard reset'),
                ),
                DropdownMenuItem(
                  value: SeasonResetPolicy.softReset,
                  child: Text('Soft reset'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                _updateResetPolicy(value);
              },
            ),
            if (config.resetPolicy == SeasonResetPolicy.softReset) ...[
              const SizedBox(height: 12),
              Text(
                  'Soft reset alpha: ${config.softResetAlpha.toStringAsFixed(2)}'),
              Slider(
                value: config.softResetAlpha.clamp(0.0, 1.0),
                onChanged: _updateSoftAlpha,
                onChangeEnd: _persistSoftAlpha,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LeaderboardSection extends StatelessWidget {
  const _LeaderboardSection({
    required this.future,
    required this.playerMap,
    required this.onRetry,
  });

  final Future<SeasonLeaderboard>? future;
  final Map<String, Player> playerMap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (future == null) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<SeasonLeaderboard>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(
            title: 'Unable to load season',
            message: snapshot.error.toString(),
            onRetry: onRetry,
          );
        }
        final leaderboard = snapshot.data;
        if (leaderboard == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = leaderboard.rows;
        if (rows.isEmpty) {
          return const Text('No matches found for this season.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leaderboard.boundaryEstimated)
              const Text(
                'Season start Elo uses current ratings (rating events missing).',
              ),
            if (leaderboard.boundaryEstimated) const SizedBox(height: 8),
            ...rows.asMap().entries.map(
                  (entry) => _SeasonRowCard(
                    rank: entry.key + 1,
                    row: entry.value,
                    player: playerMap[entry.value.playerId],
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _SeasonRowCard extends StatelessWidget {
  const _SeasonRowCard({
    required this.rank,
    required this.row,
    required this.player,
  });

  final int rank;
  final SeasonRow row;
  final Player? player;

  @override
  Widget build(BuildContext context) {
    final name = player?.displayName ?? row.displayName;
    final deleted = player?.deletedAt != null;
    final delta = row.deltaFromStart;
    final deltaLabel = delta >= 0 ? '+$delta' : '$delta';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('$rank. $name${deleted ? ' (deleted)' : ''}'),
        subtitle: Text(
          'Elo ${row.seasonElo} ($deltaLabel) | '
          '${row.matchesPlayed} MP | '
          '${row.wins}-${row.draws}-${row.losses} | '
          'GF ${row.goalsFor} GA ${row.goalsAgainst}',
        ),
      ),
    );
  }
}

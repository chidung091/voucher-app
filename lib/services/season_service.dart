import 'dart:convert';

import '../data/local_store.dart';
import '../domain/elo_calculator.dart';
import '../domain/elo_config.dart';
import '../domain/enums.dart';
import '../domain/match.dart';
import '../domain/player.dart';
import '../domain/player_rating.dart';
import '../domain/rating_event.dart';
import '../domain/season.dart';

class SeasonService {
  SeasonService(this._store, this._elo);

  final LocalStore _store;
  final EloCalculator _elo;

  static Future<SeasonService> create() async {
    return SeasonService(await LocalStore.getInstance(), EloCalculator());
  }

  Future<SeasonConfig> getSeasonConfig() async {
    return await _store.getSeasonConfig() ?? SeasonConfig.defaults();
  }

  Future<void> updateSeasonConfig(SeasonConfig config) async {
    final updated = config.copyWith(updatedAt: DateTime.now());
    await _store.saveSeasonConfig(updated);
    await _store.clearSeasonCache();
  }

  Season getCurrentSeason(DateTime now, SeasonType type) {
    return getSeasonForDate(now, type);
  }

  Season getSeasonForDate(DateTime date, SeasonType type) {
    final start = _seasonStart(date, type);
    final end = _seasonEnd(start, type);
    final id = _seasonId(start, type);
    return Season(
      id: id,
      seasonType: type,
      startAt: start,
      endAt: end,
    );
  }

  Season getSeasonById(String seasonId, SeasonType type) {
    final start = _seasonStartFromId(seasonId, type);
    final end = _seasonEnd(start, type);
    return Season(
      id: seasonId,
      seasonType: type,
      startAt: start,
      endAt: end,
    );
  }

  List<Season> listRecentSeasons(
    SeasonType type, {
    required int count,
    DateTime? now,
  }) {
    final anchor = getSeasonForDate(now ?? DateTime.now(), type).startAt;
    final seasons = <Season>[];
    for (var i = 0; i < count; i++) {
      final date = _shiftSeasonStart(anchor, type, -i);
      seasons.add(getSeasonForDate(date, type));
    }
    return seasons;
  }

  Future<SeasonLeaderboard> getSeasonLeaderboard(
    String seasonId,
    SeasonType type,
  ) async {
    final config = await getSeasonConfig();
    final season = getSeasonById(seasonId, type);
    final cacheKey = _cacheKey(type, seasonId);

    final players = await _store.getPlayers();
    final ratings = await _store.getRatings();
    final matches = await _store.getMatches();
    final events = await _store.getRatingEvents();

    final seasonMatches = matches
        .where((match) => _inSeason(match, season))
        .toList()
      ..sort(_matchSort);

    final fingerprint = _buildFingerprint(
      seasonMatches: seasonMatches,
      events: events,
      config: config,
    );

    final cached = await _store.getSeasonCache(cacheKey);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        if (decoded['fingerprint'] == fingerprint) {
          return SeasonLeaderboard.fromJson(
            decoded['leaderboard'] as Map<String, dynamic>,
          );
        }
      } catch (_) {
        await _store.removeSeasonCache(cacheKey);
      }
    }

    final playerMap = {for (final player in players) player.id: player};
    final idSet = <String>{...playerMap.keys};
    for (final match in seasonMatches) {
      idSet.addAll(match.sideAPlayerIds);
      idSet.addAll(match.sideBPlayerIds);
    }

    final boundaryResult = _buildBoundaryElo(
      playerIds: idSet,
      players: playerMap,
      ratings: ratings,
      events: events,
      seasonStart: season.startAt,
    );

    final states = <String, _SeasonPlayerState>{};
    for (final id in idSet) {
      final boundary = boundaryResult.boundaryElo[id] ?? EloConfig.defaultElo;
      final startElo = _applyReset(boundary, config);
      states[id] = _SeasonPlayerState(
        startElo: startElo,
        elo: startElo,
        gamesPlayed: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        goalsFor: 0,
        goalsAgainst: 0,
      );
    }

    for (final match in seasonMatches) {
      if (match.mode == MatchMode.oneVOne) {
        _applySeason1v1(match, states);
      } else {
        _applySeason2v2(match, states);
      }
    }

    final rows = states.entries.map((entry) {
      final id = entry.key;
      final state = entry.value;
      final player = playerMap[id];
      return SeasonRow(
        playerId: id,
        displayName: player?.displayName ?? 'Unknown',
        seasonElo: state.elo,
        deltaFromStart: state.elo - state.startElo,
        matchesPlayed: state.gamesPlayed,
        wins: state.wins,
        draws: state.draws,
        losses: state.losses,
        goalsFor: state.goalsFor,
        goalsAgainst: state.goalsAgainst,
      );
    }).toList()
      ..sort((a, b) => b.seasonElo.compareTo(a.seasonElo));

    final leaderboard = SeasonLeaderboard(
      seasonId: seasonId,
      seasonType: type,
      startAt: season.startAt,
      endAt: season.endAt,
      rows: rows,
      computedAt: DateTime.now(),
      boundaryEstimated: boundaryResult.boundaryEstimated,
    );

    await _store.saveSeasonCache(
      cacheKey,
      jsonEncode({
        'fingerprint': fingerprint,
        'leaderboard': leaderboard.toJson(),
      }),
    );

    return leaderboard;
  }

  Future<void> invalidateSeasonCacheForMatch(Match match) async {
    final seasonTypes = SeasonType.values;
    for (final type in seasonTypes) {
      final season = getSeasonForDate(match.playedAt, type);
      await _store.removeSeasonCache(_cacheKey(type, season.id));
    }
  }

  Future<void> invalidateAllSeasonCache() async {
    await _store.clearSeasonCache();
  }

  String _cacheKey(SeasonType type, String seasonId) {
    return '${type.toJson()}:$seasonId';
  }

  bool _inSeason(Match match, Season season) {
    final time = match.playedAt;
    return !time.isBefore(season.startAt) && time.isBefore(season.endAt);
  }

  String _buildFingerprint({
    required List<Match> seasonMatches,
    required List<RatingEvent> events,
    required SeasonConfig config,
  }) {
    Match? lastMatch;
    if (seasonMatches.isNotEmpty) {
      lastMatch = seasonMatches.last;
    }
    RatingEvent? lastEvent;
    if (events.isNotEmpty) {
      final sortedEvents = events.toList()..sort(_eventSort);
      lastEvent = sortedEvents.last;
    }
    return [
      'v2',
      seasonMatches.length.toString(),
      lastMatch?.playedAt.millisecondsSinceEpoch.toString() ?? '0',
      lastMatch?.id ?? 'none',
      events.length.toString(),
      lastEvent?.createdAt.millisecondsSinceEpoch.toString() ?? '0',
      config.updatedAt.millisecondsSinceEpoch.toString(),
    ].join('|');
  }

  _BoundaryResult _buildBoundaryElo({
    required Set<String> playerIds,
    required Map<String, Player> players,
    required Map<String, PlayerRating> ratings,
    required List<RatingEvent> events,
    required DateTime seasonStart,
  }) {
    final boundaryElo = <String, int>{};
    var estimated = false;
    if (events.isEmpty) {
      estimated = true;
      for (final id in playerIds) {
        boundaryElo[id] = ratings[id]?.elo ?? EloConfig.defaultElo;
      }
      return _BoundaryResult(
        boundaryElo: boundaryElo,
        boundaryEstimated: estimated,
      );
    }

    final lastBefore = <String, RatingEvent>{};
    final sortedEvents = events.toList()..sort(_eventSort);
    for (final event in sortedEvents) {
      if (!event.createdAt.isBefore(seasonStart)) {
        continue;
      }
      final existing = lastBefore[event.playerId];
      if (existing == null || event.createdAt.isAfter(existing.createdAt)) {
        lastBefore[event.playerId] = event;
      }
    }

    for (final id in playerIds) {
      final existing = lastBefore[id];
      boundaryElo[id] = existing?.newElo ?? EloConfig.defaultElo;
    }

    return _BoundaryResult(
      boundaryElo: boundaryElo,
      boundaryEstimated: estimated,
    );
  }

  int _applyReset(int boundaryElo, SeasonConfig config) {
    switch (config.resetPolicy) {
      case SeasonResetPolicy.hardReset:
        return config.baselineElo;
      case SeasonResetPolicy.softReset:
        final alpha = config.softResetAlpha.clamp(0.0, 1.0);
        final delta = (boundaryElo - config.baselineElo) * alpha;
        return config.baselineElo + _roundHalfAwayFromZero(delta);
      case SeasonResetPolicy.none:
      default:
        return boundaryElo;
    }
  }

  void _applySeason1v1(
    Match match,
    Map<String, _SeasonPlayerState> states,
  ) {
    final playerA = match.sideAPlayerIds.first;
    final playerB = match.sideBPlayerIds.first;
    final ratingA = states[playerA]!;
    final ratingB = states[playerB]!;

    final actualA = match.result == MatchResult.draw
        ? 0.5
        : match.result == MatchResult.a
            ? 1.0
            : 0.0;
    final actualB = 1 - actualA;

    final deltaA = _applyMultiplier(
      _elo.delta(
        rating: ratingA.elo,
        opponentRating: ratingB.elo,
        actualScore: actualA,
        gamesPlayed: ratingA.gamesPlayed,
      ),
      match.eloMultiplier,
    );
    final deltaB = _applyMultiplier(
      _elo.delta(
        rating: ratingB.elo,
        opponentRating: ratingA.elo,
        actualScore: actualB,
        gamesPlayed: ratingB.gamesPlayed,
      ),
      match.eloMultiplier,
    );

    ratingA.elo += deltaA;
    ratingB.elo += deltaB;
    ratingA.gamesPlayed += 1;
    ratingB.gamesPlayed += 1;

    _applyStats(
      ratingA,
      match.result == MatchResult.a,
      match.result == MatchResult.draw,
      match.scoreA,
      match.scoreB,
    );
    _applyStats(
      ratingB,
      match.result == MatchResult.b,
      match.result == MatchResult.draw,
      match.scoreB,
      match.scoreA,
    );
  }

  void _applySeason2v2(
    Match match,
    Map<String, _SeasonPlayerState> states,
  ) {
    final sideA = match.sideAPlayerIds;
    final sideB = match.sideBPlayerIds;
    final ratingsA = sideA.map((id) => states[id]!).toList();
    final ratingsB = sideB.map((id) => states[id]!).toList();

    final teamRatingA =
        ratingsA.map((rating) => rating.elo).reduce((a, b) => a + b) /
            ratingsA.length;
    final teamRatingB =
        ratingsB.map((rating) => rating.elo).reduce((a, b) => a + b) /
            ratingsB.length;
    final expectedA = _elo.expectedScoreTeam(
      teamRatingA.round(),
      teamRatingB.round(),
    );
    final actualA = match.result == MatchResult.draw
        ? 0.5
        : match.result == MatchResult.a
            ? 1.0
            : 0.0;
    final scoreDelta = actualA - expectedA;

    for (final rating in ratingsA) {
      final rawDelta = _elo.kFactor(rating.gamesPlayed) * scoreDelta;
      final appliedDelta = _applyMultiplier(rawDelta, match.eloMultiplier);
      rating.elo += appliedDelta;
      rating.gamesPlayed += 1;
      _applyStats(
        rating,
        match.result == MatchResult.a,
        match.result == MatchResult.draw,
        match.scoreA,
        match.scoreB,
      );
    }

    for (final rating in ratingsB) {
      final rawDelta = _elo.kFactor(rating.gamesPlayed) * (-scoreDelta);
      final appliedDelta = _applyMultiplier(rawDelta, match.eloMultiplier);
      rating.elo += appliedDelta;
      rating.gamesPlayed += 1;
      _applyStats(
        rating,
        match.result == MatchResult.b,
        match.result == MatchResult.draw,
        match.scoreB,
        match.scoreA,
      );
    }
  }

  void _applyStats(
    _SeasonPlayerState state,
    bool isWin,
    bool isDraw,
    int goalsFor,
    int goalsAgainst,
  ) {
    if (isDraw) {
      state.draws += 1;
    } else if (isWin) {
      state.wins += 1;
    } else {
      state.losses += 1;
    }
    state.goalsFor += goalsFor;
    state.goalsAgainst += goalsAgainst;
  }

  int _applyMultiplier(double delta, double multiplier) {
    return _roundHalfAwayFromZero(delta * multiplier);
  }

  int _roundHalfAwayFromZero(double value) {
    if (value >= 0) {
      return (value + 0.5).floor();
    }
    return (value - 0.5).ceil();
  }

  int _matchSort(Match a, Match b) {
    final played = a.playedAt.compareTo(b.playedAt);
    if (played != 0) return played;
    return a.createdAt.compareTo(b.createdAt);
  }

  int _eventSort(RatingEvent a, RatingEvent b) {
    final time = a.createdAt.compareTo(b.createdAt);
    if (time != 0) return time;
    return a.matchId.compareTo(b.matchId);
  }

  DateTime _seasonStart(DateTime date, SeasonType type) {
    switch (type) {
      case SeasonType.quarter:
        final quarter = ((date.month - 1) ~/ 3) + 1;
        final startMonth = (quarter - 1) * 3 + 1;
        return DateTime(date.year, startMonth, 1);
      case SeasonType.year:
        return DateTime(date.year, 1, 1);
      case SeasonType.month:
      default:
        return DateTime(date.year, date.month, 1);
    }
  }

  DateTime _seasonEnd(DateTime start, SeasonType type) {
    switch (type) {
      case SeasonType.quarter:
        return DateTime(start.year, start.month + 3, 1);
      case SeasonType.year:
        return DateTime(start.year + 1, 1, 1);
      case SeasonType.month:
      default:
        return DateTime(start.year, start.month + 1, 1);
    }
  }

  String _seasonId(DateTime start, SeasonType type) {
    switch (type) {
      case SeasonType.quarter:
        final quarter = ((start.month - 1) ~/ 3) + 1;
        return '${start.year}-Q$quarter';
      case SeasonType.year:
        return '${start.year}';
      case SeasonType.month:
      default:
        final month = start.month.toString().padLeft(2, '0');
        return '${start.year}-$month';
    }
  }

  DateTime _seasonStartFromId(String id, SeasonType type) {
    switch (type) {
      case SeasonType.quarter:
        final match = RegExp(r'^(\d{4})-Q([1-4])$').firstMatch(id);
        if (match == null) {
          throw ArgumentError('Invalid quarter season id: $id');
        }
        final year = int.parse(match.group(1)!);
        final quarter = int.parse(match.group(2)!);
        final startMonth = (quarter - 1) * 3 + 1;
        return DateTime(year, startMonth, 1);
      case SeasonType.year:
        final match = RegExp(r'^(\d{4})$').firstMatch(id);
        if (match == null) {
          throw ArgumentError('Invalid year season id: $id');
        }
        return DateTime(int.parse(match.group(1)!), 1, 1);
      case SeasonType.month:
      default:
        final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(id);
        if (match == null) {
          throw ArgumentError('Invalid month season id: $id');
        }
        final year = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        return DateTime(year, month, 1);
    }
  }

  DateTime _shiftSeasonStart(
    DateTime anchor,
    SeasonType type,
    int offset,
  ) {
    switch (type) {
      case SeasonType.quarter:
        return DateTime(anchor.year, anchor.month + offset * 3, 1);
      case SeasonType.year:
        return DateTime(anchor.year + offset, 1, 1);
      case SeasonType.month:
      default:
        return DateTime(anchor.year, anchor.month + offset, 1);
    }
  }
}

class _SeasonPlayerState {
  _SeasonPlayerState({
    required this.startElo,
    required this.elo,
    required this.gamesPlayed,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
  });

  final int startElo;
  int elo;
  int gamesPlayed;
  int wins;
  int draws;
  int losses;
  int goalsFor;
  int goalsAgainst;
}

class _BoundaryResult {
  _BoundaryResult({
    required this.boundaryElo,
    required this.boundaryEstimated,
  });

  final Map<String, int> boundaryElo;
  final bool boundaryEstimated;
}

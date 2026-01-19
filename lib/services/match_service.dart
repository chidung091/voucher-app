import 'package:uuid/uuid.dart';

import '../data/local_store.dart';
import '../domain/elo_calculator.dart';
import '../domain/elo_config.dart';
import '../domain/player.dart';
import '../domain/enums.dart';
import '../domain/match.dart';
import '../domain/player_rating.dart';
import '../domain/rating_event.dart';
import 'head_to_head_service.dart';
import 'player_stats_service.dart';
import 'season_service.dart';

class MatchInput {
  MatchInput({
    required this.mode,
    required this.sideAPlayerIds,
    required this.sideBPlayerIds,
    required this.scoreA,
    required this.scoreB,
    required this.playedAt,
    this.ratingMode = MatchRatingMode.ranked,
    double? eloMultiplier,
    this.idempotencyKey,
    this.tournamentId,
    this.tournamentMatchId,
    this.metadata,
  }) : eloMultiplier = eloMultiplier ?? ratingMode.defaultMultiplier();

  final MatchMode mode;
  final List<String> sideAPlayerIds;
  final List<String> sideBPlayerIds;
  final int scoreA;
  final int scoreB;
  final DateTime playedAt;
  final MatchRatingMode ratingMode;
  final double eloMultiplier;
  final String? idempotencyKey;
  final String? tournamentId;
  final String? tournamentMatchId;
  final Map<String, dynamic>? metadata;
}

class MatchResultBundle {
  MatchResultBundle({required this.match, required this.events});

  final Match match;
  final List<RatingEvent> events;
}

class RatingsRebuildResult {
  RatingsRebuildResult({required this.ratings, required this.events});

  final Map<String, PlayerRating> ratings;
  final List<RatingEvent> events;
}

class MatchService {
  MatchService(this._store, this._uuid, this._elo);

  final LocalStore _store;
  final Uuid _uuid;
  final EloCalculator _elo;

  static Future<MatchService> create() async {
    return MatchService(
      await LocalStore.getInstance(),
      const Uuid(),
      EloCalculator(),
    );
  }

  Future<MatchResultBundle> createMatch(MatchInput input) {
    _validateInput(input);
    return _store.writeTransaction(() async {
      final matches = await _store.getMatches();
      final ratings = await _store.getRatings();
      final events = await _store.getRatingEvents();
      final players = await _store.getPlayers();

      final result = createMatchFromData(
        input: input,
        matches: matches,
        ratings: ratings,
        events: events,
        players: players,
      );

      await _store.saveMatches(matches);
      await _store.saveRatings(ratings);
      await _store.saveRatingEvents(events);
      await _invalidateStatsCache(result.match);
      await _invalidateH2HCache(result.match);
      await _invalidateSeasonCache(result.match);

      return result;
    });
  }

  MatchResultBundle createMatchFromData({
    required MatchInput input,
    required List<Match> matches,
    required Map<String, PlayerRating> ratings,
    required List<RatingEvent> events,
    List<Player>? players,
  }) {
    _validateInput(input);
    if (input.idempotencyKey != null) {
      final existing = matches
          .where((match) => match.idempotencyKey == input.idempotencyKey)
          .toList();
      if (existing.isNotEmpty) {
        final match = existing.first;
        final existingEvents =
            events.where((event) => event.matchId == match.id).toList();
        return MatchResultBundle(match: match, events: existingEvents);
      }
    }

    final result = _resolveResult(input.scoreA, input.scoreB);
    final match = Match(
      id: _uuid.v4(),
      mode: input.mode,
      sideAPlayerIds: input.sideAPlayerIds,
      sideBPlayerIds: input.sideBPlayerIds,
      scoreA: input.scoreA,
      scoreB: input.scoreB,
      result: result,
      playedAt: input.playedAt,
      createdAt: DateTime.now(),
      ratingMode: input.ratingMode,
      eloMultiplier: input.eloMultiplier,
      idempotencyKey: input.idempotencyKey,
      tournamentId: input.tournamentId,
      tournamentMatchId: input.tournamentMatchId,
      metadata: input.metadata,
    );

    final ratingEvents = <RatingEvent>[];
    final playerMap = {
      for (final player in players ?? <Player>[]) player.id: player,
    };
    if (input.mode == MatchMode.oneVOne) {
      _apply1v1(
        ratings: ratings,
        ratingEvents: ratingEvents,
        match: match,
        playerMap: playerMap,
        eventTime: match.playedAt,
        eloMultiplier: match.eloMultiplier,
      );
    } else {
      _apply2v2(
        ratings: ratings,
        ratingEvents: ratingEvents,
        match: match,
        playerMap: playerMap,
        eventTime: match.playedAt,
        eloMultiplier: match.eloMultiplier,
      );
    }

    matches.add(match);
    events.addAll(ratingEvents);
    return MatchResultBundle(match: match, events: ratingEvents);
  }

  Future<List<Match>> listMatches({
    String? playerId,
    String? tournamentId,
  }) async {
    final matches = await _store.getMatches();
    return matches.where((match) {
      final byPlayer = playerId == null ||
          match.sideAPlayerIds.contains(playerId) ||
          match.sideBPlayerIds.contains(playerId);
      final byTournament =
          tournamentId == null || match.tournamentId == tournamentId;
      return byPlayer && byTournament;
    }).toList();
  }

  Future<List<PlayerRating>> getLeaderboard({int? limit}) async {
    final ratings = await _store.getRatings();
    final list = ratings.values.toList();
    list.sort((a, b) => b.elo.compareTo(a.elo));
    if (limit != null && list.length > limit) {
      return list.sublist(0, limit);
    }
    return list;
  }

  void _validateInput(MatchInput input) {
    if (input.mode == MatchMode.oneVOne) {
      if (input.sideAPlayerIds.length != 1 ||
          input.sideBPlayerIds.length != 1) {
        throw ArgumentError('1V1 must have exactly 1 player per side.');
      }
    } else {
      final allowMixed = input.tournamentId != null;
      final sideAOk = allowMixed
          ? input.sideAPlayerIds.length >= 1 &&
              input.sideAPlayerIds.length <= 2
          : input.sideAPlayerIds.length == 2;
      final sideBOk = allowMixed
          ? input.sideBPlayerIds.length >= 1 &&
              input.sideBPlayerIds.length <= 2
          : input.sideBPlayerIds.length == 2;
      if (!sideAOk || !sideBOk) {
        if (allowMixed) {
          throw ArgumentError(
            '2V2 tournament matches must have 1 or 2 players per side.',
          );
        }
        throw ArgumentError('2V2 must have exactly 2 players per side.');
      }
    }
  }

  MatchResult _resolveResult(int scoreA, int scoreB) {
    if (scoreA == scoreB) return MatchResult.draw;
    return scoreA > scoreB ? MatchResult.a : MatchResult.b;
  }

  PlayerRating _ensureRating(
    Map<String, PlayerRating> ratings,
    String playerId,
    Map<String, Player> playerMap,
  ) {
    final skill = playerMap[playerId]?.skillLevel ?? 2;
    return ratings[playerId] ??
        PlayerRating(
          playerId: playerId,
          elo: EloConfig.initialEloForSkill(skill),
          gamesPlayed: 0,
          wins: 0,
          draws: 0,
          losses: 0,
          updatedAt: DateTime.now(),
        );
  }

  void _apply1v1({
    required Map<String, PlayerRating> ratings,
    required List<RatingEvent> ratingEvents,
    required Match match,
    required Map<String, Player> playerMap,
    required DateTime eventTime,
    required double eloMultiplier,
  }) {
    final playerA = match.sideAPlayerIds.first;
    final playerB = match.sideBPlayerIds.first;
    final ratingA = _ensureRating(ratings, playerA, playerMap);
    final ratingB = _ensureRating(ratings, playerB, playerMap);

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
      eloMultiplier,
    );
    final deltaB = _applyMultiplier(
      _elo.delta(
        rating: ratingB.elo,
        opponentRating: ratingA.elo,
        actualScore: actualB,
        gamesPlayed: ratingB.gamesPlayed,
      ),
      eloMultiplier,
    );
    final newA = ratingA.elo + deltaA;
    final newB = ratingB.elo + deltaB;

    final updatedA = ratingA.copyWith(
      elo: newA,
      gamesPlayed: ratingA.gamesPlayed + 1,
      wins: ratingA.wins + (match.result == MatchResult.a ? 1 : 0),
      draws: ratingA.draws + (match.result == MatchResult.draw ? 1 : 0),
      losses: ratingA.losses + (match.result == MatchResult.b ? 1 : 0),
      updatedAt: DateTime.now(),
    );
    final updatedB = ratingB.copyWith(
      elo: newB,
      gamesPlayed: ratingB.gamesPlayed + 1,
      wins: ratingB.wins + (match.result == MatchResult.b ? 1 : 0),
      draws: ratingB.draws + (match.result == MatchResult.draw ? 1 : 0),
      losses: ratingB.losses + (match.result == MatchResult.a ? 1 : 0),
      updatedAt: DateTime.now(),
    );

    ratings[playerA] = updatedA;
    ratings[playerB] = updatedB;

    ratingEvents.addAll([
      RatingEvent(
        id: _uuid.v4(),
        matchId: match.id,
        playerId: playerA,
        oldElo: ratingA.elo,
        newElo: updatedA.elo,
        delta: deltaA,
        createdAt: eventTime,
      ),
      RatingEvent(
        id: _uuid.v4(),
        matchId: match.id,
        playerId: playerB,
        oldElo: ratingB.elo,
        newElo: updatedB.elo,
        delta: deltaB,
        createdAt: eventTime,
      ),
    ]);
  }

  void _apply2v2({
    required Map<String, PlayerRating> ratings,
    required List<RatingEvent> ratingEvents,
    required Match match,
    required Map<String, Player> playerMap,
    required DateTime eventTime,
    required double eloMultiplier,
  }) {
    final sideA = match.sideAPlayerIds;
    final sideB = match.sideBPlayerIds;
    final ratingsA =
        sideA.map((id) => _ensureRating(ratings, id, playerMap)).toList();
    final ratingsB =
        sideB.map((id) => _ensureRating(ratings, id, playerMap)).toList();

    final teamRatingA =
        ratingsA.map((rating) => rating.elo).reduce((a, b) => a + b) /
            ratingsA.length;
    final teamRatingB =
        ratingsB.map((rating) => rating.elo).reduce((a, b) => a + b) /
            ratingsB.length;
    final expectedA =
        _elo.expectedScoreTeam(teamRatingA.round(), teamRatingB.round());
    final actualA = match.result == MatchResult.draw
        ? 0.5
        : match.result == MatchResult.a
            ? 1.0
            : 0.0;
    final scoreDelta = actualA - expectedA;

    for (final rating in ratingsA) {
      final rawDelta = _elo.kFactor(rating.gamesPlayed) * scoreDelta;
      final appliedDelta = _applyMultiplier(rawDelta, eloMultiplier);
      final newRating = rating.elo + appliedDelta;
      final updated = rating.copyWith(
        elo: newRating,
        gamesPlayed: rating.gamesPlayed + 1,
        wins: rating.wins + (match.result == MatchResult.a ? 1 : 0),
        draws: rating.draws + (match.result == MatchResult.draw ? 1 : 0),
        losses: rating.losses + (match.result == MatchResult.b ? 1 : 0),
        updatedAt: DateTime.now(),
      );
      ratings[rating.playerId] = updated;
      ratingEvents.add(
        RatingEvent(
          id: _uuid.v4(),
          matchId: match.id,
          playerId: rating.playerId,
          oldElo: rating.elo,
          newElo: updated.elo,
          delta: appliedDelta,
          createdAt: eventTime,
        ),
      );
    }

    for (final rating in ratingsB) {
      final rawDelta = _elo.kFactor(rating.gamesPlayed) * (-scoreDelta);
      final appliedDelta = _applyMultiplier(rawDelta, eloMultiplier);
      final newRating = rating.elo + appliedDelta;
      final updated = rating.copyWith(
        elo: newRating,
        gamesPlayed: rating.gamesPlayed + 1,
        wins: rating.wins + (match.result == MatchResult.b ? 1 : 0),
        draws: rating.draws + (match.result == MatchResult.draw ? 1 : 0),
        losses: rating.losses + (match.result == MatchResult.a ? 1 : 0),
        updatedAt: DateTime.now(),
      );
      ratings[rating.playerId] = updated;
      ratingEvents.add(
        RatingEvent(
          id: _uuid.v4(),
          matchId: match.id,
          playerId: rating.playerId,
          oldElo: rating.elo,
          newElo: updated.elo,
          delta: appliedDelta,
          createdAt: eventTime,
        ),
      );
    }
  }

  RatingsRebuildResult rebuildRatingsAndEvents(
    List<Match> matches,
    List<Player> players,
  ) {
    final sorted = [...matches]
      ..sort((a, b) {
        final played = a.playedAt.compareTo(b.playedAt);
        if (played != 0) return played;
        return a.createdAt.compareTo(b.createdAt);
      });
    final ratings = <String, PlayerRating>{};
    final events = <RatingEvent>[];
    final playerMap = {for (final player in players) player.id: player};
    for (final match in sorted) {
      if (match.mode == MatchMode.oneVOne) {
        _apply1v1(
          ratings: ratings,
          ratingEvents: events,
          match: match,
          playerMap: playerMap,
          eventTime: match.playedAt,
          eloMultiplier: match.eloMultiplier,
        );
      } else {
        _apply2v2(
          ratings: ratings,
          ratingEvents: events,
          match: match,
          playerMap: playerMap,
          eventTime: match.playedAt,
          eloMultiplier: match.eloMultiplier,
        );
      }
    }
    return RatingsRebuildResult(ratings: ratings, events: events);
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

  Future<void> _invalidateStatsCache(Match match) async {
    final statsService = PlayerStatsService(_store, _elo);
    await statsService.invalidatePlayerStatsCacheForMatch(match);
  }

  Future<void> _invalidateH2HCache(Match match) async {
    final h2hService = HeadToHeadService(_store);
    await h2hService.invalidateH2HCacheForMatch(match);
  }

  Future<void> _invalidateSeasonCache(Match match) async {
    final seasonService = SeasonService(_store, _elo);
    await seasonService.invalidateSeasonCacheForMatch(match);
  }
}

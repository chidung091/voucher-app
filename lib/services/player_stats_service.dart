import 'dart:convert';

import '../data/local_store.dart';
import '../domain/elo_calculator.dart';
import '../domain/elo_config.dart';
import '../domain/enums.dart';
import '../domain/match.dart';
import '../domain/player.dart';
import '../domain/player_stats.dart';
import '../domain/rating_event.dart';

class PlayerStatsService {
  PlayerStatsService(this._store, this._elo);

  final LocalStore _store;
  final EloCalculator _elo;

  static Future<PlayerStatsService> create() async {
    return PlayerStatsService(await LocalStore.getInstance(), EloCalculator());
  }

  Future<PlayerStats> getPlayerStats(String playerId) async {
    final matches = await _store.getMatches();
    final players = await _store.getPlayers();
    final ratings = await _store.getRatings();
    final events = await _store.getRatingEvents();

    final player = _resolvePlayer(playerId, players, matches);
    final playerMatches = matches
        .where((match) =>
            match.sideAPlayerIds.contains(playerId) ||
            match.sideBPlayerIds.contains(playerId))
        .toList()
      ..sort(_matchSort);

    final playerEvents = events
        .where((event) => event.playerId == playerId)
        .toList()
      ..sort(_eventSort);

    final fingerprint = _buildFingerprint(
      player: player,
      playerMatches: playerMatches,
      playerEvents: playerEvents,
      allMatches: matches,
    );

    final cached = await _store.getPlayerStatsCache(playerId);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        if (decoded['fingerprint'] == fingerprint) {
          return PlayerStats.fromJson(decoded['stats'] as Map<String, dynamic>);
        }
      } catch (_) {
        await _store.removePlayerStatsCache(playerId);
      }
    }

    final totals = _computeTotals(playerId, playerMatches);
    final streaks = _computeStreaks(playerId, playerMatches);

    const initialElo = EloConfig.defaultElo;
    final eloHistory = playerEvents.isNotEmpty
        ? _buildHistoryFromEvents(
            player,
            initialElo,
            playerEvents,
          )
        : _buildHistoryFromMatches(
            player,
            initialElo,
            matches,
            players,
            playerId,
          );

    final currentElo = ratings[playerId]?.elo ?? initialElo;
    final peakElo = eloHistory.isEmpty
        ? currentElo
        : eloHistory.map((point) => point.elo).reduce(_max);
    final lowestElo = eloHistory.isEmpty
        ? currentElo
        : eloHistory.map((point) => point.elo).reduce(_min);

    final stats = PlayerStats(
      playerId: playerId,
      computedAt: DateTime.now(),
      totalMatches: totals.totalMatches,
      wins: totals.wins,
      draws: totals.draws,
      losses: totals.losses,
      winRatePercent: totals.winRatePercent,
      goalsFor: totals.goalsFor,
      goalsAgainst: totals.goalsAgainst,
      goalDifference: totals.goalDifference,
      currentWinStreak: streaks.currentWin,
      bestWinStreak: streaks.bestWin,
      currentLoseStreak: streaks.currentLose,
      worstLoseStreak: streaks.worstLose,
      currentElo: currentElo,
      peakElo: peakElo,
      lowestElo: lowestElo,
      eloHistory: eloHistory,
    );

    await _store.savePlayerStatsCache(
      playerId,
      jsonEncode({'fingerprint': fingerprint, 'stats': stats.toJson()}),
    );

    return stats;
  }

  Future<void> invalidatePlayerStatsCacheForMatch(Match match) async {
    final ids = {
      ...match.sideAPlayerIds,
      ...match.sideBPlayerIds,
    };
    for (final id in ids) {
      await _store.removePlayerStatsCache(id);
    }
  }

  Future<void> invalidateAllStatsCache() async {
    await _store.clearPlayerStatsCache();
  }

  Player _resolvePlayer(
    String playerId,
    List<Player> players,
    List<Match> matches,
  ) {
    final existing = players.where((player) => player.id == playerId).toList();
    if (existing.isNotEmpty) {
      return existing.first;
    }
    final fallbackTime = matches.isEmpty
        ? DateTime.now()
        : (matches.toList()..sort(_matchSort)).first.playedAt;
    return Player(
      id: playerId,
      displayName: 'Unknown',
      skillLevel: 2,
      createdAt: fallbackTime,
      updatedAt: fallbackTime,
    );
  }

  String _buildFingerprint({
    required Player player,
    required List<Match> playerMatches,
    required List<RatingEvent> playerEvents,
    required List<Match> allMatches,
  }) {
    final lastPlayerMatch = playerMatches.isEmpty ? null : playerMatches.last;
    final lastPlayerEvent = playerEvents.isEmpty ? null : playerEvents.last;
    final lastGlobalMatch = allMatches.isEmpty
        ? null
        : (allMatches.toList()..sort(_matchSort)).last;

    final buffer = StringBuffer('v1');
    buffer
      ..write('|pm:')
      ..write(playerMatches.length)
      ..write(':')
      ..write(lastPlayerMatch?.playedAt.millisecondsSinceEpoch ?? 0)
      ..write(':')
      ..write(lastPlayerMatch?.createdAt.millisecondsSinceEpoch ?? 0)
      ..write('|pe:')
      ..write(playerEvents.length)
      ..write(':')
      ..write(lastPlayerEvent?.createdAt.millisecondsSinceEpoch ?? 0)
      ..write('|pu:')
      ..write(player.updatedAt.millisecondsSinceEpoch)
      ..write('|gm:')
      ..write(allMatches.length)
      ..write(':')
      ..write(lastGlobalMatch?.playedAt.millisecondsSinceEpoch ?? 0)
      ..write(':')
      ..write(lastGlobalMatch?.createdAt.millisecondsSinceEpoch ?? 0);
    return buffer.toString();
  }

  _Totals _computeTotals(String playerId, List<Match> matches) {
    var wins = 0;
    var draws = 0;
    var losses = 0;
    var goalsFor = 0;
    var goalsAgainst = 0;

    for (final match in matches) {
      final onSideA = match.sideAPlayerIds.contains(playerId);
      final onSideB = match.sideBPlayerIds.contains(playerId);
      if (!onSideA && !onSideB) continue;

      if (match.result == MatchResult.draw) {
        draws++;
      } else {
        final playerWon = (match.result == MatchResult.a && onSideA) ||
            (match.result == MatchResult.b && onSideB);
        if (playerWon) {
          wins++;
        } else {
          losses++;
        }
      }

      if (onSideA) {
        goalsFor += match.scoreA;
        goalsAgainst += match.scoreB;
      } else if (onSideB) {
        goalsFor += match.scoreB;
        goalsAgainst += match.scoreA;
      }
    }

    final totalMatches = matches.length;
    final winRate =
        totalMatches == 0 ? 0.0 : _round1((wins / totalMatches) * 100);

    return _Totals(
      totalMatches: totalMatches,
      wins: wins,
      draws: draws,
      losses: losses,
      winRatePercent: winRate,
      goalsFor: goalsFor,
      goalsAgainst: goalsAgainst,
      goalDifference: goalsFor - goalsAgainst,
    );
  }

  _Streaks _computeStreaks(String playerId, List<Match> matches) {
    var currentWin = 0;
    var bestWin = 0;
    var currentLose = 0;
    var worstLose = 0;

    for (final match in matches) {
      final onSideA = match.sideAPlayerIds.contains(playerId);
      final onSideB = match.sideBPlayerIds.contains(playerId);
      if (!onSideA && !onSideB) continue;

      if (match.result == MatchResult.draw) {
        currentWin = 0;
        currentLose = 0;
        continue;
      }

      final playerWon = (match.result == MatchResult.a && onSideA) ||
          (match.result == MatchResult.b && onSideB);
      if (playerWon) {
        currentWin += 1;
        bestWin = currentWin > bestWin ? currentWin : bestWin;
        currentLose = 0;
      } else {
        currentLose += 1;
        worstLose = currentLose > worstLose ? currentLose : worstLose;
        currentWin = 0;
      }
    }

    return _Streaks(
      currentWin: currentWin,
      bestWin: bestWin,
      currentLose: currentLose,
      worstLose: worstLose,
    );
  }

  List<EloPoint> _buildHistoryFromEvents(
    Player player,
    int initialElo,
    List<RatingEvent> events,
  ) {
    final history = <EloPoint>[
      EloPoint(timestamp: player.createdAt, elo: initialElo),
    ];
    for (final event in events) {
      history.add(EloPoint(timestamp: event.createdAt, elo: event.newElo));
    }
    return history;
  }

  List<EloPoint> _buildHistoryFromMatches(
    Player player,
    int initialElo,
    List<Match> allMatches,
    List<Player> players,
    String playerId,
  ) {
    final history = <EloPoint>[
      EloPoint(timestamp: player.createdAt, elo: initialElo),
    ];

    if (allMatches.isEmpty) {
      return history;
    }

    final states = <String, _EloState>{};

    _EloState ensureState(String id) {
      return states.putIfAbsent(id, () {
        return _EloState(
          elo: EloConfig.defaultElo,
          gamesPlayed: 0,
        );
      });
    }

    final sorted = allMatches.toList()..sort(_matchSort);
    for (final match in sorted) {
      if (match.mode == MatchMode.oneVOne) {
        final playerA = match.sideAPlayerIds.first;
        final playerB = match.sideBPlayerIds.first;
        final ratingA = ensureState(playerA);
        final ratingB = ensureState(playerB);

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
        final newA = ratingA.elo + deltaA;
        final newB = ratingB.elo + deltaB;

        ratingA.elo = newA;
        ratingA.gamesPlayed += 1;
        ratingB.elo = newB;
        ratingB.gamesPlayed += 1;

        if (playerId == playerA) {
          history.add(EloPoint(timestamp: match.playedAt, elo: newA));
        } else if (playerId == playerB) {
          history.add(EloPoint(timestamp: match.playedAt, elo: newB));
        }
      } else {
        final sideA = match.sideAPlayerIds;
        final sideB = match.sideBPlayerIds;
        if (sideA.isEmpty || sideB.isEmpty) {
          continue;
        }

        final ratingsA = sideA.map(ensureState).toList();
        final ratingsB = sideB.map(ensureState).toList();

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

        for (var i = 0; i < sideA.length; i++) {
          final id = sideA[i];
          final rating = ratingsA[i];
          final rawDelta = _elo.kFactor(rating.gamesPlayed) * scoreDelta;
          final newRating =
              rating.elo + _applyMultiplier(rawDelta, match.eloMultiplier);
          rating.elo = newRating;
          rating.gamesPlayed += 1;
          if (id == playerId) {
            history.add(EloPoint(timestamp: match.playedAt, elo: newRating));
          }
        }

        for (var i = 0; i < sideB.length; i++) {
          final id = sideB[i];
          final rating = ratingsB[i];
          final rawDelta = _elo.kFactor(rating.gamesPlayed) * (-scoreDelta);
          final newRating =
              rating.elo + _applyMultiplier(rawDelta, match.eloMultiplier);
          rating.elo = newRating;
          rating.gamesPlayed += 1;
          if (id == playerId) {
            history.add(EloPoint(timestamp: match.playedAt, elo: newRating));
          }
        }
      }
    }

    return history;
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

  double _round1(double value) {
    return double.parse(value.toStringAsFixed(1));
  }

  int _max(int a, int b) => a > b ? a : b;

  int _min(int a, int b) => a < b ? a : b;

  int _applyMultiplier(double delta, double multiplier) {
    return _roundHalfAwayFromZero(delta * multiplier);
  }

  int _roundHalfAwayFromZero(double value) {
    if (value >= 0) {
      return (value + 0.5).floor();
    }
    return (value - 0.5).ceil();
  }
}

class _Totals {
  _Totals({
    required this.totalMatches,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.winRatePercent,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
  });

  final int totalMatches;
  final int wins;
  final int draws;
  final int losses;
  final double winRatePercent;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
}

class _Streaks {
  _Streaks({
    required this.currentWin,
    required this.bestWin,
    required this.currentLose,
    required this.worstLose,
  });

  final int currentWin;
  final int bestWin;
  final int currentLose;
  final int worstLose;
}

class _EloState {
  _EloState({required this.elo, required this.gamesPlayed});

  int elo;
  int gamesPlayed;
}

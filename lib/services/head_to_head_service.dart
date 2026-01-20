import 'dart:convert';

import '../data/local_store.dart';
import '../domain/enums.dart';
import '../domain/head_to_head.dart';
import '../domain/match.dart';

class HeadToHeadService {
  HeadToHeadService(this._store);

  final LocalStore _store;

  static Future<HeadToHeadService> create() async {
    return HeadToHeadService(await LocalStore.getInstance());
  }

  Future<HeadToHeadStats> getH2H1v1(
    String playerAId,
    String playerBId, {
    int recentLimit = 20,
  }) async {
    final key = HeadToHeadKey.for1v1(playerAId, playerBId);
    return _getStats(
      key: key,
      recentLimit: recentLimit,
    );
  }

  Future<HeadToHeadStats> getH2H2v2(
    String aId,
    String bId,
    String cId,
    String dId, {
    int recentLimit = 20,
  }) async {
    final key = HeadToHeadKey.for2v2(aId, bId, cId, dId);
    return _getStats(
      key: key,
      recentLimit: recentLimit,
    );
  }

  Future<HeadToHeadStats> _getStats({
    required HeadToHeadKey key,
    required int recentLimit,
  }) async {
    final matches = await _store.getMatches();
    final filtered = _filterMatches(key, matches);
    filtered.sort(_matchSortAsc);

    final fingerprint = _buildFingerprint(filtered);
    final cacheKey = key.toCacheKey();
    final cached = await _store.getH2HCache(cacheKey);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        if (decoded['fingerprint'] == fingerprint) {
          return HeadToHeadStats.fromJson(
            decoded['stats'] as Map<String, dynamic>,
          );
        }
      } catch (_) {
        await _store.removeH2HCache(cacheKey);
      }
    }

    final stats = _computeStats(key, filtered, recentLimit);
    await _store.saveH2HCache(
      cacheKey,
      jsonEncode({'fingerprint': fingerprint, 'stats': stats.toJson()}),
    );
    return stats;
  }

  Future<void> invalidateH2HCacheForMatch(Match match) async {
    if (match.mode == MatchMode.oneVOne) {
      if (match.sideAPlayerIds.isEmpty || match.sideBPlayerIds.isEmpty) {
        return;
      }
      final key = HeadToHeadKey.for1v1(
        match.sideAPlayerIds.first,
        match.sideBPlayerIds.first,
      );
      await _store.removeH2HCache(key.toCacheKey());
      return;
    }

    if (match.sideAPlayerIds.length < 2 || match.sideBPlayerIds.length < 2) {
      return;
    }
    final key = HeadToHeadKey.for2v2(
      match.sideAPlayerIds[0],
      match.sideAPlayerIds[1],
      match.sideBPlayerIds[0],
      match.sideBPlayerIds[1],
    );
    await _store.removeH2HCache(key.toCacheKey());
  }

  Future<void> invalidateAllH2HCache() async {
    await _store.clearH2HCache();
  }

  List<Match> _filterMatches(HeadToHeadKey key, List<Match> matches) {
    if (key.mode == MatchMode.oneVOne) {
      final side1 = key.ids[0];
      final side2 = key.ids[1];
      return matches.where((match) {
        if (match.mode != MatchMode.oneVOne) return false;
        final players = [...match.sideAPlayerIds, ...match.sideBPlayerIds];
        if (players.length != 2) return false;
        final sorted = players..sort();
        return sorted[0] == side1 && sorted[1] == side2;
      }).toList();
    }

    final side1 = [key.ids[0], key.ids[1]];
    final side2 = [key.ids[2], key.ids[3]];
    return matches.where((match) {
      if (match.mode != MatchMode.twoVTwo) return false;
      if (match.sideAPlayerIds.length != 2 ||
          match.sideBPlayerIds.length != 2) {
        return false;
      }
      final sideA = [...match.sideAPlayerIds]..sort();
      final sideB = [...match.sideBPlayerIds]..sort();
      return (_listEquals(sideA, side1) && _listEquals(sideB, side2)) ||
          (_listEquals(sideA, side2) && _listEquals(sideB, side1));
    }).toList();
  }

  HeadToHeadStats _computeStats(
    HeadToHeadKey key,
    List<Match> matches,
    int recentLimit,
  ) {
    var winsSide1 = 0;
    var winsSide2 = 0;
    var draws = 0;
    var goalsForSide1 = 0;
    var goalsAgainstSide1 = 0;

    for (final match in matches) {
      final scores = _scoresForSide1(key, match);
      if (scores == null) continue;
      final scoreSide1 = scores.$1;
      final scoreSide2 = scores.$2;
      goalsForSide1 += scoreSide1;
      goalsAgainstSide1 += scoreSide2;

      if (scoreSide1 == scoreSide2) {
        draws += 1;
      } else if (scoreSide1 > scoreSide2) {
        winsSide1 += 1;
      } else {
        winsSide2 += 1;
      }
    }

    final recentMatches = _buildRecentMatches(key, matches, recentLimit);

    return HeadToHeadStats(
      key: key,
      computedAt: DateTime.now(),
      totalMatches: matches.length,
      winsSide1: winsSide1,
      draws: draws,
      winsSide2: winsSide2,
      goalsForSide1: goalsForSide1,
      goalsAgainstSide1: goalsAgainstSide1,
      recentMatches: recentMatches,
    );
  }

  List<HeadToHeadMatchSummary> _buildRecentMatches(
    HeadToHeadKey key,
    List<Match> matches,
    int limit,
  ) {
    final sorted = [...matches]..sort(_matchSortDesc);
    final summaries = <HeadToHeadMatchSummary>[];
    for (final match in sorted.take(limit)) {
      final scores = _scoresForSide1(key, match);
      if (scores == null) continue;
      final scoreSide1 = scores.$1;
      final scoreSide2 = scores.$2;
      final result = scoreSide1 == scoreSide2
          ? 'D'
          : (scoreSide1 > scoreSide2 ? 'W' : 'L');
      summaries.add(
        HeadToHeadMatchSummary(
          matchId: match.id,
          playedAt: match.playedAt,
          scoreSide1: scoreSide1,
          scoreSide2: scoreSide2,
          resultForSide1: result,
          ratingMode: match.ratingMode,
          tournamentId: match.tournamentId,
        ),
      );
    }
    return summaries;
  }

  (int, int)? _scoresForSide1(HeadToHeadKey key, Match match) {
    if (key.mode == MatchMode.oneVOne) {
      final side1 = key.ids[0];
      if (match.sideAPlayerIds.contains(side1)) {
        return (match.scoreA, match.scoreB);
      }
      if (match.sideBPlayerIds.contains(side1)) {
        return (match.scoreB, match.scoreA);
      }
      return null;
    }

    final side1 = [key.ids[0], key.ids[1]];
    final sideA = [...match.sideAPlayerIds]..sort();
    if (_listEquals(sideA, side1)) {
      return (match.scoreA, match.scoreB);
    }
    return (match.scoreB, match.scoreA);
  }

  String _buildFingerprint(List<Match> matches) {
    if (matches.isEmpty) {
      return '0_0_';
    }
    final sorted = [...matches]..sort(_matchSortAsc);
    final last = sorted.last;
    return '${sorted.length}_${last.playedAt.millisecondsSinceEpoch}_${last.id}';
  }

  int _matchSortAsc(Match a, Match b) {
    final played = a.playedAt.compareTo(b.playedAt);
    if (played != 0) return played;
    return a.createdAt.compareTo(b.createdAt);
  }

  int _matchSortDesc(Match a, Match b) {
    final played = b.playedAt.compareTo(a.playedAt);
    if (played != 0) return played;
    return b.createdAt.compareTo(a.createdAt);
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

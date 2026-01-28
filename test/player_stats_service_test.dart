import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voucher_app/data/local_store.dart';
import 'package:voucher_app/domain/elo_config.dart';
import 'package:voucher_app/domain/enums.dart';
import 'package:voucher_app/domain/match.dart';
import 'package:voucher_app/domain/player.dart';
import 'package:voucher_app/domain/player_rating.dart';
import 'package:voucher_app/domain/rating_event.dart';
import 'package:voucher_app/services/player_stats_service.dart';

void main() {
  Future<LocalStore> _seedBasicPlayers() async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();
    final store = await LocalStore.getInstance();
    final now = DateTime(2024, 1, 1);
    await store.savePlayers([
      Player(
        id: 'p1',
        displayName: 'Alpha',
        skillLevel: 2,
        createdAt: now,
        updatedAt: now,
      ),
      Player(
        id: 'p2',
        displayName: 'Bravo',
        skillLevel: 2,
        createdAt: now,
        updatedAt: now,
      ),
      Player(
        id: 'p3',
        displayName: 'Charlie',
        skillLevel: 2,
        createdAt: now,
        updatedAt: now,
      ),
      Player(
        id: 'p4',
        displayName: 'Delta',
        skillLevel: 2,
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    await store.saveRatings({
      'p1': PlayerRating(
        playerId: 'p1',
        elo: 1000,
        gamesPlayed: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        updatedAt: now,
      ),
    });
    return store;
  }

  test('1v1 series computes totals, goals, and streaks', () async {
    final store = await _seedBasicPlayers();
    final base = DateTime(2024, 1, 1, 10, 0);
    await store.saveMatches([
      Match(
        id: 'm1',
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p2'],
        scoreA: 2,
        scoreB: 1,
        result: MatchResult.a,
        playedAt: base.add(const Duration(days: 1)),
        createdAt: base.add(const Duration(days: 1, seconds: 1)),
      ),
      Match(
        id: 'm2',
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p2'],
        scoreA: 1,
        scoreB: 1,
        result: MatchResult.draw,
        playedAt: base.add(const Duration(days: 2)),
        createdAt: base.add(const Duration(days: 2, seconds: 1)),
      ),
      Match(
        id: 'm3',
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p2'],
        scoreA: 0,
        scoreB: 3,
        result: MatchResult.b,
        playedAt: base.add(const Duration(days: 3)),
        createdAt: base.add(const Duration(days: 3, seconds: 1)),
      ),
    ]);

    final service = await PlayerStatsService.create();
    final stats = await service.getPlayerStats('p1');

    expect(stats.totalMatches, 3);
    expect(stats.wins, 1);
    expect(stats.draws, 1);
    expect(stats.losses, 1);
    expect(stats.goalsFor, 3);
    expect(stats.goalsAgainst, 5);
    expect(stats.goalDifference, -2);
    expect(stats.winRatePercent, 33.3);
    expect(stats.currentWinStreak, 0);
    expect(stats.bestWinStreak, 1);
    expect(stats.currentLoseStreak, 1);
    expect(stats.worstLoseStreak, 1);
  });

  test('2v2 results account for side A and side B correctly', () async {
    final store = await _seedBasicPlayers();
    final base = DateTime(2024, 2, 1, 10, 0);
    await store.saveMatches([
      Match(
        id: 'm1',
        mode: MatchMode.twoVTwo,
        sideAPlayerIds: const ['p1', 'p2'],
        sideBPlayerIds: const ['p3', 'p4'],
        scoreA: 3,
        scoreB: 1,
        result: MatchResult.a,
        playedAt: base.add(const Duration(days: 1)),
        createdAt: base.add(const Duration(days: 1, seconds: 1)),
      ),
      Match(
        id: 'm2',
        mode: MatchMode.twoVTwo,
        sideAPlayerIds: const ['p3', 'p4'],
        sideBPlayerIds: const ['p1', 'p2'],
        scoreA: 2,
        scoreB: 0,
        result: MatchResult.a,
        playedAt: base.add(const Duration(days: 2)),
        createdAt: base.add(const Duration(days: 2, seconds: 1)),
      ),
    ]);

    final service = await PlayerStatsService.create();
    final stats = await service.getPlayerStats('p1');

    expect(stats.totalMatches, 2);
    expect(stats.wins, 1);
    expect(stats.losses, 1);
    expect(stats.draws, 0);
    expect(stats.goalsFor, 3);
    expect(stats.goalsAgainst, 3);
  });

  test('draws reset streaks', () async {
    final store = await _seedBasicPlayers();
    final base = DateTime(2024, 3, 1, 10, 0);
    await store.saveMatches([
      Match(
        id: 'm1',
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p2'],
        scoreA: 2,
        scoreB: 0,
        result: MatchResult.a,
        playedAt: base.add(const Duration(days: 1)),
        createdAt: base.add(const Duration(days: 1, seconds: 1)),
      ),
      Match(
        id: 'm2',
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p2'],
        scoreA: 1,
        scoreB: 0,
        result: MatchResult.a,
        playedAt: base.add(const Duration(days: 2)),
        createdAt: base.add(const Duration(days: 2, seconds: 1)),
      ),
      Match(
        id: 'm3',
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p2'],
        scoreA: 1,
        scoreB: 1,
        result: MatchResult.draw,
        playedAt: base.add(const Duration(days: 3)),
        createdAt: base.add(const Duration(days: 3, seconds: 1)),
      ),
      Match(
        id: 'm4',
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p2'],
        scoreA: 0,
        scoreB: 1,
        result: MatchResult.b,
        playedAt: base.add(const Duration(days: 4)),
        createdAt: base.add(const Duration(days: 4, seconds: 1)),
      ),
      Match(
        id: 'm5',
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p2'],
        scoreA: 0,
        scoreB: 2,
        result: MatchResult.b,
        playedAt: base.add(const Duration(days: 5)),
        createdAt: base.add(const Duration(days: 5, seconds: 1)),
      ),
    ]);

    final service = await PlayerStatsService.create();
    final stats = await service.getPlayerStats('p1');

    expect(stats.bestWinStreak, 2);
    expect(stats.worstLoseStreak, 2);
    expect(stats.currentWinStreak, 0);
    expect(stats.currentLoseStreak, 2);
  });

  test('elo history uses rating events and computes extremes', () async {
    final store = await _seedBasicPlayers();
    final base = DateTime(2024, 4, 1, 10, 0);
    await store.saveMatches([
      Match(
        id: 'm1',
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p2'],
        scoreA: 2,
        scoreB: 1,
        result: MatchResult.a,
        playedAt: base.add(const Duration(days: 1)),
        createdAt: base.add(const Duration(days: 1, seconds: 1)),
      ),
      Match(
        id: 'm2',
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p2'],
        scoreA: 0,
        scoreB: 1,
        result: MatchResult.b,
        playedAt: base.add(const Duration(days: 2)),
        createdAt: base.add(const Duration(days: 2, seconds: 1)),
      ),
      Match(
        id: 'm3',
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p2'],
        scoreA: 3,
        scoreB: 0,
        result: MatchResult.a,
        playedAt: base.add(const Duration(days: 3)),
        createdAt: base.add(const Duration(days: 3, seconds: 1)),
      ),
    ]);
    await store.saveRatingEvents([
      RatingEvent(
        id: 'e1',
        matchId: 'm1',
        playerId: 'p1',
        oldElo: 1000,
        newElo: 1020,
        delta: 20,
        createdAt: base.add(const Duration(days: 1)),
      ),
      RatingEvent(
        id: 'e2',
        matchId: 'm2',
        playerId: 'p1',
        oldElo: 1020,
        newElo: 990,
        delta: -30,
        createdAt: base.add(const Duration(days: 2)),
      ),
      RatingEvent(
        id: 'e3',
        matchId: 'm3',
        playerId: 'p1',
        oldElo: 990,
        newElo: 1050,
        delta: 60,
        createdAt: base.add(const Duration(days: 3)),
      ),
    ]);

    final service = await PlayerStatsService.create();
    final stats = await service.getPlayerStats('p1');

    expect(stats.eloHistory.length, 4);
    expect(stats.eloHistory.first.elo, EloConfig.defaultElo);
    expect(stats.eloHistory[1].elo, 1020);
    expect(stats.eloHistory[2].elo, 990);
    expect(stats.eloHistory[3].elo, 1050);
    expect(stats.peakElo, 1050);
    expect(stats.lowestElo, 990);
  });

  test('stats cache returns cached values and invalidates on match changes',
      () async {
    final store = await _seedBasicPlayers();
    final base = DateTime(2024, 5, 1, 10, 0);
    final match1 = Match(
      id: 'm1',
      mode: MatchMode.oneVOne,
      sideAPlayerIds: const ['p1'],
      sideBPlayerIds: const ['p2'],
      scoreA: 1,
      scoreB: 0,
      result: MatchResult.a,
      playedAt: base.add(const Duration(days: 1)),
      createdAt: base.add(const Duration(days: 1, seconds: 1)),
    );
    await store.saveMatches([match1]);

    final service = await PlayerStatsService.create();
    final first = await service.getPlayerStats('p1');
    final second = await service.getPlayerStats('p1');

    expect(second.computedAt, first.computedAt);

    final match2 = Match(
      id: 'm2',
      mode: MatchMode.oneVOne,
      sideAPlayerIds: const ['p1'],
      sideBPlayerIds: const ['p2'],
      scoreA: 0,
      scoreB: 1,
      result: MatchResult.b,
      playedAt: base.add(const Duration(days: 2)),
      createdAt: base.add(const Duration(days: 2, seconds: 1)),
    );
    await store.saveMatches([match1, match2]);
    await service.invalidatePlayerStatsCacheForMatch(match2);

    await Future<void>.delayed(const Duration(milliseconds: 2));

    final third = await service.getPlayerStats('p1');
    expect(third.totalMatches, 2);
    expect(third.computedAt, isNot(first.computedAt));
  });
}

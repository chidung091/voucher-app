import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voucher_app/data/local_store.dart';
import 'package:voucher_app/domain/enums.dart';
import 'package:voucher_app/domain/match.dart';
import 'package:voucher_app/domain/player.dart';
import 'package:voucher_app/domain/player_rating.dart';
import 'package:voucher_app/domain/rating_event.dart';
import 'package:voucher_app/domain/season.dart';
import 'package:voucher_app/services/season_service.dart';

void main() {
  Future<LocalStore> seedPlayers() async {
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
      'p2': PlayerRating(
        playerId: 'p2',
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

  test('Season ids are generated correctly', () async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();
    final service = await SeasonService.create();
    final date = DateTime(2026, 1, 15);

    expect(service.getSeasonForDate(date, SeasonType.month).id, '2026-01');
    expect(service.getSeasonForDate(date, SeasonType.quarter).id, '2026-Q1');
    expect(service.getSeasonForDate(date, SeasonType.year).id, '2026');
  });

  test('Soft reset uses baseline and alpha', () async {
    final store = await seedPlayers();
    final service = await SeasonService.create();
    await service.updateSeasonConfig(
      SeasonConfig(
        seasonType: SeasonType.month,
        baselineElo: 1000,
        resetPolicy: SeasonResetPolicy.softReset,
        softResetAlpha: 0.5,
        updatedAt: DateTime.now(),
      ),
    );
    await store.saveRatingEvents([
      RatingEvent(
        id: 'e1',
        matchId: 'm1',
        playerId: 'p1',
        oldElo: 1000,
        newElo: 1200,
        delta: 200,
        createdAt: DateTime(2024, 1, 15),
      ),
    ]);

    final leaderboard = await service.getSeasonLeaderboard(
      '2024-02',
      SeasonType.month,
    );
    final row = leaderboard.rows.firstWhere((item) => item.playerId == 'p1');
    expect(row.seasonElo, 1100);
    expect(row.deltaFromStart, 0);
  });

  test('Leaderboard only counts matches inside the season', () async {
    final store = await seedPlayers();
    final service = await SeasonService.create();
    await service.updateSeasonConfig(
      SeasonConfig(
        seasonType: SeasonType.month,
        baselineElo: 1000,
        resetPolicy: SeasonResetPolicy.none,
        softResetAlpha: 0.5,
        updatedAt: DateTime.now(),
      ),
    );
    await store.saveMatches([
      Match(
        id: 'm1',
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p2'],
        scoreA: 1,
        scoreB: 0,
        result: MatchResult.a,
        playedAt: DateTime(2024, 1, 10),
        createdAt: DateTime(2024, 1, 10, 10, 0),
      ),
      Match(
        id: 'm2',
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p2'],
        scoreA: 2,
        scoreB: 1,
        result: MatchResult.a,
        playedAt: DateTime(2024, 2, 10),
        createdAt: DateTime(2024, 2, 10, 10, 0),
      ),
      Match(
        id: 'm3',
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p2'],
        sideBPlayerIds: const ['p1'],
        scoreA: 0,
        scoreB: 3,
        result: MatchResult.b,
        playedAt: DateTime(2024, 2, 12),
        createdAt: DateTime(2024, 2, 12, 10, 0),
      ),
    ]);

    final leaderboard = await service.getSeasonLeaderboard(
      '2024-02',
      SeasonType.month,
    );
    final row = leaderboard.rows.firstWhere((item) => item.playerId == 'p1');
    expect(row.matchesPlayed, 2);
  });

  test('Elo multiplier applies during seasonal replay', () async {
    final store = await seedPlayers();
    final service = await SeasonService.create();
    await service.updateSeasonConfig(
      SeasonConfig(
        seasonType: SeasonType.month,
        baselineElo: 1000,
        resetPolicy: SeasonResetPolicy.none,
        softResetAlpha: 0.5,
        updatedAt: DateTime.now(),
      ),
    );
    await store.saveMatches([
      Match(
        id: 'm1',
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p2'],
        scoreA: 1,
        scoreB: 0,
        result: MatchResult.a,
        playedAt: DateTime(2024, 2, 5),
        createdAt: DateTime(2024, 2, 5, 10, 0),
        ratingMode: MatchRatingMode.friendly,
      ),
    ]);

    final leaderboard = await service.getSeasonLeaderboard(
      '2024-02',
      SeasonType.month,
    );
    final row = leaderboard.rows.firstWhere((item) => item.playerId == 'p1');
    expect(row.seasonElo, 1010);
  });

  test('Season cache returns cached leaderboard and recomputes on change',
      () async {
    final store = await seedPlayers();
    final service = await SeasonService.create();
    await service.updateSeasonConfig(
      SeasonConfig(
        seasonType: SeasonType.month,
        baselineElo: 1000,
        resetPolicy: SeasonResetPolicy.none,
        softResetAlpha: 0.5,
        updatedAt: DateTime.now(),
      ),
    );
    final match1 = Match(
      id: 'm1',
      mode: MatchMode.oneVOne,
      sideAPlayerIds: const ['p1'],
      sideBPlayerIds: const ['p2'],
      scoreA: 1,
      scoreB: 0,
      result: MatchResult.a,
      playedAt: DateTime(2024, 2, 1),
      createdAt: DateTime(2024, 2, 1, 10, 0),
    );
    await store.saveMatches([match1]);

    final first = await service.getSeasonLeaderboard(
      '2024-02',
      SeasonType.month,
    );
    final second = await service.getSeasonLeaderboard(
      '2024-02',
      SeasonType.month,
    );
    expect(second.computedAt, first.computedAt);

    final match2 = Match(
      id: 'm2',
      mode: MatchMode.oneVOne,
      sideAPlayerIds: const ['p1'],
      sideBPlayerIds: const ['p2'],
      scoreA: 0,
      scoreB: 1,
      result: MatchResult.b,
      playedAt: DateTime(2024, 2, 3),
      createdAt: DateTime(2024, 2, 3, 10, 0),
    );
    await store.saveMatches([match1, match2]);
    await Future<void>.delayed(const Duration(milliseconds: 2));

    final third = await service.getSeasonLeaderboard(
      '2024-02',
      SeasonType.month,
    );
    expect(third.computedAt, isNot(first.computedAt));
  });

  test('Boundary Elo uses last rating event before season start', () async {
    final store = await seedPlayers();
    final service = await SeasonService.create();
    await service.updateSeasonConfig(
      SeasonConfig(
        seasonType: SeasonType.month,
        baselineElo: 1000,
        resetPolicy: SeasonResetPolicy.none,
        softResetAlpha: 0.5,
        updatedAt: DateTime.now(),
      ),
    );
    await store.saveRatingEvents([
      RatingEvent(
        id: 'e1',
        matchId: 'm1',
        playerId: 'p1',
        oldElo: 1000,
        newElo: 1100,
        delta: 100,
        createdAt: DateTime(2024, 1, 10),
      ),
      RatingEvent(
        id: 'e2',
        matchId: 'm2',
        playerId: 'p1',
        oldElo: 1100,
        newElo: 1150,
        delta: 50,
        createdAt: DateTime(2024, 1, 20),
      ),
      RatingEvent(
        id: 'e3',
        matchId: 'm3',
        playerId: 'p1',
        oldElo: 1150,
        newElo: 1300,
        delta: 150,
        createdAt: DateTime(2024, 2, 1),
      ),
    ]);

    final leaderboard = await service.getSeasonLeaderboard(
      '2024-02',
      SeasonType.month,
    );
    final row = leaderboard.rows.firstWhere((item) => item.playerId == 'p1');
    expect(row.seasonElo, 1150);
  });
}

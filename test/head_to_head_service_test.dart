import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voucher_app/data/local_store.dart';
import 'package:voucher_app/domain/enums.dart';
import 'package:voucher_app/domain/match.dart';
import 'package:voucher_app/services/head_to_head_service.dart';

void main() {
  Future<LocalStore> setupStore() async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();
    return LocalStore.getInstance();
  }

  test('1v1 counts exact players and swaps sides correctly', () async {
    final store = await setupStore();
    final base = DateTime(2024, 1, 1, 12);
    await store.saveMatches([
      Match(
        id: 'm1',
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p2'],
        scoreA: 2,
        scoreB: 1,
        result: MatchResult.a,
        playedAt: base,
        createdAt: base.add(const Duration(seconds: 1)),
      ),
      Match(
        id: 'm2',
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p2'],
        sideBPlayerIds: const ['p1'],
        scoreA: 0,
        scoreB: 0,
        result: MatchResult.draw,
        playedAt: base.add(const Duration(days: 1)),
        createdAt: base.add(const Duration(days: 1, seconds: 1)),
      ),
      Match(
        id: 'm3',
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p3'],
        scoreA: 3,
        scoreB: 1,
        result: MatchResult.a,
        playedAt: base.add(const Duration(days: 2)),
        createdAt: base.add(const Duration(days: 2, seconds: 1)),
      ),
    ]);

    final service = await HeadToHeadService.create();
    final stats = await service.getH2H1v1('p1', 'p2');

    expect(stats.totalMatches, 2);
    expect(stats.winsSide1, 1);
    expect(stats.draws, 1);
    expect(stats.winsSide2, 0);
    expect(stats.goalsForSide1, 2);
    expect(stats.goalsAgainstSide1, 1);
  });

  test('2v2 respects pair order and swaps sides', () async {
    final store = await setupStore();
    final base = DateTime(2024, 2, 1, 12);
    await store.saveMatches([
      Match(
        id: 'm1',
        mode: MatchMode.twoVTwo,
        sideAPlayerIds: const ['a', 'b'],
        sideBPlayerIds: const ['c', 'd'],
        scoreA: 3,
        scoreB: 1,
        result: MatchResult.a,
        playedAt: base,
        createdAt: base.add(const Duration(seconds: 1)),
      ),
      Match(
        id: 'm2',
        mode: MatchMode.twoVTwo,
        sideAPlayerIds: const ['d', 'c'],
        sideBPlayerIds: const ['b', 'a'],
        scoreA: 2,
        scoreB: 2,
        result: MatchResult.draw,
        playedAt: base.add(const Duration(days: 1)),
        createdAt: base.add(const Duration(days: 1, seconds: 1)),
      ),
      Match(
        id: 'm3',
        mode: MatchMode.twoVTwo,
        sideAPlayerIds: const ['a', 'c'],
        sideBPlayerIds: const ['b', 'd'],
        scoreA: 1,
        scoreB: 0,
        result: MatchResult.a,
        playedAt: base.add(const Duration(days: 2)),
        createdAt: base.add(const Duration(days: 2, seconds: 1)),
      ),
    ]);

    final service = await HeadToHeadService.create();
    final stats = await service.getH2H2v2('b', 'a', 'd', 'c');

    expect(stats.totalMatches, 2);
    expect(stats.winsSide1, 1);
    expect(stats.draws, 1);
    expect(stats.winsSide2, 0);
    expect(stats.goalsForSide1, 5);
    expect(stats.goalsAgainstSide1, 3);
  });

  test('cache hit and invalidation after match update', () async {
    final store = await setupStore();
    final base = DateTime(2024, 3, 1, 12);
    final match1 = Match(
      id: 'm1',
      mode: MatchMode.oneVOne,
      sideAPlayerIds: const ['p1'],
      sideBPlayerIds: const ['p2'],
      scoreA: 1,
      scoreB: 0,
      result: MatchResult.a,
      playedAt: base,
      createdAt: base.add(const Duration(seconds: 1)),
    );
    await store.saveMatches([match1]);

    final service = await HeadToHeadService.create();
    final first = await service.getH2H1v1('p1', 'p2');
    final second = await service.getH2H1v1('p1', 'p2');

    expect(second.computedAt, first.computedAt);

    final match2 = Match(
      id: 'm2',
      mode: MatchMode.oneVOne,
      sideAPlayerIds: const ['p2'],
      sideBPlayerIds: const ['p1'],
      scoreA: 0,
      scoreB: 2,
      result: MatchResult.b,
      playedAt: base.add(const Duration(days: 1)),
      createdAt: base.add(const Duration(days: 1, seconds: 1)),
    );
    await store.saveMatches([match1, match2]);
    await service.invalidateH2HCacheForMatch(match2);

    await Future<void>.delayed(const Duration(milliseconds: 2));
    final third = await service.getH2H1v1('p1', 'p2');

    expect(third.totalMatches, 2);
    expect(third.computedAt, isNot(first.computedAt));
  });
}

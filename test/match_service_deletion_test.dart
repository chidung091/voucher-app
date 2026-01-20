import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voucher_app/data/local_store.dart';
import 'package:voucher_app/domain/enums.dart';
import 'package:voucher_app/services/match_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();
  });

  test('Deleting a match rebuilds Elo ratings accurately', () async {
    final service = await MatchService.create();

    // Match 1: P1 beats P2 (Friendly)
    // Initial: 1000 (Skill 2)
    // K=40 (New player) * 0.5 = 20
    // Raw Delta = 20 * (1 - 0.5) = 10
    // Friendly Multiplier 0.5 -> Delta = 10? No, wait.
    // If K=40, raw delta for 1000v1000 win is 40 * 0.5 = 20.
    // Friendly multiplier 0.5 applied to raw delta -> 10.
    // P1: 1010, P2: 990

    final match1 = await service.createMatch(
      MatchInput(
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p2'],
        scoreA: 2,
        scoreB: 0,
        playedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ratingMode: MatchRatingMode.friendly,
      ),
    );

    // Match 2: P1 beats P2 (Ranked)
    // P1: 1010, P2: 990
    // Expected P1: ~0.528
    // Raw Delta: 40 * (1 - 0.528) = 18.88 -> 19
    // P1: 1029, P2: 971
    final match2 = await service.createMatch(
      MatchInput(
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p2'],
        scoreA: 2,
        scoreB: 0,
        playedAt: DateTime.now(),
        ratingMode: MatchRatingMode.ranked,
      ),
    );

    var leaderboard = await service.getLeaderboard();
    var p1 = leaderboard.firstWhere((r) => r.playerId == 'p1');
    expect(p1.elo, 1029);

    // Delete Match 1
    await service.deleteMatch(match1.match.id);

    // After deletion:
    // Only Match 2 exists.
    // P1: 1000, P2: 1000
    // Expected P1: 0.5
    // Delta = 40 * 0.5 = 20
    // P1: 1020, P2: 980
    leaderboard = await service.getLeaderboard();
    p1 = leaderboard.firstWhere((r) => r.playerId == 'p1');
    var p2 = leaderboard.firstWhere((r) => r.playerId == 'p2');

    expect(p1.elo, 1020);
    expect(p2.elo, 980);

    final matches = await service.listMatches();
    expect(matches.length, 1);
    expect(matches.first.id, match2.match.id);
  });
}

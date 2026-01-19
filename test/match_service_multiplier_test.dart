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

  test('Friendly mode applies 0.5x multiplier to delta', () async {
    final service = await MatchService.create();
    final result = await service.createMatch(
      MatchInput(
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p2'],
        scoreA: 2,
        scoreB: 0,
        playedAt: DateTime.now(),
        ratingMode: MatchRatingMode.friendly,
      ),
    );

    final eventA =
        result.events.firstWhere((event) => event.playerId == 'p1');
    final eventB =
        result.events.firstWhere((event) => event.playerId == 'p2');

    expect(eventA.delta, 10);
    expect(eventB.delta, -10);
    expect(eventA.newElo - eventA.oldElo, eventA.delta);
    expect(eventB.newElo - eventB.oldElo, eventB.delta);
  });

  test('Tournament mode applies 1.2x multiplier to delta', () async {
    final service = await MatchService.create();
    final result = await service.createMatch(
      MatchInput(
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p2'],
        scoreA: 3,
        scoreB: 1,
        playedAt: DateTime.now(),
        ratingMode: MatchRatingMode.tournament,
      ),
    );

    final eventA =
        result.events.firstWhere((event) => event.playerId == 'p1');
    final eventB =
        result.events.firstWhere((event) => event.playerId == 'p2');

    expect(eventA.delta, 24);
    expect(eventB.delta, -24);
  });
}

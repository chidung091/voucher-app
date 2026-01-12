import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voucher_app/data/local_store.dart';
import 'package:voucher_app/domain/enums.dart';
import 'package:voucher_app/services/match_service.dart';

void main() {
  test('MatchService idempotency prevents duplicate Elo updates', () async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();

    final service = await MatchService.create();
    final input = MatchInput(
      mode: MatchMode.oneVOne,
      sideAPlayerIds: const ['p1'],
      sideBPlayerIds: const ['p2'],
      scoreA: 2,
      scoreB: 1,
      playedAt: DateTime.now(),
      idempotencyKey: 'match-1',
    );

    final first = await service.createMatch(input);
    final second = await service.createMatch(input);

    expect(first.match.id, second.match.id);
    expect(first.events.length, second.events.length);
  });
}

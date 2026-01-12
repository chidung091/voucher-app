import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voucher_app/data/local_store.dart';
import 'package:voucher_app/domain/elo_config.dart';
import 'package:voucher_app/services/player_service.dart';

void main() {
  test('Player creation seeds initial Elo from skill level', () async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();

    final service = await PlayerService.create();
    final player = await service.createPlayer('Striker', skillLevel: 1);

    final store = await LocalStore.getInstance();
    final ratings = await store.getRatings();
    final rating = ratings[player.id];

    expect(rating, isNotNull);
    expect(rating!.elo, EloConfig.initialEloForSkill(1));
  });
}

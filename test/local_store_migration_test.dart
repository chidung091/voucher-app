import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voucher_app/data/local_store.dart';

void main() {
  test('Players migrate with default skillLevel', () async {
    final playersPayload = [
      {
        'id': 'p1',
        'displayName': 'Alpha',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
    ];
    SharedPreferences.setMockInitialValues({
      'players_v1': jsonEncode(playersPayload),
      'app_meta_v1': jsonEncode({'schemaVersion': 1}),
    });
    LocalStore.resetForTest();

    final store = await LocalStore.getInstance();
    final players = await store.getPlayers();

    expect(players.first.skillLevel, 2);
  });
}

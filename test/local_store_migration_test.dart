import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voucher_app/data/local_store.dart';
import 'package:voucher_app/domain/enums.dart';

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

  test('Matches migrate with default rating mode and multiplier', () async {
    final matchesPayload = [
      {
        'id': 'match-1',
        'mode': '1V1',
        'sideAPlayerIds': ['p1'],
        'sideBPlayerIds': ['p2'],
        'scoreA': 1,
        'scoreB': 0,
        'result': 'A',
        'playedAt': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      },
    ];
    SharedPreferences.setMockInitialValues({
      'matches_v1': jsonEncode(matchesPayload),
      'app_meta_v1': jsonEncode({'schemaVersion': 2}),
    });
    LocalStore.resetForTest();

    final store = await LocalStore.getInstance();
    final matches = await store.getMatches();

    expect(matches.first.ratingMode, MatchRatingMode.ranked);
    expect(matches.first.eloMultiplier, 1.0);
  });
}

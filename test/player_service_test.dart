import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voucher_app/data/local_store.dart';
import 'package:voucher_app/domain/elo_config.dart';
import 'package:voucher_app/services/player_service.dart';

void main() {
  test('Player creation uses default Elo when no initialElo provided',
      () async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();

    final service = await PlayerService.create();
    final player = await service.createPlayer('Striker', skillLevel: 1);

    final store = await LocalStore.getInstance();
    final ratings = await store.getRatings();
    final rating = ratings[player.id];

    expect(rating, isNotNull);
    expect(rating!.elo, EloConfig.defaultElo);
  });

  test('Player creation uses provided initialElo', () async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();

    final service = await PlayerService.create();
    final player = await service.createPlayer(
      'Custom',
      skillLevel: 2,
      initialElo: 1500,
    );

    final store = await LocalStore.getInstance();
    final ratings = await store.getRatings();
    final rating = ratings[player.id];

    expect(rating, isNotNull);
    expect(rating!.elo, 1500);
  });

  test('updatePlayerElo updates player ELO', () async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();

    final service = await PlayerService.create();
    final player = await service.createPlayer('TestPlayer');

    await service.updatePlayerElo(player.id, 1200);

    final ratings = await service.getRatings();
    expect(ratings[player.id]!.elo, 1200);
  });

  test('ELO validation enforces bounds', () async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();

    final service = await PlayerService.create();

    expect(
      () => service.createPlayer('TooLow', initialElo: 50),
      throwsArgumentError,
    );

    expect(
      () => service.createPlayer('TooHigh', initialElo: 5000),
      throwsArgumentError,
    );
  });

  test('resetAllRatings resets all players to default ELO', () async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();

    final service = await PlayerService.create();
    final player1 = await service.createPlayer('Player1', initialElo: 1500);
    final player2 = await service.createPlayer('Player2', initialElo: 1200);

    // Verify initial ELOs
    var ratings = await service.getRatings();
    expect(ratings[player1.id]!.elo, 1500);
    expect(ratings[player2.id]!.elo, 1200);

    // Reset all
    await service.resetAllRatings();

    // Verify all reset to default
    ratings = await service.getRatings();
    expect(ratings[player1.id]!.elo, EloConfig.defaultElo);
    expect(ratings[player2.id]!.elo, EloConfig.defaultElo);
    expect(ratings[player1.id]!.gamesPlayed, 0);
    expect(ratings[player1.id]!.wins, 0);
  });

  test('resetAllRatings applies custom ELOs', () async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();

    final service = await PlayerService.create();
    final player1 = await service.createPlayer('Player1', initialElo: 1500);
    final player2 = await service.createPlayer('Player2', initialElo: 1200);

    // Reset with custom ELOs
    await service.resetAllRatings(customElos: {
      player1.id: 1800,
      player2.id: 900,
    });

    final ratings = await service.getRatings();
    expect(ratings[player1.id]!.elo, 1800);
    expect(ratings[player2.id]!.elo, 900);
  });

  test('resetAllRatings clears rating events', () async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();

    final service = await PlayerService.create();
    await service.createPlayer('Player1');

    await service.resetAllRatings();

    final store = await LocalStore.getInstance();
    final events = await store.getRatingEvents();
    expect(events, isEmpty);
  });
}

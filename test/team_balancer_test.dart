import 'package:flutter_test/flutter_test.dart';
import 'package:voucher_app/domain/player.dart';
import 'package:voucher_app/domain/player_rating.dart';
import 'package:voucher_app/services/team_balancer.dart';

void main() {
  test('TeamBalancer 2v2 minimizes range', () {
    final players = [
      Player(
        id: 'a',
        displayName: 'A',
        skillLevel: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Player(
        id: 'b',
        displayName: 'B',
        skillLevel: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Player(
        id: 'c',
        displayName: 'C',
        skillLevel: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Player(
        id: 'd',
        displayName: 'D',
        skillLevel: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Player(
        id: 'e',
        displayName: 'E',
        skillLevel: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Player(
        id: 'f',
        displayName: 'F',
        skillLevel: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
    final ratings = {
      'a': PlayerRating(
        playerId: 'a',
        elo: 1200,
        gamesPlayed: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        updatedAt: DateTime.now(),
      ),
      'b': PlayerRating(
        playerId: 'b',
        elo: 1180,
        gamesPlayed: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        updatedAt: DateTime.now(),
      ),
      'c': PlayerRating(
        playerId: 'c',
        elo: 1120,
        gamesPlayed: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        updatedAt: DateTime.now(),
      ),
      'd': PlayerRating(
        playerId: 'd',
        elo: 980,
        gamesPlayed: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        updatedAt: DateTime.now(),
      ),
      'e': PlayerRating(
        playerId: 'e',
        elo: 960,
        gamesPlayed: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        updatedAt: DateTime.now(),
      ),
      'f': PlayerRating(
        playerId: 'f',
        elo: 940,
        gamesPlayed: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        updatedAt: DateTime.now(),
      ),
    };
    final pool = TeamBalancer.buildPool(players, ratings);
    final result = TeamBalancer().balanceFor2v2(pool);

    final totals = result.teamTotals..sort();
    expect(totals.last - totals.first, lessThanOrEqualTo(200));
  });

  test('TeamBalancer deterministic output', () {
    final players = [
      Player(
        id: '1',
        displayName: 'One',
        skillLevel: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Player(
        id: '2',
        displayName: 'Two',
        skillLevel: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Player(
        id: '3',
        displayName: 'Three',
        skillLevel: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
    final ratings = {
      '1': PlayerRating(
        playerId: '1',
        elo: 1000,
        gamesPlayed: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        updatedAt: DateTime.now(),
      ),
      '2': PlayerRating(
        playerId: '2',
        elo: 1010,
        gamesPlayed: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        updatedAt: DateTime.now(),
      ),
      '3': PlayerRating(
        playerId: '3',
        elo: 990,
        gamesPlayed: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        updatedAt: DateTime.now(),
      ),
    };
    final pool = TeamBalancer.buildPool(players, ratings);
    final first = TeamBalancer().balanceFor1v1(pool);
    final second = TeamBalancer().balanceFor1v1(pool);

    expect(
      first.teams[0][0].player.id,
      second.teams[0][0].player.id,
    );
  });
}

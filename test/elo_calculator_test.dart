import 'package:flutter_test/flutter_test.dart';
import 'package:voucher_app/domain/elo_calculator.dart';

void main() {
  group('EloCalculator', () {
    test('1v1 win/loss/draw updates correctly', () {
      final calculator = EloCalculator();

      final win = calculator.updateRating(
        rating: 1000,
        opponentRating: 1000,
        actualScore: 1,
        gamesPlayed: 0,
      );
      final loss = calculator.updateRating(
        rating: 1000,
        opponentRating: 1000,
        actualScore: 0,
        gamesPlayed: 0,
      );
      final draw = calculator.updateRating(
        rating: 1000,
        opponentRating: 1000,
        actualScore: 0.5,
        gamesPlayed: 0,
      );

      expect(win, 1020);
      expect(loss, 980);
      expect(draw, 1000);
    });

    test('K-factor changes with games played', () {
      final calculator = EloCalculator();

      expect(calculator.kFactor(0), 40);
      expect(calculator.kFactor(10), 32);
      expect(calculator.kFactor(50), 32);
      expect(calculator.kFactor(51), 24);
    });

    test('2v2 expected score uses team average', () {
      final calculator = EloCalculator();
      final expected = calculator.expectedScoreTeam(1100, 1000);
      expect(expected, greaterThan(0.5));
    });
  });
}

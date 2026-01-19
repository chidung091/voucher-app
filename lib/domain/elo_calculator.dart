import 'dart:math';

class EloCalculator {
  static const int defaultElo = 1000;

  int kFactor(int gamesPlayed) {
    if (gamesPlayed < 10) {
      return 40;
    }
    if (gamesPlayed <= 50) {
      return 32;
    }
    return 24;
  }

  double expectedScore(int ratingA, int ratingB) {
    return 1 / (1 + pow(10, (ratingB - ratingA) / 400));
  }

  int updateRating({
    required int rating,
    required int opponentRating,
    required double actualScore,
    required int gamesPlayed,
  }) {
    final k = kFactor(gamesPlayed);
    final expected = expectedScore(rating, opponentRating);
    final updated = rating + k * (actualScore - expected);
    return updated.round();
  }

  double delta({
    required int rating,
    required int opponentRating,
    required double actualScore,
    required int gamesPlayed,
  }) {
    final k = kFactor(gamesPlayed);
    final expected = expectedScore(rating, opponentRating);
    return k * (actualScore - expected);
  }

  double expectedScoreTeam(int teamRatingA, int teamRatingB) {
    return expectedScore(teamRatingA, teamRatingB);
  }
}

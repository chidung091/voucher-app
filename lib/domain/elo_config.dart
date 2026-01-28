class EloConfig {
  static const int defaultElo = 1000;
  static const int minElo = 100;
  static const int maxElo = 3000;
  static const double teamSizeFactor2v1 = 1.05;

  /// Clamps the given ELO value to the valid range [minElo, maxElo].
  static int clampElo(int elo) {
    if (elo < minElo) return minElo;
    if (elo > maxElo) return maxElo;
    return elo;
  }

  /// Validates if the given ELO is within the allowed range.
  static bool isValidElo(int elo) {
    return elo >= minElo && elo <= maxElo;
  }
}

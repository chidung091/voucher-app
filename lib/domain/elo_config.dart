class EloConfig {
  static const int defaultElo = 1000;
  static const Map<int, int> initialBySkill = {
    1: 1100,
    2: 1000,
    3: 900,
  };
  static const double teamSizeFactor2v1 = 1.05;

  static int initialEloForSkill(int skillLevel) {
    return initialBySkill[skillLevel] ?? defaultElo;
  }
}

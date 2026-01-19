class EloPoint {
  EloPoint({
    required this.timestamp,
    required this.elo,
  });

  final DateTime timestamp;
  final int elo;

  factory EloPoint.fromJson(Map<String, dynamic> json) {
    return EloPoint(
      timestamp: DateTime.parse(json['timestamp'] as String),
      elo: json['elo'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'elo': elo,
    };
  }
}

class PlayerStats {
  PlayerStats({
    required this.playerId,
    required this.computedAt,
    required this.totalMatches,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.winRatePercent,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.currentWinStreak,
    required this.bestWinStreak,
    required this.currentLoseStreak,
    required this.worstLoseStreak,
    required this.currentElo,
    required this.peakElo,
    required this.lowestElo,
    required this.eloHistory,
  });

  final String playerId;
  final DateTime computedAt;
  final int totalMatches;
  final int wins;
  final int draws;
  final int losses;
  final double winRatePercent;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final int currentWinStreak;
  final int bestWinStreak;
  final int currentLoseStreak;
  final int worstLoseStreak;
  final int currentElo;
  final int peakElo;
  final int lowestElo;
  final List<EloPoint> eloHistory;

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    return PlayerStats(
      playerId: json['playerId'] as String,
      computedAt: DateTime.parse(json['computedAt'] as String),
      totalMatches: json['totalMatches'] as int,
      wins: json['wins'] as int,
      draws: json['draws'] as int,
      losses: json['losses'] as int,
      winRatePercent: (json['winRatePercent'] as num).toDouble(),
      goalsFor: json['goalsFor'] as int,
      goalsAgainst: json['goalsAgainst'] as int,
      goalDifference: json['goalDifference'] as int,
      currentWinStreak: json['currentWinStreak'] as int,
      bestWinStreak: json['bestWinStreak'] as int,
      currentLoseStreak: json['currentLoseStreak'] as int,
      worstLoseStreak: json['worstLoseStreak'] as int,
      currentElo: json['currentElo'] as int,
      peakElo: json['peakElo'] as int,
      lowestElo: json['lowestElo'] as int,
      eloHistory: (json['eloHistory'] as List<dynamic>)
          .map((item) => EloPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'computedAt': computedAt.toIso8601String(),
      'totalMatches': totalMatches,
      'wins': wins,
      'draws': draws,
      'losses': losses,
      'winRatePercent': winRatePercent,
      'goalsFor': goalsFor,
      'goalsAgainst': goalsAgainst,
      'goalDifference': goalDifference,
      'currentWinStreak': currentWinStreak,
      'bestWinStreak': bestWinStreak,
      'currentLoseStreak': currentLoseStreak,
      'worstLoseStreak': worstLoseStreak,
      'currentElo': currentElo,
      'peakElo': peakElo,
      'lowestElo': lowestElo,
      'eloHistory': eloHistory.map((point) => point.toJson()).toList(),
    };
  }
}

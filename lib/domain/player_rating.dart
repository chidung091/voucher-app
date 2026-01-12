class PlayerRating {
  PlayerRating({
    required this.playerId,
    required this.elo,
    required this.gamesPlayed,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.updatedAt,
  });

  final String playerId;
  final int elo;
  final int gamesPlayed;
  final int wins;
  final int draws;
  final int losses;
  final DateTime updatedAt;

  PlayerRating copyWith({
    int? elo,
    int? gamesPlayed,
    int? wins,
    int? draws,
    int? losses,
    DateTime? updatedAt,
  }) {
    return PlayerRating(
      playerId: playerId,
      elo: elo ?? this.elo,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      wins: wins ?? this.wins,
      draws: draws ?? this.draws,
      losses: losses ?? this.losses,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory PlayerRating.fromJson(Map<String, dynamic> json) {
    return PlayerRating(
      playerId: json['playerId'] as String,
      elo: json['elo'] as int,
      gamesPlayed: json['gamesPlayed'] as int,
      wins: json['wins'] as int,
      draws: json['draws'] as int,
      losses: json['losses'] as int,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'elo': elo,
      'gamesPlayed': gamesPlayed,
      'wins': wins,
      'draws': draws,
      'losses': losses,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

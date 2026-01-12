class RatingEvent {
  RatingEvent({
    required this.id,
    required this.matchId,
    required this.playerId,
    required this.oldElo,
    required this.newElo,
    required this.delta,
    required this.createdAt,
  });

  final String id;
  final String matchId;
  final String playerId;
  final int oldElo;
  final int newElo;
  final int delta;
  final DateTime createdAt;

  factory RatingEvent.fromJson(Map<String, dynamic> json) {
    return RatingEvent(
      id: json['id'] as String,
      matchId: json['matchId'] as String,
      playerId: json['playerId'] as String,
      oldElo: json['oldElo'] as int,
      newElo: json['newElo'] as int,
      delta: json['delta'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'matchId': matchId,
      'playerId': playerId,
      'oldElo': oldElo,
      'newElo': newElo,
      'delta': delta,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

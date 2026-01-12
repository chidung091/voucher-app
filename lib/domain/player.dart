class Player {
  Player({
    required this.id,
    required this.displayName,
    this.skillLevel = 2,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String displayName;
  final int skillLevel;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Player copyWith({
    String? displayName,
    int? skillLevel,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Player(
      id: id,
      displayName: displayName ?? this.displayName,
      skillLevel: skillLevel ?? this.skillLevel,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      skillLevel: (json['skillLevel'] as int?) ?? 2,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'skillLevel': skillLevel,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }
}

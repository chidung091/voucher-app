class Club {
  Club({
    required this.id,
    required this.name,
    required this.stars,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final double stars;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Club copyWith({
    String? name,
    double? stars,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Club(
      id: id,
      name: name ?? this.name,
      stars: stars ?? this.stars,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: json['id'] as String,
      name: json['name'] as String,
      stars: (json['stars'] as num).toDouble(),
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
      'name': name,
      'stars': stars,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }
}

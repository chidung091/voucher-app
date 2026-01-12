import 'enums.dart';

class Tournament {
  Tournament({
    required this.id,
    required this.name,
    required this.mode,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.championTeamIndex,
    this.finalsEnabled = true,
  });

  final String id;
  final String name;
  final MatchMode mode;
  final TournamentStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? championTeamIndex;
  final bool finalsEnabled;

  Tournament copyWith({
    String? name,
    MatchMode? mode,
    TournamentStatus? status,
    DateTime? updatedAt,
    int? championTeamIndex,
    bool? finalsEnabled,
  }) {
    return Tournament(
      id: id,
      name: name ?? this.name,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      championTeamIndex: championTeamIndex ?? this.championTeamIndex,
      finalsEnabled: finalsEnabled ?? this.finalsEnabled,
    );
  }

  factory Tournament.fromJson(Map<String, dynamic> json) {
    return Tournament(
      id: json['id'] as String,
      name: json['name'] as String,
      mode: MatchModeJson.fromJson(json['mode'] as String),
      status: TournamentStatusJson.fromJson(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      championTeamIndex: json['championTeamIndex'] as int?,
      finalsEnabled: json['finalsEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mode': mode.toJson(),
      'status': status.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'championTeamIndex': championTeamIndex,
      'finalsEnabled': finalsEnabled,
    };
  }
}

import 'enums.dart';

class Season {
  Season({
    required this.id,
    required this.seasonType,
    required this.startAt,
    required this.endAt,
  });

  final String id;
  final SeasonType seasonType;
  final DateTime startAt;
  final DateTime endAt;
}

class SeasonConfig {
  SeasonConfig({
    required this.seasonType,
    required this.baselineElo,
    required this.resetPolicy,
    required this.softResetAlpha,
    required this.updatedAt,
  });

  final SeasonType seasonType;
  final int baselineElo;
  final SeasonResetPolicy resetPolicy;
  final double softResetAlpha;
  final DateTime updatedAt;

  factory SeasonConfig.defaults() {
    return SeasonConfig(
      seasonType: SeasonType.month,
      baselineElo: 1000,
      resetPolicy: SeasonResetPolicy.none,
      softResetAlpha: 0.5,
      updatedAt: DateTime.now(),
    );
  }

  SeasonConfig copyWith({
    SeasonType? seasonType,
    int? baselineElo,
    SeasonResetPolicy? resetPolicy,
    double? softResetAlpha,
    DateTime? updatedAt,
  }) {
    return SeasonConfig(
      seasonType: seasonType ?? this.seasonType,
      baselineElo: baselineElo ?? this.baselineElo,
      resetPolicy: resetPolicy ?? this.resetPolicy,
      softResetAlpha: softResetAlpha ?? this.softResetAlpha,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory SeasonConfig.fromJson(Map<String, dynamic> json) {
    return SeasonConfig(
      seasonType: SeasonTypeJson.fromJson(json['seasonType'] as String),
      baselineElo: json['baselineElo'] as int,
      resetPolicy:
          SeasonResetPolicyJson.fromJson(json['resetPolicy'] as String),
      softResetAlpha: (json['softResetAlpha'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seasonType': seasonType.toJson(),
      'baselineElo': baselineElo,
      'resetPolicy': resetPolicy.toJson(),
      'softResetAlpha': softResetAlpha,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class SeasonRow {
  SeasonRow({
    required this.playerId,
    required this.displayName,
    required this.seasonElo,
    required this.deltaFromStart,
    required this.matchesPlayed,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
  });

  final String playerId;
  final String displayName;
  final int seasonElo;
  final int deltaFromStart;
  final int matchesPlayed;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'displayName': displayName,
      'seasonElo': seasonElo,
      'deltaFromStart': deltaFromStart,
      'matchesPlayed': matchesPlayed,
      'wins': wins,
      'draws': draws,
      'losses': losses,
      'goalsFor': goalsFor,
      'goalsAgainst': goalsAgainst,
    };
  }

  factory SeasonRow.fromJson(Map<String, dynamic> json) {
    return SeasonRow(
      playerId: json['playerId'] as String,
      displayName: json['displayName'] as String,
      seasonElo: json['seasonElo'] as int,
      deltaFromStart: json['deltaFromStart'] as int,
      matchesPlayed: json['matchesPlayed'] as int,
      wins: json['wins'] as int,
      draws: json['draws'] as int,
      losses: json['losses'] as int,
      goalsFor: json['goalsFor'] as int,
      goalsAgainst: json['goalsAgainst'] as int,
    );
  }
}

class SeasonLeaderboard {
  SeasonLeaderboard({
    required this.seasonId,
    required this.seasonType,
    required this.startAt,
    required this.endAt,
    required this.rows,
    required this.computedAt,
    required this.boundaryEstimated,
  });

  final String seasonId;
  final SeasonType seasonType;
  final DateTime startAt;
  final DateTime endAt;
  final List<SeasonRow> rows;
  final DateTime computedAt;
  final bool boundaryEstimated;

  Map<String, dynamic> toJson() {
    return {
      'seasonId': seasonId,
      'seasonType': seasonType.toJson(),
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      'rows': rows.map((row) => row.toJson()).toList(),
      'computedAt': computedAt.toIso8601String(),
      'boundaryEstimated': boundaryEstimated,
    };
  }

  factory SeasonLeaderboard.fromJson(Map<String, dynamic> json) {
    return SeasonLeaderboard(
      seasonId: json['seasonId'] as String,
      seasonType: SeasonTypeJson.fromJson(json['seasonType'] as String),
      startAt: DateTime.parse(json['startAt'] as String),
      endAt: DateTime.parse(json['endAt'] as String),
      rows: (json['rows'] as List<dynamic>)
          .map((item) => SeasonRow.fromJson(item as Map<String, dynamic>))
          .toList(),
      computedAt: DateTime.parse(json['computedAt'] as String),
      boundaryEstimated: json['boundaryEstimated'] as bool? ?? false,
    );
  }
}

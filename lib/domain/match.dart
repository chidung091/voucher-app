import 'enums.dart';

class Match {
  Match({
    required this.id,
    required this.mode,
    required this.sideAPlayerIds,
    required this.sideBPlayerIds,
    required this.scoreA,
    required this.scoreB,
    required this.result,
    required this.playedAt,
    required this.createdAt,
    this.idempotencyKey,
    this.tournamentId,
    this.tournamentMatchId,
    this.metadata,
  });

  final String id;
  final MatchMode mode;
  final List<String> sideAPlayerIds;
  final List<String> sideBPlayerIds;
  final int scoreA;
  final int scoreB;
  final MatchResult result;
  final DateTime playedAt;
  final DateTime createdAt;
  final String? idempotencyKey;
  final String? tournamentId;
  final String? tournamentMatchId;
  final Map<String, dynamic>? metadata;

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      id: json['id'] as String,
      mode: MatchModeJson.fromJson(json['mode'] as String),
      sideAPlayerIds:
          (json['sideAPlayerIds'] as List<dynamic>).cast<String>(),
      sideBPlayerIds:
          (json['sideBPlayerIds'] as List<dynamic>).cast<String>(),
      scoreA: json['scoreA'] as int,
      scoreB: json['scoreB'] as int,
      result: MatchResultJson.fromJson(json['result'] as String),
      playedAt: DateTime.parse(json['playedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      idempotencyKey: json['idempotencyKey'] as String?,
      tournamentId: json['tournamentId'] as String?,
      tournamentMatchId: json['tournamentMatchId'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mode': mode.toJson(),
      'sideAPlayerIds': sideAPlayerIds,
      'sideBPlayerIds': sideBPlayerIds,
      'scoreA': scoreA,
      'scoreB': scoreB,
      'result': result.toJson(),
      'playedAt': playedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'idempotencyKey': idempotencyKey,
      'tournamentId': tournamentId,
      'tournamentMatchId': tournamentMatchId,
      'metadata': metadata,
    };
  }
}

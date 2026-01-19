import 'enums.dart';

class TournamentMatch {
  TournamentMatch({
    required this.id,
    required this.tournamentId,
    required this.stage,
    required this.homeTeamIndex,
    required this.awayTeamIndex,
    required this.scheduledOrder,
    required this.status,
    this.matchId,
    this.homeAssignedStars,
    this.awayAssignedStars,
    this.homeClubId,
    this.awayClubId,
    this.clubAssignmentMode = ClubAssignmentMode.auto,
  });

  final String id;
  final String tournamentId;
  final TournamentStage stage;
  final int homeTeamIndex;
  final int awayTeamIndex;
  final int scheduledOrder;
  final TournamentMatchStatus status;
  final String? matchId;
  final double? homeAssignedStars;
  final double? awayAssignedStars;
  final String? homeClubId;
  final String? awayClubId;
  final ClubAssignmentMode clubAssignmentMode;

  TournamentMatch copyWith({
    TournamentStage? stage,
    int? homeTeamIndex,
    int? awayTeamIndex,
    int? scheduledOrder,
    TournamentMatchStatus? status,
    String? matchId,
    double? homeAssignedStars,
    double? awayAssignedStars,
    String? homeClubId,
    String? awayClubId,
    ClubAssignmentMode? clubAssignmentMode,
  }) {
    return TournamentMatch(
      id: id,
      tournamentId: tournamentId,
      stage: stage ?? this.stage,
      homeTeamIndex: homeTeamIndex ?? this.homeTeamIndex,
      awayTeamIndex: awayTeamIndex ?? this.awayTeamIndex,
      scheduledOrder: scheduledOrder ?? this.scheduledOrder,
      status: status ?? this.status,
      matchId: matchId ?? this.matchId,
      homeAssignedStars: homeAssignedStars ?? this.homeAssignedStars,
      awayAssignedStars: awayAssignedStars ?? this.awayAssignedStars,
      homeClubId: homeClubId ?? this.homeClubId,
      awayClubId: awayClubId ?? this.awayClubId,
      clubAssignmentMode: clubAssignmentMode ?? this.clubAssignmentMode,
    );
  }

  factory TournamentMatch.fromJson(Map<String, dynamic> json) {
    return TournamentMatch(
      id: json['id'] as String,
      tournamentId: json['tournamentId'] as String,
      stage: TournamentStageJson.fromJson(json['stage'] as String),
      homeTeamIndex: json['homeTeamIndex'] as int,
      awayTeamIndex: json['awayTeamIndex'] as int,
      scheduledOrder: json['scheduledOrder'] as int,
      status: TournamentMatchStatusJson.fromJson(json['status'] as String),
      matchId: json['matchId'] as String?,
      homeAssignedStars: (json['homeAssignedStars'] as num?)?.toDouble(),
      awayAssignedStars: (json['awayAssignedStars'] as num?)?.toDouble(),
      homeClubId: json['homeClubId'] as String?,
      awayClubId: json['awayClubId'] as String?,
      clubAssignmentMode: ClubAssignmentModeJson.fromJson(
        json['clubAssignmentMode'] as String? ?? 'AUTO',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tournamentId': tournamentId,
      'stage': stage.toJson(),
      'homeTeamIndex': homeTeamIndex,
      'awayTeamIndex': awayTeamIndex,
      'scheduledOrder': scheduledOrder,
      'status': status.toJson(),
      'matchId': matchId,
      'homeAssignedStars': homeAssignedStars,
      'awayAssignedStars': awayAssignedStars,
      'homeClubId': homeClubId,
      'awayClubId': awayClubId,
      'clubAssignmentMode': clubAssignmentMode.toJson(),
    };
  }
}

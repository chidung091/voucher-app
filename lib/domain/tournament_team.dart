class TournamentTeam {
  TournamentTeam({
    required this.id,
    required this.tournamentId,
    required this.teamIndex,
    required this.name,
    required this.playerIds,
  });

  final String id;
  final String tournamentId;
  final int teamIndex;
  final String name;
  final List<String> playerIds;

  factory TournamentTeam.fromJson(Map<String, dynamic> json) {
    return TournamentTeam(
      id: json['id'] as String,
      tournamentId: json['tournamentId'] as String,
      teamIndex: json['teamIndex'] as int,
      name: json['name'] as String,
      playerIds: (json['playerIds'] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tournamentId': tournamentId,
      'teamIndex': teamIndex,
      'name': name,
      'playerIds': playerIds,
    };
  }
}

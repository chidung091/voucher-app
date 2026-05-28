class TournamentTeam {
  TournamentTeam({
    required this.id,
    required this.tournamentId,
    required this.teamIndex,
    required this.name,
    required this.playerIds,
  }) {
    if (playerIds.isEmpty || playerIds.length > 2) {
      throw ArgumentError('TournamentTeam must have 1 or 2 players.');
    }
  }

  final String id;
  final String tournamentId;
  final int teamIndex;
  final String name;
  final List<String> playerIds;
  int get teamSize => playerIds.length;

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

import '../domain/elo_config.dart';
import '../domain/player.dart';
import '../domain/player_rating.dart';
import '../domain/tournament_team.dart';

class TeamEloSnapshot {
  TeamEloSnapshot({
    required this.rawElo,
    required this.effectiveElo,
    required this.teamSize,
  });

  final double rawElo;
  final double effectiveElo;
  final int teamSize;
}

class TeamEloCalculator {
  TeamEloSnapshot computeTeamElo({
    required List<String> playerIds,
    required Map<String, Player> players,
    required Map<String, PlayerRating> ratings,
  }) {
    final teamSize = playerIds.length;
    if (teamSize == 0) {
      return TeamEloSnapshot(rawElo: 0, effectiveElo: 0, teamSize: 0);
    }
    final elos = playerIds.map((id) {
      final rating = ratings[id]?.elo;
      if (rating != null) return rating.toDouble();
      final skill = players[id]?.skillLevel ?? 2;
      return EloConfig.initialEloForSkill(skill).toDouble();
    }).toList();

    final raw = elos.reduce((a, b) => a + b) / elos.length;
    final factor = teamSize == 2 ? EloConfig.teamSizeFactor2v1 : 1.0;
    final effective = raw * factor;
    return TeamEloSnapshot(
      rawElo: raw,
      effectiveElo: effective,
      teamSize: teamSize,
    );
  }

  Map<int, TeamEloSnapshot> computeTournamentTeamElos({
    required List<TournamentTeam> teams,
    required List<Player> players,
    required Map<String, PlayerRating> ratings,
  }) {
    final playerMap = {for (final player in players) player.id: player};
    final result = <int, TeamEloSnapshot>{};
    for (final team in teams) {
      result[team.teamIndex] = computeTeamElo(
        playerIds: team.playerIds,
        players: playerMap,
        ratings: ratings,
      );
    }
    return result;
  }

  Map<int, int> computeTeamRanks(Map<int, TeamEloSnapshot> snapshots) {
    final entries = snapshots.entries.toList()
      ..sort((a, b) {
        final diff = b.value.effectiveElo.compareTo(a.value.effectiveElo);
        if (diff != 0) return diff;
        return a.key.compareTo(b.key);
      });
    final ranks = <int, int>{};
    for (var i = 0; i < entries.length; i++) {
      ranks[entries[i].key] = i + 1;
    }
    return ranks;
  }
}

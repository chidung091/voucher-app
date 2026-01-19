import 'enums.dart';
import 'match.dart';
import 'tournament_match.dart';
import 'tournament_team.dart';

class TournamentStanding {
  TournamentStanding({
    required this.teamIndex,
    this.points = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
  });

  final int teamIndex;
  int points;
  int goalsFor;
  int goalsAgainst;

  int get goalDifference => goalsFor - goalsAgainst;
}

class TournamentStandingsCalculator {
  List<TournamentStanding> compute({
    required List<TournamentTeam> teams,
    required List<TournamentMatch> matches,
    required List<Match> matchHistory,
  }) {
    final table = {
      for (final team in teams)
        team.teamIndex: TournamentStanding(teamIndex: team.teamIndex),
    };

    for (final tm in matches) {
      if (tm.stage != TournamentStage.group) continue;
      if (tm.status != TournamentMatchStatus.done) continue;
      if (tm.matchId == null) continue;
      final match = matchHistory.firstWhere(
        (element) => element.id == tm.matchId,
        orElse: () => Match(
          id: tm.matchId!,
          mode: MatchMode.oneVOne,
          sideAPlayerIds: const [],
          sideBPlayerIds: const [],
          scoreA: 0,
          scoreB: 0,
          result: MatchResult.draw,
          playedAt: DateTime.fromMillisecondsSinceEpoch(0),
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
      if (match.sideAPlayerIds.isEmpty && match.sideBPlayerIds.isEmpty) {
        continue;
      }

      final home = table[tm.homeTeamIndex]!;
      final away = table[tm.awayTeamIndex]!;
      home.goalsFor += match.scoreA;
      home.goalsAgainst += match.scoreB;
      away.goalsFor += match.scoreB;
      away.goalsAgainst += match.scoreA;

      if (match.result == MatchResult.draw) {
        home.points += 1;
        away.points += 1;
      } else if (match.result == MatchResult.a) {
        home.points += 3;
      } else {
        away.points += 3;
      }
    }

    final standings = table.values.toList();
    final headToHeadMap = _buildHeadToHeadMap(
      standings,
      matches,
      matchHistory,
    );
    standings.sort((a, b) {
      final points = b.points.compareTo(a.points);
      if (points != 0) return points;
      final gd = b.goalDifference.compareTo(a.goalDifference);
      if (gd != 0) return gd;
      final gf = b.goalsFor.compareTo(a.goalsFor);
      if (gf != 0) return gf;
      final headToHead = (headToHeadMap[b.teamIndex] ?? 0)
          .compareTo(headToHeadMap[a.teamIndex] ?? 0);
      if (headToHead != 0) return headToHead;
      return a.teamIndex.compareTo(b.teamIndex);
    });
    return standings;
  }

  Map<int, int> _buildHeadToHeadMap(
    List<TournamentStanding> standings,
    List<TournamentMatch> matches,
    List<Match> matchHistory,
  ) {
    final grouped = <String, List<TournamentStanding>>{};
    for (final standing in standings) {
      final key =
          '${standing.points}-${standing.goalDifference}-${standing.goalsFor}';
      grouped.putIfAbsent(key, () => []).add(standing);
    }

    final headToHeadPoints = <int, int>{};
    for (final group in grouped.values) {
      if (group.length <= 1) continue;
      final teamIndexes = group.map((s) => s.teamIndex).toSet();
      for (final tm in matches) {
        if (tm.stage != TournamentStage.group) continue;
        if (tm.matchId == null) continue;
        if (!teamIndexes.contains(tm.homeTeamIndex) ||
            !teamIndexes.contains(tm.awayTeamIndex)) {
          continue;
        }
        final match = matchHistory.firstWhere(
          (element) => element.id == tm.matchId,
          orElse: () => Match(
            id: tm.matchId!,
            mode: MatchMode.oneVOne,
            sideAPlayerIds: const [],
            sideBPlayerIds: const [],
            scoreA: 0,
            scoreB: 0,
            result: MatchResult.draw,
            playedAt: DateTime.fromMillisecondsSinceEpoch(0),
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        );
        if (match.sideAPlayerIds.isEmpty && match.sideBPlayerIds.isEmpty) {
          continue;
        }
        if (match.result == MatchResult.draw) {
          headToHeadPoints[tm.homeTeamIndex] =
              (headToHeadPoints[tm.homeTeamIndex] ?? 0) + 1;
          headToHeadPoints[tm.awayTeamIndex] =
              (headToHeadPoints[tm.awayTeamIndex] ?? 0) + 1;
        } else if (match.result == MatchResult.a) {
          headToHeadPoints[tm.homeTeamIndex] =
              (headToHeadPoints[tm.homeTeamIndex] ?? 0) + 3;
        } else {
          headToHeadPoints[tm.awayTeamIndex] =
              (headToHeadPoints[tm.awayTeamIndex] ?? 0) + 3;
        }
      }
    }
    return headToHeadPoints;
  }
}

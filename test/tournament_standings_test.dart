import 'package:flutter_test/flutter_test.dart';
import 'package:voucher_app/domain/enums.dart';
import 'package:voucher_app/domain/match.dart';
import 'package:voucher_app/domain/tournament_match.dart';
import 'package:voucher_app/domain/tournament_standings.dart';
import 'package:voucher_app/domain/tournament_team.dart';

void main() {
  test('Tournament standings apply tie-breakers', () {
    final teams = [
      TournamentTeam(
        id: 't0',
        tournamentId: 'tour1',
        teamIndex: 0,
        name: 'Team 1',
        playerIds: const ['p1'],
      ),
      TournamentTeam(
        id: 't1',
        tournamentId: 'tour1',
        teamIndex: 1,
        name: 'Team 2',
        playerIds: const ['p2'],
      ),
      TournamentTeam(
        id: 't2',
        tournamentId: 'tour1',
        teamIndex: 2,
        name: 'Team 3',
        playerIds: const ['p3'],
      ),
    ];

    final matches = [
      TournamentMatch(
        id: 'm1',
        tournamentId: 'tour1',
        stage: TournamentStage.group,
        homeTeamIndex: 0,
        awayTeamIndex: 1,
        scheduledOrder: 1,
        status: TournamentMatchStatus.done,
        matchId: 'match1',
      ),
      TournamentMatch(
        id: 'm2',
        tournamentId: 'tour1',
        stage: TournamentStage.group,
        homeTeamIndex: 0,
        awayTeamIndex: 2,
        scheduledOrder: 2,
        status: TournamentMatchStatus.done,
        matchId: 'match2',
      ),
      TournamentMatch(
        id: 'm3',
        tournamentId: 'tour1',
        stage: TournamentStage.group,
        homeTeamIndex: 1,
        awayTeamIndex: 2,
        scheduledOrder: 3,
        status: TournamentMatchStatus.done,
        matchId: 'match3',
      ),
    ];

    final matchHistory = [
      Match(
        id: 'match1',
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p2'],
        scoreA: 1,
        scoreB: 0,
        result: MatchResult.a,
        playedAt: DateTime.now(),
        createdAt: DateTime.now(),
      ),
      Match(
        id: 'match2',
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p1'],
        sideBPlayerIds: const ['p3'],
        scoreA: 0,
        scoreB: 1,
        result: MatchResult.b,
        playedAt: DateTime.now(),
        createdAt: DateTime.now(),
      ),
      Match(
        id: 'match3',
        mode: MatchMode.oneVOne,
        sideAPlayerIds: const ['p2'],
        sideBPlayerIds: const ['p3'],
        scoreA: 2,
        scoreB: 1,
        result: MatchResult.a,
        playedAt: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    ];

    final standings = TournamentStandingsCalculator().compute(
      teams: teams,
      matches: matches,
      matchHistory: matchHistory,
    );

    expect(standings[0].teamIndex, 1);
    expect(standings[1].teamIndex, 2);
    expect(standings[2].teamIndex, 0);
  });
}

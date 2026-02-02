// test/ranking_logic_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:voucher_app/domain/enums.dart';
import 'package:voucher_app/domain/match.dart';
import 'package:voucher_app/domain/tournament_match.dart';
import 'package:voucher_app/domain/tournament_standings.dart';
import 'package:voucher_app/domain/tournament_team.dart';

void main() {
  // Helpers
  TournamentTeam createTeam(int index, String name) {
    return TournamentTeam(
      id: 't$index',
      tournamentId: 'tour1',
      teamIndex: index,
      name: name,
      playerIds: ['p$index'],
    );
  }

  Match createMatch(String id, String pA, String pB, int sA, int sB) {
    MatchResult result;
    if (sA > sB) {
      result = MatchResult.a;
    } else if (sB > sA) {
      result = MatchResult.b;
    } else {
      result = MatchResult.draw;
    }

    return Match(
      id: id,
      mode: MatchMode.oneVOne,
      sideAPlayerIds: [pA],
      sideBPlayerIds: [pB],
      scoreA: sA,
      scoreB: sB,
      result: result,
      playedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }

  TournamentMatch createTM(int index, int home, int away, String matchId) {
    return TournamentMatch(
      id: 'tm$index',
      tournamentId: 'tour1',
      stage: TournamentStage.group,
      homeTeamIndex: home,
      awayTeamIndex: away,
      scheduledOrder: index,
      status: TournamentMatchStatus.done,
      matchId: matchId,
    );
  }

  group('Tournament Ranking Logic', () {
    test('Points -> GD -> GF', () {
      // Team 0: 3 Pts, GD +2 (5-3), GF 5
      // Team 1: 3 Pts, GD +3 (4-1), GF 4
      // Team 1 should lead due to better GD, even though Team 0 has better GF.

      final teams = [
        createTeam(0, 'Team A'),
        createTeam(1, 'Team B'),
        createTeam(2, 'Team C'),
        createTeam(3, 'Team D'),
      ];

      final matches = [
        createTM(1, 0, 2, 'm1'), // 0 vs 2
        createTM(2, 1, 3, 'm2'), // 1 vs 3
      ];

      final matchHistory = [
        createMatch('m1', 'p0', 'p2', 5, 3),
        createMatch('m2', 'p1', 'p3', 4, 1),
      ];

      final calculator = TournamentStandingsCalculator();
      final standings = calculator.compute(
          teams: teams, matches: matches, matchHistory: matchHistory);

      final top2 = standings.take(2).toList();
      expect(top2[0].teamIndex, 1, reason: 'Team B has GD +3');
      expect(top2[1].teamIndex, 0, reason: 'Team A has GD +2');
    });

    test('Equal GD -> Check GF', () {
      // Team 0: 3 Pts, GD +2 (5-3), GF 5
      // Team 1: 3 Pts, GD +2 (4-2), GF 4
      // Team 0 should lead due to better GF.

      final teams = [
        createTeam(0, 'Team A'),
        createTeam(1, 'Team B'),
        createTeam(2, 'Team C'),
        createTeam(3, 'Team D'),
      ];

      final matches = [
        createTM(1, 0, 2, 'm1'), // 0 vs 2
        createTM(2, 1, 3, 'm2'), // 1 vs 3
      ];

      final matchHistory = [
        createMatch('m1', 'p0', 'p2', 5, 3),
        createMatch('m2', 'p1', 'p3', 4, 2),
      ];

      final calculator = TournamentStandingsCalculator();
      final standings = calculator.compute(
          teams: teams, matches: matches, matchHistory: matchHistory);

      final top2 = standings.take(2).toList();
      expect(top2[0].teamIndex, 0, reason: 'Team A has GF 5');
      expect(top2[1].teamIndex, 1, reason: 'Team B has GF 4');
    });
  });
}

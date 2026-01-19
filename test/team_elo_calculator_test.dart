import 'package:flutter_test/flutter_test.dart';
import 'package:voucher_app/domain/player.dart';
import 'package:voucher_app/domain/player_rating.dart';
import 'package:voucher_app/domain/tournament_team.dart';
import 'package:voucher_app/services/team_elo_calculator.dart';

void main() {
  test('TeamEloCalculator ranks teams by effective Elo with size factor', () {
    final players = [
      Player(
        id: 'p1',
        displayName: 'Solo',
        skillLevel: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Player(
        id: 'p2',
        displayName: 'Duo A',
        skillLevel: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Player(
        id: 'p3',
        displayName: 'Duo B',
        skillLevel: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
    final ratings = {
      'p1': PlayerRating(
        playerId: 'p1',
        elo: 1300,
        gamesPlayed: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        updatedAt: DateTime.now(),
      ),
      'p2': PlayerRating(
        playerId: 'p2',
        elo: 1250,
        gamesPlayed: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        updatedAt: DateTime.now(),
      ),
      'p3': PlayerRating(
        playerId: 'p3',
        elo: 1250,
        gamesPlayed: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        updatedAt: DateTime.now(),
      ),
    };
    final teams = [
      TournamentTeam(
        id: 't1',
        tournamentId: 't',
        teamIndex: 0,
        name: 'Solo',
        playerIds: const ['p1'],
      ),
      TournamentTeam(
        id: 't2',
        tournamentId: 't',
        teamIndex: 1,
        name: 'Duo',
        playerIds: const ['p2', 'p3'],
      ),
    ];

    final calculator = TeamEloCalculator();
    final snapshots = calculator.computeTournamentTeamElos(
      teams: teams,
      players: players,
      ratings: ratings,
    );
    final ranks = calculator.computeTeamRanks(snapshots);

    expect(ranks[1], 1);
    expect(ranks[0], 2);
  });
}

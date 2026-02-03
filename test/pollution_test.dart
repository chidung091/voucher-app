import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voucher_app/data/local_store.dart';
import 'package:voucher_app/domain/enums.dart';
import 'package:voucher_app/services/match_service.dart';
import 'package:voucher_app/services/player_service.dart';
import 'package:voucher_app/services/tournament_service.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('Tournament Standing Pollution Test', () {
    late LocalStore store;
    late TournamentService service;
    late PlayerService playerService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      LocalStore.resetForTest();
      store = await LocalStore.getInstance();
      playerService = await PlayerService.create();
      final matchService = await MatchService.create();
      service = TournamentService(store, const Uuid(), matchService);
    });

    test('Standalone standings should not be polluted by other tournaments',
        () async {
      // Create 3 players
      final p1 = await playerService.createPlayer('Player 1');
      final p2 = await playerService.createPlayer('Player 2');
      final p3 = await playerService.createPlayer('Player 3');

      // Create Tournament A
      final viewA = await service.createTournament(TournamentInput(
        name: 'Tournament A',
        mode: MatchMode.oneVOne,
        finalsEnabled: false,
        teams: [
          TournamentTeamInput(name: 'Team A0', playerIds: [p1.id]),
          TournamentTeamInput(name: 'Team A1', playerIds: [p2.id]),
          TournamentTeamInput(name: 'Team A2', playerIds: [p3.id]),
        ],
      ));

      // Create Tournament B
      final viewB = await service.createTournament(TournamentInput(
        name: 'Tournament B',
        mode: MatchMode.oneVOne,
        finalsEnabled: false,
        teams: [
          TournamentTeamInput(name: 'Team B0', playerIds: [p1.id]),
          TournamentTeamInput(name: 'Team B1', playerIds: [p2.id]),
          TournamentTeamInput(name: 'Team B2', playerIds: [p3.id]),
        ],
      ));

      // In Tournament A, Team 0 wins all matches
      final matchA01 = viewA.matches
          .firstWhere((m) => m.homeTeamIndex == 0 && m.awayTeamIndex == 1);
      await service.recordTournamentMatchResult(
        tournamentId: viewA.tournament.id,
        tournamentMatchId: matchA01.id,
        scoreHome: 10,
        scoreAway: 0,
      );

      final matchA02 = viewA.matches
          .firstWhere((m) => m.homeTeamIndex == 0 && m.awayTeamIndex == 2);
      await service.recordTournamentMatchResult(
        tournamentId: viewA.tournament.id,
        tournamentMatchId: matchA02.id,
        scoreHome: 10,
        scoreAway: 0,
      );

      final matchA12 = viewA.matches
          .firstWhere((m) => m.homeTeamIndex == 1 && m.awayTeamIndex == 2);
      await service.recordTournamentMatchResult(
        tournamentId: viewA.tournament.id,
        tournamentMatchId: matchA12.id,
        scoreHome: 1,
        scoreAway: 0,
      );

      // Verify Tournament A completed
      final updatedViewA = await service.getTournament(viewA.tournament.id);
      expect(updatedViewA.tournament.status, TournamentStatus.completed);
      expect(updatedViewA.tournament.championTeamIndex, 0);

      // In Tournament B, Team 2 wins everything
      final matchB01 = viewB.matches
          .firstWhere((m) => m.homeTeamIndex == 0 && m.awayTeamIndex == 1);
      await service.recordTournamentMatchResult(
        tournamentId: viewB.tournament.id,
        tournamentMatchId: matchB01.id,
        scoreHome: 0,
        scoreAway: 0,
      );

      final matchB02 = viewB.matches
          .firstWhere((m) => m.homeTeamIndex == 0 && m.awayTeamIndex == 2);
      await service.recordTournamentMatchResult(
        tournamentId: viewB.tournament.id,
        tournamentMatchId: matchB02.id,
        scoreHome: 0,
        scoreAway: 1,
      );

      // Final match for Tournament B
      final matchB12 = viewB.matches
          .firstWhere((m) => m.homeTeamIndex == 1 && m.awayTeamIndex == 2);
      final updatedViewB = await service.recordTournamentMatchResult(
        tournamentId: viewB.tournament.id,
        tournamentMatchId: matchB12.id,
        scoreHome: 0,
        scoreAway: 5,
      );

      expect(updatedViewB.tournament.status, TournamentStatus.completed);

      // Champion of B should be Team 2.
      // If polluted by A, Team 0 might win because it had 2 wins in Tournament A.
      expect(updatedViewB.tournament.championTeamIndex, 2);
    });
  });
}

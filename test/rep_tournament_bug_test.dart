import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voucher_app/data/local_store.dart';
import 'package:voucher_app/domain/enums.dart';
import 'package:voucher_app/services/match_service.dart';
import 'package:voucher_app/services/player_service.dart';
import 'package:voucher_app/services/tournament_service.dart';
import 'package:uuid/uuid.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();
  });

  test('Reproduction: 1v1 Tournament Finals Score & Deletion', () async {
    // 1. Setup
    final store = await LocalStore.getInstance();
    await store.savePlayers([]);
    await store.saveMatches([]);
    await store.saveTournaments([]);
    await store.saveTournamentMatches([]); // Clear existing
    await store.saveTournamentTeams([]);

    final matchService = await MatchService.create();
    final service = TournamentService(store, const Uuid(), matchService);
    final playerService = await PlayerService.create();

    final p1 = await playerService.createPlayer('P1');
    final p2 = await playerService.createPlayer('P2');

    // 2. Create Tournament
    final tournamentView = await service.createTournamentAutoBalanced(
      name: 'Bug Repro',
      mode: MatchMode.oneVOne,
      playerIdsPool: [p1.id, p2.id],
      finalsEnabled: true,
    );

    // 3. Play Group Match (Should assign finals teams)
    final groupMatch = tournamentView.matches
        .firstWhere((m) => m.stage == TournamentStage.group);
    await service.recordTournamentMatchResult(
      tournamentId: tournamentView.tournament.id,
      tournamentMatchId: groupMatch.id,
      scoreHome: 3,
      scoreAway: 0,
    );

    // 4. Verify Finals Assignment
    var view = await service.getTournament(tournamentView.tournament.id);
    final finalMatch =
        view.matches.firstWhere((m) => m.stage == TournamentStage.finalStage);
    expect(finalMatch.homeTeamIndex, isNot(-1),
        reason: "Finals home team not assigned");
    expect(finalMatch.awayTeamIndex, isNot(-1),
        reason: "Finals away team not assigned");

    // 5. Attempt to Record Finals Result (Reported Bug: Cannot save?)
    try {
      await service.recordTournamentMatchResult(
        tournamentId: tournamentView.tournament.id,
        tournamentMatchId: finalMatch.id,
        scoreHome: 1,
        scoreAway: 2,
      );
      print("Finals match saved successfully");
    } catch (e) {
      fail("Failed to save finals match: $e");
    }

    // 6. Attempt to Delete Tournament (Reported Bug: Cannot delete?)
    // This method deleteTournamentIfNotStarted implies it fails if started.
    // Maybe the user WANTS to delete it even if started?
    // Or maybe it fails even if NOT started?
    // In this case, it HAS started (matches played).
    try {
      await service.deleteTournamentIfNotStarted(
          tournamentId: tournamentView.tournament.id);
      fail("Should have thrown StateError because tournament started");
    } catch (e) {
      print("Deletion correctly failed for started tournament: $e");
    }

    // Is there a "Force Delete" or "Delete Anyway" requirement?
    // If the user says "tournaments cannot be deleted", they likely mean they WANT to delete a messed up tournament.
  });
}

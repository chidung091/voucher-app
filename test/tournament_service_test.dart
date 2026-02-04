import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voucher_app/data/local_store.dart';
import 'package:voucher_app/domain/enums.dart';
import 'package:voucher_app/services/player_service.dart';
import 'package:voucher_app/services/tournament_service.dart';

void main() {
  test('Tournament progresses to final after group matches', () async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();

    final playerService = await PlayerService.create();
    final p1 = await playerService.createPlayer('A');
    final p2 = await playerService.createPlayer('B');
    final p3 = await playerService.createPlayer('C');

    final service = await TournamentService.create();
    final tournament = await service.createTournament(
      TournamentInput(
        name: 'Test Cup',
        mode: MatchMode.oneVOne,
        teams: [
          TournamentTeamInput(name: 'Team 1', playerIds: [p1.id]),
          TournamentTeamInput(name: 'Team 2', playerIds: [p2.id]),
          TournamentTeamInput(name: 'Team 3', playerIds: [p3.id]),
        ],
      ),
    );

    final groupMatches =
        tournament.matches.where((m) => m.stage == TournamentStage.group);
    final group = groupMatches.toList()
      ..sort((a, b) => a.scheduledOrder - b.scheduledOrder);

    await service.recordTournamentMatchResult(
      tournamentId: tournament.tournament.id,
      tournamentMatchId: group[0].id,
      scoreHome: 1,
      scoreAway: 0,
    );
    await service.recordTournamentMatchResult(
      tournamentId: tournament.tournament.id,
      tournamentMatchId: group[1].id,
      scoreHome: 0,
      scoreAway: 1,
    );
    final updated = await service.recordTournamentMatchResult(
      tournamentId: tournament.tournament.id,
      tournamentMatchId: group[2].id,
      scoreHome: 2,
      scoreAway: 1,
    );

    final finalMatch = updated.matches.firstWhere(
      (m) => m.stage == TournamentStage.finalStage,
    );

    expect(updated.tournament.status, TournamentStatus.finalStage);
    expect(finalMatch.homeTeamIndex, isNot(-1));
    expect(finalMatch.awayTeamIndex, isNot(-1));
  });

  test('Tournament completes without finals when disabled', () async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();

    final playerService = await PlayerService.create();
    final p1 = await playerService.createPlayer('A');
    final p2 = await playerService.createPlayer('B');
    final p3 = await playerService.createPlayer('C');

    final service = await TournamentService.create();
    final tournament = await service.createTournament(
      TournamentInput(
        name: 'No Finals',
        mode: MatchMode.oneVOne,
        finalsEnabled: false,
        teams: [
          TournamentTeamInput(name: 'Team 1', playerIds: [p1.id]),
          TournamentTeamInput(name: 'Team 2', playerIds: [p2.id]),
          TournamentTeamInput(name: 'Team 3', playerIds: [p3.id]),
        ],
      ),
    );

    final groupMatches =
        tournament.matches.where((m) => m.stage == TournamentStage.group);
    final group = groupMatches.toList()
      ..sort((a, b) => a.scheduledOrder - b.scheduledOrder);

    await service.recordTournamentMatchResult(
      tournamentId: tournament.tournament.id,
      tournamentMatchId: group[0].id,
      scoreHome: 1,
      scoreAway: 0,
    );
    await service.recordTournamentMatchResult(
      tournamentId: tournament.tournament.id,
      tournamentMatchId: group[1].id,
      scoreHome: 0,
      scoreAway: 1,
    );
    final updated = await service.recordTournamentMatchResult(
      tournamentId: tournament.tournament.id,
      tournamentMatchId: group[2].id,
      scoreHome: 2,
      scoreAway: 1,
    );

    expect(updated.tournament.status, TournamentStatus.completed);
    expect(updated.tournament.championTeamIndex, isNotNull);
  });

  test('Can disable finals after creation', () async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();

    final playerService = await PlayerService.create();
    final p1 = await playerService.createPlayer('A');
    final p2 = await playerService.createPlayer('B');
    final p3 = await playerService.createPlayer('C');

    final service = await TournamentService.create();
    final tournament = await service.createTournament(
      TournamentInput(
        name: 'Toggle Finals',
        mode: MatchMode.oneVOne,
        finalsEnabled: true,
        teams: [
          TournamentTeamInput(name: 'Team 1', playerIds: [p1.id]),
          TournamentTeamInput(name: 'Team 2', playerIds: [p2.id]),
          TournamentTeamInput(name: 'Team 3', playerIds: [p3.id]),
        ],
      ),
    );

    final updated = await service.setFinalsEnabled(
      tournamentId: tournament.tournament.id,
      enabled: false,
    );

    expect(updated.tournament.finalsEnabled, false);
  });
  test('Rankings are isolated between tournaments', () async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();

    final playerService = await PlayerService.create();
    final p1 = await playerService.createPlayer('Player 1');
    final p2 = await playerService.createPlayer('Player 2');
    final p3 = await playerService.createPlayer('Player 3');

    final service = await TournamentService.create();

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

    // Create Tournament B (Same players)
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

    // Tournament A: Team 0 wins everything
    final matchesA =
        viewA.matches.where((m) => m.stage == TournamentStage.group).toList();
    for (final match in matchesA) {
      if (match.homeTeamIndex == 0 || match.awayTeamIndex == 0) {
        // Team 0 wins
        await service.recordTournamentMatchResult(
          tournamentId: viewA.tournament.id,
          tournamentMatchId: match.id,
          scoreHome: match.homeTeamIndex == 0 ? 10 : 0,
          scoreAway: match.awayTeamIndex == 0 ? 10 : 0,
        );
      } else {
        // Others draw
        await service.recordTournamentMatchResult(
          tournamentId: viewA.tournament.id,
          tournamentMatchId: match.id,
          scoreHome: 0,
          scoreAway: 0,
        );
      }
    }

    final updatedA = await service.getTournament(viewA.tournament.id);
    expect(updatedA.tournament.championTeamIndex, 0);

    // Tournament B: Team 2 wins everything
    final matchesB =
        viewB.matches.where((m) => m.stage == TournamentStage.group).toList();
    for (final match in matchesB) {
      if (match.homeTeamIndex == 2 || match.awayTeamIndex == 2) {
        // Team 2 wins
        await service.recordTournamentMatchResult(
          tournamentId: viewB.tournament.id,
          tournamentMatchId: match.id,
          scoreHome: match.homeTeamIndex == 2 ? 10 : 0,
          scoreAway: match.awayTeamIndex == 2 ? 10 : 0,
        );
      } else {
        // Others draw
        await service.recordTournamentMatchResult(
          tournamentId: viewB.tournament.id,
          tournamentMatchId: match.id,
          scoreHome: 0,
          scoreAway: 0,
        );
      }
    }

    // Verify Tournament B results are not polluted by Tournament A
    final updatedB = await service.getTournament(viewB.tournament.id);
    expect(updatedB.tournament.championTeamIndex, 2,
        reason:
            'Team 2 should win Tournament B independent of Team 0 winning Tournament A');
  });
}

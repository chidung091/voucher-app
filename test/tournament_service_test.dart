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
    final group = groupMatches.toList()..sort((a, b) => a.scheduledOrder - b.scheduledOrder);

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
    final group = groupMatches.toList()..sort((a, b) => a.scheduledOrder - b.scheduledOrder);

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
}

import 'package:uuid/uuid.dart';

import '../data/local_store.dart';
import '../domain/enums.dart';
import '../domain/match.dart';
import '../domain/tournament.dart';
import '../domain/tournament_match.dart';
import '../domain/tournament_standings.dart';
import '../domain/tournament_team.dart';
import 'match_service.dart';
import 'team_balancer.dart';

class TournamentInput {
  TournamentInput({
    required this.name,
    required this.mode,
    required this.teams,
    this.finalsEnabled = true,
  });

  final String name;
  final MatchMode mode;
  final List<TournamentTeamInput> teams;
  final bool finalsEnabled;
}

class TournamentTeamInput {
  TournamentTeamInput({
    required this.name,
    required this.playerIds,
  });

  final String name;
  final List<String> playerIds;
}

class TournamentView {
  TournamentView({
    required this.tournament,
    required this.teams,
    required this.matches,
    required this.standings,
  });

  final Tournament tournament;
  final List<TournamentTeam> teams;
  final List<TournamentMatch> matches;
  final List<TournamentStanding> standings;
}

class TournamentService {
  TournamentService(this._store, this._uuid, this._matchService);

  final LocalStore _store;
  final Uuid _uuid;
  final MatchService _matchService;

  static Future<TournamentService> create() async {
    return TournamentService(
      await LocalStore.getInstance(),
      const Uuid(),
      await MatchService.create(),
    );
  }

  Future<TournamentView> createTournament(TournamentInput input) {
    _validateTournament(input);
    return _store.writeTransaction(() async {
      final now = DateTime.now();
      final tournament = Tournament(
        id: _uuid.v4(),
        name: input.name.trim(),
        mode: input.mode,
        status: TournamentStatus.group,
        createdAt: now,
        updatedAt: now,
        finalsEnabled: input.finalsEnabled,
      );

      final teams = List.generate(3, (index) {
        final inputTeam = input.teams[index];
        return TournamentTeam(
          id: _uuid.v4(),
          tournamentId: tournament.id,
          teamIndex: index,
          name: inputTeam.name,
          playerIds: inputTeam.playerIds,
        );
      });

      final matches = [
        TournamentMatch(
          id: _uuid.v4(),
          tournamentId: tournament.id,
          stage: TournamentStage.group,
          homeTeamIndex: 0,
          awayTeamIndex: 1,
          scheduledOrder: 1,
          status: TournamentMatchStatus.scheduled,
        ),
        TournamentMatch(
          id: _uuid.v4(),
          tournamentId: tournament.id,
          stage: TournamentStage.group,
          homeTeamIndex: 0,
          awayTeamIndex: 2,
          scheduledOrder: 2,
          status: TournamentMatchStatus.scheduled,
        ),
        TournamentMatch(
          id: _uuid.v4(),
          tournamentId: tournament.id,
          stage: TournamentStage.group,
          homeTeamIndex: 1,
          awayTeamIndex: 2,
          scheduledOrder: 3,
          status: TournamentMatchStatus.scheduled,
        ),
      ];
      if (tournament.finalsEnabled) {
        matches.add(
          TournamentMatch(
            id: _uuid.v4(),
            tournamentId: tournament.id,
            stage: TournamentStage.finalStage,
            homeTeamIndex: -1,
            awayTeamIndex: -1,
            scheduledOrder: 4,
            status: TournamentMatchStatus.scheduled,
          ),
        );
      }

      final tournaments = await _store.getTournaments();
      final teamsList = await _store.getTournamentTeams();
      final matchesList = await _store.getTournamentMatches();

      tournaments.add(tournament);
      teamsList.addAll(teams);
      matchesList.addAll(matches);

      await _store.saveTournaments(tournaments);
      await _store.saveTournamentTeams(teamsList);
      await _store.saveTournamentMatches(matchesList);

      return await getTournament(tournament.id);
    });
  }

  Future<TournamentView> createTournamentAutoBalanced({
    required String name,
    required MatchMode mode,
    required List<String> playerIdsPool,
    bool finalsEnabled = true,
  }) async {
    if (playerIdsPool.isEmpty) {
      throw ArgumentError('Player pool is required.');
    }
    final players = await _store.getPlayers();
    final ratings = await _store.getRatings();
    final pool = players
        .where((player) => playerIdsPool.contains(player.id))
        .toList();
    final entries = TeamBalancer.buildPool(pool, ratings);
    final balancer = TeamBalancer();
    final result = mode == MatchMode.oneVOne
        ? balancer.balanceFor1v1(entries)
        : balancer.balanceFor2v2(entries);

    final teams = List.generate(3, (index) {
      final members = result.teams[index]
          .map((entry) => entry.player.id)
          .toList();
      return TournamentTeamInput(
        name: 'Team ${index + 1}',
        playerIds: members,
      );
    });

    return createTournament(
      TournamentInput(
        name: name,
        mode: mode,
        teams: teams,
        finalsEnabled: finalsEnabled,
      ),
    );
  }

  Future<List<Tournament>> listTournaments() async {
    return _store.getTournaments();
  }

  Future<TournamentView> getTournament(String id) async {
    final tournaments = await _store.getTournaments();
    final tournament = tournaments.firstWhere(
      (item) => item.id == id,
      orElse: () => throw StateError('Tournament not found'),
    );
    final teams = (await _store.getTournamentTeams())
        .where((team) => team.tournamentId == id)
        .toList()
      ..sort((a, b) => a.teamIndex.compareTo(b.teamIndex));
    final matches = (await _store.getTournamentMatches())
        .where((match) => match.tournamentId == id)
        .toList()
      ..sort((a, b) => a.scheduledOrder.compareTo(b.scheduledOrder));
    final history = await _store.getMatches();
    final standings = TournamentStandingsCalculator().compute(
      teams: teams,
      matches: matches,
      matchHistory: history,
    );
    return TournamentView(
      tournament: tournament,
      teams: teams,
      matches: matches,
      standings: standings,
    );
  }

  Future<TournamentView> recordTournamentMatchResult({
    required String tournamentId,
    required String tournamentMatchId,
    required int scoreHome,
    required int scoreAway,
    DateTime? playedAt,
    bool forfeit = false,
  }) {
    return _store.writeTransaction(() async {
      final tournaments = await _store.getTournaments();
      final tournamentIndex =
          tournaments.indexWhere((item) => item.id == tournamentId);
      if (tournamentIndex == -1) {
        throw StateError('Tournament not found');
      }
      final tournament = tournaments[tournamentIndex];

      final teams = await _store.getTournamentTeams();
      final tournamentTeams = teams
          .where((team) => team.tournamentId == tournamentId)
          .toList();
      final matches = await _store.getTournamentMatches();
      final matchIndex =
          matches.indexWhere((item) => item.id == tournamentMatchId);
      if (matchIndex == -1) {
        throw StateError('Tournament match not found');
      }
      final tournamentMatch = matches[matchIndex];

      if (tournamentMatch.stage == TournamentStage.finalStage &&
          scoreHome == scoreAway &&
          !forfeit) {
        throw ArgumentError('Final match cannot end in a draw.');
      }
      if (tournamentMatch.homeTeamIndex < 0 ||
          tournamentMatch.awayTeamIndex < 0) {
        throw StateError('Final teams are not decided yet.');
      }

      final homeTeam = tournamentTeams.firstWhere(
        (team) => team.teamIndex == tournamentMatch.homeTeamIndex,
        orElse: () => throw StateError('Home team not found'),
      );
      final awayTeam = tournamentTeams.firstWhere(
        (team) => team.teamIndex == tournamentMatch.awayTeamIndex,
        orElse: () => throw StateError('Away team not found'),
      );

      final matchInput = MatchInput(
        mode: tournament.mode,
        sideAPlayerIds: homeTeam.playerIds,
        sideBPlayerIds: awayTeam.playerIds,
        scoreA: scoreHome,
        scoreB: scoreAway,
        playedAt: playedAt ?? DateTime.now(),
        idempotencyKey: 'tournament-$tournamentId-$tournamentMatchId',
        tournamentId: tournamentId,
        tournamentMatchId: tournamentMatchId,
        metadata: forfeit ? {'forfeit': true} : null,
      );

      final storeMatches = await _store.getMatches();
      final storeRatings = await _store.getRatings();
      final storeEvents = await _store.getRatingEvents();
      final result = _matchService.createMatchFromData(
        input: matchInput,
        matches: storeMatches,
        ratings: storeRatings,
        events: storeEvents,
      );
      await _store.saveMatches(storeMatches);
      await _store.saveRatings(storeRatings);
      await _store.saveRatingEvents(storeEvents);

      matches[matchIndex] = tournamentMatch.copyWith(
        matchId: result.match.id,
        status: TournamentMatchStatus.done,
      );

      final groupMatchesDone = matches.where((item) {
        return item.tournamentId == tournamentId &&
            item.stage == TournamentStage.group &&
            item.status == TournamentMatchStatus.done;
      }).length;

      Tournament updatedTournament = tournament;
      if (groupMatchesDone == 3 && tournament.status == TournamentStatus.group) {
        final standings = TournamentStandingsCalculator().compute(
          teams: tournamentTeams,
          matches: matches,
          matchHistory: storeMatches,
        );
        if (tournament.finalsEnabled) {
          final topTwo = standings.take(2).toList();
          if (topTwo.length == 2) {
            final finalIndex = matches.indexWhere(
              (item) =>
                  item.tournamentId == tournamentId &&
                  item.stage == TournamentStage.finalStage,
            );
            matches[finalIndex] = matches[finalIndex].copyWith(
              homeTeamIndex: topTwo[0].teamIndex,
              awayTeamIndex: topTwo[1].teamIndex,
            );
            updatedTournament = updatedTournament.copyWith(
              status: TournamentStatus.finalStage,
              updatedAt: DateTime.now(),
            );
          }
        } else {
          updatedTournament = updatedTournament.copyWith(
            status: TournamentStatus.completed,
            championTeamIndex: standings.first.teamIndex,
            updatedAt: DateTime.now(),
          );
        }
      }

      if (tournamentMatch.stage == TournamentStage.finalStage) {
        final winnerIndex =
            scoreHome > scoreAway ? homeTeam.teamIndex : awayTeam.teamIndex;
        updatedTournament = updatedTournament.copyWith(
          status: TournamentStatus.completed,
          championTeamIndex: winnerIndex,
          updatedAt: DateTime.now(),
        );
      }

      tournaments[tournamentIndex] = updatedTournament;
      await _store.saveTournamentMatches(matches);
      await _store.saveTournaments(tournaments);

      return await getTournament(tournamentId);
    });
  }

  Future<TournamentView> setFinalsEnabled({
    required String tournamentId,
    required bool enabled,
  }) {
    return _store.writeTransaction(() async {
      final tournaments = await _store.getTournaments();
      final index =
          tournaments.indexWhere((tournament) => tournament.id == tournamentId);
      if (index == -1) {
        throw StateError('Tournament not found');
      }
      final tournament = tournaments[index];
      if (tournament.status == TournamentStatus.completed) {
        throw StateError('Cannot change finals after completion.');
      }

      final matches = await _store.getTournamentMatches();
      final tournamentMatches =
          matches.where((m) => m.tournamentId == tournamentId).toList();
      final storeMatches = await _store.getMatches();
      final teams = (await _store.getTournamentTeams())
          .where((team) => team.tournamentId == tournamentId)
          .toList();

      if (!enabled) {
        matches.removeWhere((m) =>
            m.tournamentId == tournamentId &&
            m.stage == TournamentStage.finalStage);
      } else {
        final hasFinal = tournamentMatches.any(
          (m) => m.stage == TournamentStage.finalStage,
        );
        if (!hasFinal) {
          matches.add(
            TournamentMatch(
              id: _uuid.v4(),
              tournamentId: tournamentId,
              stage: TournamentStage.finalStage,
              homeTeamIndex: -1,
              awayTeamIndex: -1,
              scheduledOrder: 4,
              status: TournamentMatchStatus.scheduled,
            ),
          );
        }
      }

      Tournament updated = tournament.copyWith(
        finalsEnabled: enabled,
        updatedAt: DateTime.now(),
      );

      final groupMatchesDone = tournamentMatches.where((item) {
        return item.stage == TournamentStage.group &&
            item.status == TournamentMatchStatus.done;
      }).length;

      if (groupMatchesDone == 3) {
        final standings = TournamentStandingsCalculator().compute(
          teams: teams,
          matches: matches
              .where((m) => m.tournamentId == tournamentId)
              .toList(),
          matchHistory: storeMatches,
        );
        if (enabled) {
          final finalIndex = matches.indexWhere(
            (m) =>
                m.tournamentId == tournamentId &&
                m.stage == TournamentStage.finalStage,
          );
          if (finalIndex != -1) {
            matches[finalIndex] = matches[finalIndex].copyWith(
              homeTeamIndex: standings[0].teamIndex,
              awayTeamIndex: standings[1].teamIndex,
            );
            updated = updated.copyWith(
              status: TournamentStatus.finalStage,
              championTeamIndex: null,
            );
          }
        } else {
          updated = updated.copyWith(
            status: TournamentStatus.completed,
            championTeamIndex: standings.first.teamIndex,
          );
        }
      }

      tournaments[index] = updated;
      await _store.saveTournamentMatches(matches);
      await _store.saveTournaments(tournaments);

      return getTournament(tournamentId);
    });
  }

  Future<TournamentView> recordFinalForfeit({
    required String tournamentId,
    required String tournamentMatchId,
    required int winnerTeamIndex,
  }) async {
    final view = await getTournament(tournamentId);
    final tournamentMatch = view.matches.firstWhere(
      (match) => match.id == tournamentMatchId,
      orElse: () => throw StateError('Tournament match not found'),
    );
    final scoreHome = tournamentMatch.homeTeamIndex == winnerTeamIndex ? 1 : 0;
    final scoreAway = tournamentMatch.awayTeamIndex == winnerTeamIndex ? 1 : 0;
    return recordTournamentMatchResult(
      tournamentId: tournamentId,
      tournamentMatchId: tournamentMatchId,
      scoreHome: scoreHome,
      scoreAway: scoreAway,
      forfeit: true,
    );
  }

  void _validateTournament(TournamentInput input) {
    if (input.name.trim().isEmpty) {
      throw ArgumentError('Tournament name is required');
    }
    if (input.teams.length != 3) {
      throw ArgumentError('Tournament requires exactly 3 teams');
    }
    final expectedSize = input.mode == MatchMode.oneVOne ? 1 : 2;
    for (final team in input.teams) {
      if (team.playerIds.length != expectedSize) {
        throw ArgumentError('Team size does not match tournament mode');
      }
    }
  }
}

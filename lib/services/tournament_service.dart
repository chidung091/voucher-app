import 'package:uuid/uuid.dart';

import '../data/local_store.dart';
import '../domain/elo_calculator.dart';
import '../domain/enums.dart';
import '../domain/match.dart';
import '../domain/tournament.dart';
import '../domain/tournament_match.dart';
import '../domain/tournament_standings.dart';
import '../domain/tournament_team.dart';
import 'club_assignment_service.dart';
import 'head_to_head_service.dart';
import 'match_service.dart';
import 'player_stats_service.dart';
import 'season_service.dart';
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

      final teams = List.generate(input.teams.length, (index) {
        final inputTeam = input.teams[index];
        return TournamentTeam(
          id: _uuid.v4(),
          tournamentId: tournament.id,
          teamIndex: index,
          name: inputTeam.name,
          playerIds: inputTeam.playerIds,
        );
      });

      final matches = _buildGroupMatches(
        tournamentId: tournament.id,
        teamCount: teams.length,
      );
      if (tournament.finalsEnabled) {
        final order = matches.length + 1;
        matches.add(
          TournamentMatch(
            id: _uuid.v4(),
            tournamentId: tournament.id,
            stage: TournamentStage.finalStage,
            homeTeamIndex: -1,
            awayTeamIndex: -1,
            scheduledOrder: order,
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
      await ClubAssignmentService(_store).assignForTournamentSchedule(
        tournamentId: tournament.id,
      );

      return await getTournament(tournament.id);
    });
  }

  Future<TournamentView> createTournamentAutoBalanced({
    required String name,
    required MatchMode mode,
    required List<String> playerIdsPool,
    bool finalsEnabled = true,
    String? forceSoloPlayerId,
  }) async {
    if (playerIdsPool.isEmpty) {
      throw ArgumentError('Player pool is required.');
    }
    final players = await _store.getPlayers();
    final ratings = await _store.getRatings();
    final pool =
        players.where((player) => playerIdsPool.contains(player.id)).toList();
    final entries = TeamBalancer.buildPool(pool, ratings);
    final balancer = TeamBalancer();
    final result = mode == MatchMode.oneVOne
        ? balancer.balanceFor1v1(entries)
        : balancer.balanceFor2v2(entries, forceSoloPlayerId: forceSoloPlayerId);

    final teams = List.generate(result.teams.length, (index) {
      final members =
          result.teams[index].map((entry) => entry.player.id).toList();
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
    MatchRatingMode? ratingMode,
    double? eloMultiplier,
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
      final tournamentTeams =
          teams.where((team) => team.tournamentId == tournamentId).toList();
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
        ratingMode: ratingMode ?? MatchRatingMode.tournament,
        eloMultiplier: eloMultiplier ??
            (ratingMode ?? MatchRatingMode.tournament).defaultMultiplier(),
        metadata: _buildMatchMetadata(
          tournamentMatch: tournamentMatch,
          forfeit: forfeit,
        ),
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
      final statsService = PlayerStatsService(_store, EloCalculator());
      await statsService.invalidatePlayerStatsCacheForMatch(result.match);
      await HeadToHeadService(_store).invalidateH2HCacheForMatch(result.match);
      await SeasonService(_store, EloCalculator())
          .invalidateSeasonCacheForMatch(result.match);

      matches[matchIndex] = tournamentMatch.copyWith(
        matchId: result.match.id,
        status: TournamentMatchStatus.done,
      );

      final groupMatchesDone = matches.where((item) {
        return item.tournamentId == tournamentId &&
            item.stage == TournamentStage.group &&
            item.status == TournamentMatchStatus.done;
      }).length;
      final groupMatchesTotal = matches.where((item) {
        return item.tournamentId == tournamentId &&
            item.stage == TournamentStage.group;
      }).length;

      Tournament updatedTournament = tournament;
      String? finalMatchToAssign;
      if (groupMatchesDone == groupMatchesTotal &&
          tournament.status == TournamentStatus.group) {
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
              homeAssignedStars: null,
              awayAssignedStars: null,
              homeClubId: null,
              awayClubId: null,
              clubAssignmentMode: ClubAssignmentMode.auto,
            );
            finalMatchToAssign = matches[finalIndex].id;
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
      if (finalMatchToAssign != null) {
        await ClubAssignmentService(_store).assignForTournamentSchedule(
          tournamentId: tournamentId,
          matchIds: {finalMatchToAssign!},
        );
      }

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
          final order = matches
                  .where((m) =>
                      m.tournamentId == tournamentId &&
                      m.stage == TournamentStage.group)
                  .length +
              1;
          matches.add(
            TournamentMatch(
              id: _uuid.v4(),
              tournamentId: tournamentId,
              stage: TournamentStage.finalStage,
              homeTeamIndex: -1,
              awayTeamIndex: -1,
              scheduledOrder: order,
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
      final groupMatchesTotal = tournamentMatches.where((item) {
        return item.stage == TournamentStage.group;
      }).length;

      if (groupMatchesDone == groupMatchesTotal) {
        final standings = TournamentStandingsCalculator().compute(
          teams: teams,
          matches:
              matches.where((m) => m.tournamentId == tournamentId).toList(),
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
      await ClubAssignmentService(_store).assignForTournamentSchedule(
        tournamentId: tournamentId,
        matchIds: {
          for (final match in matches)
            if (match.tournamentId == tournamentId &&
                match.stage == TournamentStage.finalStage &&
                match.homeTeamIndex >= 0 &&
                match.awayTeamIndex >= 0)
              match.id,
        },
      );

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

  Future<TournamentView> resetTournamentResults({
    required String tournamentId,
  }) {
    return _store.writeTransaction(() async {
      final tournaments = await _store.getTournaments();
      final index =
          tournaments.indexWhere((tournament) => tournament.id == tournamentId);
      if (index == -1) {
        throw StateError('Tournament not found');
      }
      final tournament = tournaments[index];
      final tournamentTeams = (await _store.getTournamentTeams())
          .where((team) => team.tournamentId == tournamentId)
          .toList();
      final tournamentMatches = await _store.getTournamentMatches();
      final matches = await _store.getMatches();
      final players = await _store.getPlayers();

      final idsToRemove = tournamentMatches
          .where((match) => match.tournamentId == tournamentId)
          .map((match) => match.matchId)
          .whereType<String>()
          .toSet();

      final filteredMatches =
          matches.where((match) => !idsToRemove.contains(match.id)).toList();
      final updatedTournamentMatches = tournamentMatches.map((match) {
        if (match.tournamentId != tournamentId) return match;
        if (match.stage == TournamentStage.finalStage &&
            tournament.finalsEnabled) {
          return match.copyWith(
            matchId: null,
            status: TournamentMatchStatus.scheduled,
            homeTeamIndex: -1,
            awayTeamIndex: -1,
            homeAssignedStars: null,
            awayAssignedStars: null,
            homeClubId: null,
            awayClubId: null,
            clubAssignmentMode: ClubAssignmentMode.auto,
          );
        }
        return match.copyWith(
          matchId: null,
          status: TournamentMatchStatus.scheduled,
        );
      }).toList();

      final updatedTournament = tournament.copyWith(
        status: TournamentStatus.group,
        championTeamIndex: null,
        updatedAt: DateTime.now(),
      );
      tournaments[index] = updatedTournament;

      final rebuild = _matchService.rebuildRatingsAndEvents(
        filteredMatches,
        players,
      );

      await _store.saveMatches(filteredMatches);
      await _store.saveRatingEvents(rebuild.events);
      await _store.saveRatings(rebuild.ratings);
      await _store.saveTournamentMatches(updatedTournamentMatches);
      await _store.saveTournaments(tournaments);
      await PlayerStatsService(_store, EloCalculator())
          .invalidateAllStatsCache();
      await HeadToHeadService(_store).invalidateAllH2HCache();
      await SeasonService(_store, EloCalculator()).invalidateAllSeasonCache();

      return TournamentView(
        tournament: updatedTournament,
        teams: tournamentTeams,
        matches: updatedTournamentMatches
            .where((match) => match.tournamentId == tournamentId)
            .toList(),
        standings: TournamentStandingsCalculator().compute(
          teams: tournamentTeams,
          matches: updatedTournamentMatches
              .where((match) => match.tournamentId == tournamentId)
              .toList(),
          matchHistory: filteredMatches,
        ),
      );
    });
  }

  Future<void> autoAssignClubs({
    required String tournamentId,
    bool force = false,
    Set<String>? matchIds,
  }) async {
    await ClubAssignmentService(_store).assignForTournamentSchedule(
      tournamentId: tournamentId,
      force: force,
      matchIds: matchIds,
    );
  }

  Future<void> updateTournamentMatchClubAssignment({
    required String tournamentId,
    required String matchId,
    required ClubAssignmentMode mode,
    String? homeClubId,
    String? awayClubId,
    double? homeStars,
    double? awayStars,
  }) async {
    await _store.writeTransaction(() async {
      final matches = await _store.getTournamentMatches();
      final index = matches.indexWhere(
        (match) => match.id == matchId && match.tournamentId == tournamentId,
      );
      if (index == -1) {
        throw StateError('Tournament match not found');
      }
      matches[index] = matches[index].copyWith(
        clubAssignmentMode: mode,
        homeClubId: homeClubId,
        awayClubId: awayClubId,
        homeAssignedStars: homeStars,
        awayAssignedStars: awayStars,
      );
      await _store.saveTournamentMatches(matches);
    });
  }

  Map<String, dynamic>? _buildMatchMetadata({
    required TournamentMatch tournamentMatch,
    required bool forfeit,
  }) {
    final metadata = <String, dynamic>{};
    if (forfeit) {
      metadata['forfeit'] = true;
    }
    if (tournamentMatch.homeClubId != null) {
      metadata['homeClubId'] = tournamentMatch.homeClubId;
    }
    if (tournamentMatch.awayClubId != null) {
      metadata['awayClubId'] = tournamentMatch.awayClubId;
    }
    if (tournamentMatch.homeAssignedStars != null) {
      metadata['homeStars'] = tournamentMatch.homeAssignedStars;
    }
    if (tournamentMatch.awayAssignedStars != null) {
      metadata['awayStars'] = tournamentMatch.awayAssignedStars;
    }
    if (metadata.isEmpty) {
      return null;
    }
    return metadata;
  }

  Future<void> deleteTournamentIfNotStarted({
    required String tournamentId,
  }) async {
    final matches = await _store.getTournamentMatches();
    final hasStarted = matches.any((m) =>
        m.tournamentId == tournamentId &&
        m.status == TournamentMatchStatus.done);

    if (hasStarted) {
      throw StateError('Tournament has already started.');
    }

    await deleteTournament(tournamentId: tournamentId);
  }

  Future<void> deleteTournament({
    required String tournamentId,
  }) {
    return _store.writeTransaction(() async {
      final tournaments = await _store.getTournaments();
      final index =
          tournaments.indexWhere((tournament) => tournament.id == tournamentId);
      if (index == -1) {
        throw StateError('Tournament not found');
      }

      // 1. Identify match IDs to remove (history)
      final allMatches = await _store.getMatches();
      final tournamentMatchIds = allMatches
          .where((m) => m.tournamentId == tournamentId)
          .map((m) => m.id)
          .toSet();

      final remainingMatches =
          allMatches.where((m) => !tournamentMatchIds.contains(m.id)).toList();

      // 2. Remove Tournament Data
      tournaments.removeAt(index);
      final teams = await _store.getTournamentTeams();
      teams.removeWhere((team) => team.tournamentId == tournamentId);
      final tournamentMatches = await _store.getTournamentMatches();
      tournamentMatches
          .removeWhere((match) => match.tournamentId == tournamentId);

      // 3. Rebuild Elo if needed
      if (tournamentMatchIds.isNotEmpty) {
        final players = await _store.getPlayers();
        final rebuild = _matchService.rebuildRatingsAndEvents(
          remainingMatches,
          players,
        );
        await _store.saveRatings(rebuild.ratings);
        await _store.saveRatingEvents(rebuild.events);

        // Invalidate caches
        await PlayerStatsService(_store, EloCalculator())
            .invalidateAllStatsCache();
        await HeadToHeadService(_store).invalidateAllH2HCache();
        await SeasonService(_store, EloCalculator()).invalidateAllSeasonCache();
      }

      // 4. Save Changes
      await _store.saveMatches(remainingMatches);
      await _store.saveTournaments(tournaments);
      await _store.saveTournamentTeams(teams);
      await _store.saveTournamentMatches(tournamentMatches);
    });
  }

  void _validateTournament(TournamentInput input) {
    if (input.name.trim().isEmpty) {
      throw ArgumentError('Tournament name is required');
    }
    if (input.teams.length < 2) {
      throw ArgumentError('Tournament requires at least 2 teams');
    }
    for (final team in input.teams) {
      if (team.playerIds.isEmpty || team.playerIds.length > 2) {
        throw ArgumentError('Teams must have 1 or 2 players');
      }
      if (input.mode == MatchMode.oneVOne && team.playerIds.length != 1) {
        throw ArgumentError('1V1 tournament requires solo teams');
      }
    }
  }

  List<TournamentMatch> _buildGroupMatches({
    required String tournamentId,
    required int teamCount,
  }) {
    final matches = <TournamentMatch>[];
    var order = 1;
    for (var i = 0; i < teamCount; i++) {
      for (var j = i + 1; j < teamCount; j++) {
        matches.add(
          TournamentMatch(
            id: _uuid.v4(),
            tournamentId: tournamentId,
            stage: TournamentStage.group,
            homeTeamIndex: i,
            awayTeamIndex: j,
            scheduledOrder: order,
            status: TournamentMatchStatus.scheduled,
          ),
        );
        order += 1;
      }
    }
    return matches;
  }
}

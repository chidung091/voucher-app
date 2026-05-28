import 'dart:math';

import '../data/local_store.dart';
import '../domain/club.dart';
import '../domain/enums.dart';
import 'team_elo_calculator.dart';

class MatchupStars {
  MatchupStars({required this.strongStars, required this.weakStars});

  final double strongStars;
  final double weakStars;
}

class ClubAssignmentService {
  ClubAssignmentService(this._store);

  final LocalStore _store;

  static const double maxStar = 5.0;
  static const double step = 0.5;

  static double roundToStep(double value, double step) {
    return (value / step).round() * step;
  }

  static double baseStars({required int rank, required int teamCount}) {
    final minStar = max(1.0, maxStar - step * (teamCount - 1));
    return minStar + step * (rank - 1);
  }

  static MatchupStars matchupStars({
    required int rankStrong,
    required int rankWeak,
    required int teamCount,
    required int teamSizeStrong,
    required int teamSizeWeak,
    int? eloDiff,
  }) {
    final strongBase = baseStars(rank: rankStrong, teamCount: teamCount);
    final weakBase = baseStars(rank: rankWeak, teamCount: teamCount);
    final baseline = roundToStep((strongBase + weakBase) / 2, step);

    // Preserve an even matchup only for teams with the same effective Elo.
    // Any measured gap receives at least one available club-star step.
    if (eloDiff != null && eloDiff == 0) {
      final equalStars =
          roundToStep(baseline, step).clamp(1.0, maxStar).toDouble();
      return MatchupStars(strongStars: equalStars, weakStars: equalStars);
    }

    // Dynamic spread based on Elo difference only (no solo handicap)
    // An unspecified or small non-zero gap requests one 0.5 star distinction.
    double spread = step / 2;
    if (eloDiff != null) {
      final absoluteDiff = eloDiff.abs();
      final calculated = absoluteDiff / 200.0;
      // At 50 Elo and above, retain at least a full one-star rounded gap.
      spread = absoluteDiff >= 50
          ? max(step, calculated)
          : max(step / 2, calculated);
    }

    final strongRaw = baseline - spread;
    final weakRaw = baseline + spread;

    var strong = roundToStep(strongRaw, step).clamp(1.0, maxStar).toDouble();
    var weak = roundToStep(weakRaw, step).clamp(1.0, maxStar).toDouble();

    // Rounding at the 5-star ceiling can erase a legitimate small handicap.
    // Keep the weaker side higher; reduce the strong side if the weak side is capped.
    if (strong >= weak) {
      if (weak == maxStar) {
        strong = (weak - step).clamp(1.0, maxStar).toDouble();
      } else {
        weak = (strong + step).clamp(1.0, maxStar).toDouble();
      }
    }

    return MatchupStars(strongStars: strong, weakStars: weak);
  }

  static Club? pickClubForStars({
    required double requiredStars,
    required List<Club> clubs,
    String? excludeId,
    Random? random,
  }) {
    if (clubs.isEmpty) return null;
    final active = clubs.where((club) => club.deletedAt == null).toList();
    if (active.isEmpty) return null;

    List<Club> candidates =
        active.where((club) => club.stars == requiredStars).toList();
    if (candidates.isEmpty) {
      candidates = active
          .where((club) => (club.stars - requiredStars).abs() <= step)
          .toList();
    }
    if (candidates.isEmpty) {
      candidates = List<Club>.from(active);
    }
    // Sort for stability before shuffle, ensuring consistent behavior with seeded random
    candidates.sort((a, b) => a.id.compareTo(b.id));

    // Shuffle to pick a random club among candidates
    candidates.shuffle(random);

    if (excludeId != null && candidates.length > 1) {
      final filtered =
          candidates.where((club) => club.id != excludeId).toList();
      if (filtered.isNotEmpty) {
        return filtered.first;
      }
    }
    return candidates.first;
  }

  Future<void> assignForTournamentSchedule({
    required String tournamentId,
    bool force = false,
    Set<String>? matchIds,
  }) async {
    final tournaments = await _store.getTournaments();
    tournaments.firstWhere(
      (item) => item.id == tournamentId,
      orElse: () => throw StateError('Tournament not found'),
    );
    final teams = (await _store.getTournamentTeams())
        .where((team) => team.tournamentId == tournamentId)
        .toList();
    final matches = await _store.getTournamentMatches();
    final tournamentMatches =
        matches.where((match) => match.tournamentId == tournamentId).toList();

    if (teams.isEmpty || tournamentMatches.isEmpty) {
      return;
    }

    final players = await _store.getPlayers();
    final ratings = await _store.getRatings();
    final clubs = await _store.getClubs();

    final teamEloCalculator = TeamEloCalculator();
    final teamSnapshots = teamEloCalculator.computeTournamentTeamElos(
      teams: teams,
      players: players,
      ratings: ratings,
    );
    final ranks = teamEloCalculator.computeTeamRanks(teamSnapshots);
    final teamCount = teams.length;
    final random = Random();

    var updated = false;
    for (final match in tournamentMatches) {
      if (matchIds != null && !matchIds.contains(match.id)) {
        continue;
      }
      if (match.homeTeamIndex < 0 || match.awayTeamIndex < 0) {
        continue;
      }
      if (match.clubAssignmentMode == ClubAssignmentMode.manual) {
        continue;
      }
      final hasAssignment =
          match.homeAssignedStars != null && match.awayAssignedStars != null;
      if (!force && hasAssignment) {
        continue;
      }

      final homeRank = ranks[match.homeTeamIndex];
      final awayRank = ranks[match.awayTeamIndex];
      if (homeRank == null || awayRank == null) {
        continue;
      }

      final homeSnapshot = teamSnapshots[match.homeTeamIndex];
      final awaySnapshot = teamSnapshots[match.awayTeamIndex];
      if (homeSnapshot == null || awaySnapshot == null) {
        continue;
      }

      final strongIsHome = homeRank < awayRank ||
          (homeRank == awayRank &&
              homeSnapshot.effectiveElo >= awaySnapshot.effectiveElo);

      final eloDiff =
          (homeSnapshot.effectiveElo - awaySnapshot.effectiveElo).abs().round();

      final stars = matchupStars(
        rankStrong: min(homeRank, awayRank),
        rankWeak: max(homeRank, awayRank),
        teamCount: teamCount,
        teamSizeStrong:
            strongIsHome ? homeSnapshot.teamSize : awaySnapshot.teamSize,
        teamSizeWeak:
            strongIsHome ? awaySnapshot.teamSize : homeSnapshot.teamSize,
        eloDiff: eloDiff,
      );
      final homeStars = strongIsHome ? stars.strongStars : stars.weakStars;
      final awayStars = strongIsHome ? stars.weakStars : stars.strongStars;

      final homeClub = pickClubForStars(
        requiredStars: homeStars,
        clubs: clubs,
        random: random,
      );
      final awayClub = pickClubForStars(
        requiredStars: awayStars,
        clubs: clubs,
        excludeId: homeClub?.id,
        random: random,
      );

      final updatedMatch = match.copyWith(
        clubAssignmentMode: ClubAssignmentMode.auto,
        homeAssignedStars: homeStars,
        awayAssignedStars: awayStars,
        homeClubId: homeClub?.id,
        awayClubId: awayClub?.id,
      );
      final index = matches.indexWhere((item) => item.id == match.id);
      if (index != -1) {
        matches[index] = updatedMatch;
        updated = true;
      }
    }

    if (updated) {
      await _store.saveTournamentMatches(matches);
    }
  }
}

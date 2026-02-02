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

    // When ELO difference is very small (<50), both teams get equal stars
    // This handles the case where teams have similar strength
    final isCloseMatch = eloDiff != null && eloDiff.abs() < 50;

    if (isCloseMatch) {
      // Both teams get baseline stars (equal match)
      final equalStars =
          roundToStep(baseline, step).clamp(1.0, maxStar).toDouble();
      return MatchupStars(strongStars: equalStars, weakStars: equalStars);
    }

    // Dynamic spread based on Elo difference only (no solo handicap)
    // If undefined or small (<60), use 0.25 (total 0.5 gap).
    // If larger, scale up: ~100 elo -> 0.5 spread (total 1.0 gap).
    double spread = 0.25;
    if (eloDiff != null) {
      // 1 full star gap (0.5 spread) per 100 elo
      final calculated = (eloDiff.abs() / 200.0);
      // Ensure at least 0.25 spread (0.5 gap) to differentiate ranks
      spread = max(0.25, calculated);
    }

    final strongRaw = baseline - spread;
    final weakRaw = baseline + spread;

    final strong = roundToStep(strongRaw, step).clamp(1.0, maxStar).toDouble();
    final weak = roundToStep(weakRaw, step).clamp(1.0, maxStar).toDouble();

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

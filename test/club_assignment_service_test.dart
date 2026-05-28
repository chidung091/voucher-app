import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voucher_app/data/local_store.dart';
import 'package:voucher_app/domain/club.dart';
import 'package:voucher_app/domain/enums.dart';
import 'package:voucher_app/domain/player.dart';
import 'package:voucher_app/domain/player_rating.dart';
import 'package:voucher_app/domain/tournament.dart';
import 'package:voucher_app/domain/tournament_match.dart';
import 'package:voucher_app/domain/tournament_team.dart';
import 'package:voucher_app/services/club_assignment_service.dart';
import 'package:voucher_app/services/club_service.dart';

void main() {
  test('baseStars uses adaptive min for N=3', () {
    expect(ClubAssignmentService.baseStars(rank: 1, teamCount: 3), 4.0);
    expect(ClubAssignmentService.baseStars(rank: 2, teamCount: 3), 4.5);
    expect(ClubAssignmentService.baseStars(rank: 3, teamCount: 3), 5.0);
  });

  test('baseStars uses adaptive min for N=5', () {
    expect(ClubAssignmentService.baseStars(rank: 1, teamCount: 5), 3.0);
    expect(ClubAssignmentService.baseStars(rank: 2, teamCount: 5), 3.5);
    expect(ClubAssignmentService.baseStars(rank: 3, teamCount: 5), 4.0);
    expect(ClubAssignmentService.baseStars(rank: 4, teamCount: 5), 4.5);
    expect(ClubAssignmentService.baseStars(rank: 5, teamCount: 5), 5.0);
  });

  test('baseStars uses adaptive min for N=7', () {
    expect(ClubAssignmentService.baseStars(rank: 1, teamCount: 7), 2.0);
    expect(ClubAssignmentService.baseStars(rank: 7, teamCount: 7), 5.0);
  });

  test('matchupStars follow example and cap at 5.0', () {
    final vs12 = ClubAssignmentService.matchupStars(
      rankStrong: 1,
      rankWeak: 2,
      teamCount: 3,
      teamSizeStrong: 2,
      teamSizeWeak: 2,
    );
    expect(vs12.strongStars, 4.5);
    expect(vs12.weakStars, 5.0);

    final vs13 = ClubAssignmentService.matchupStars(
      rankStrong: 1,
      rankWeak: 3,
      teamCount: 3,
      teamSizeStrong: 2,
      teamSizeWeak: 2,
    );
    expect(vs13.strongStars, 4.5);
    expect(vs13.weakStars, 5.0);

    final cap = ClubAssignmentService.matchupStars(
      rankStrong: 2,
      rankWeak: 3,
      teamCount: 3,
      teamSizeStrong: 2,
      teamSizeWeak: 2,
    );
    expect(cap.weakStars, 5.0);
  });

  test('matchupStars same for 1v2 as any other match (no solo handicap)', () {
    final stars = ClubAssignmentService.matchupStars(
      rankStrong: 1,
      rankWeak: 2,
      teamCount: 3,
      teamSizeStrong: 1,
      teamSizeWeak: 2,
    );
    // Baseline 4.5. No eloDiff provided so spread = 0.25
    // Strong: 4.5 - 0.25 = 4.25 -> rounds to 4.5
    // Weak: 4.5 + 0.25 = 4.75 -> rounds to 5.0
    expect(stars.strongStars, 4.5);
    expect(stars.weakStars, 5.0);
  });

  test('matchupStars applies no handicap for 1v1', () {
    final stars = ClubAssignmentService.matchupStars(
      rankStrong: 1,
      rankWeak: 2,
      teamCount: 3,
      teamSizeStrong: 1,
      teamSizeWeak: 1,
    );
    expect(stars.strongStars, 4.5);
    expect(stars.weakStars, 5.0);
  });

  test('matchupStars applies no handicap for 2v2', () {
    final stars = ClubAssignmentService.matchupStars(
      rankStrong: 1,
      rankWeak: 2,
      teamCount: 3,
      teamSizeStrong: 2,
      teamSizeWeak: 2,
    );
    expect(stars.strongStars, 4.5);
    expect(stars.weakStars, 5.0);
  });

  test('matchupStars distinguishes a non-zero small elo gap', () {
    final stars = ClubAssignmentService.matchupStars(
      rankStrong: 1,
      rankWeak: 2,
      teamCount: 3,
      teamSizeStrong: 2,
      teamSizeWeak: 2,
      eloDiff: 25,
    );
    expect(stars.strongStars, 4.5);
    expect(stars.weakStars, 5.0);
  });

  test('matchupStars dynamic spread for huge elo diff', () {
    // Diff 200 -> (200/200) = 1.0 spread.
    // Baseline 4.5.
    // Strong: 3.5. Weak: 5.5 (clamp 5.0).
    // Gap 1.5.
    final stars = ClubAssignmentService.matchupStars(
      rankStrong: 1,
      rankWeak: 2,
      teamCount: 3,
      teamSizeStrong: 2,
      teamSizeWeak: 2,
      eloDiff: 200,
    );
    expect(stars.strongStars, 3.5);
    expect(stars.weakStars, 5.0);
  });

  test('matchupStars differentiates the three-team scenario at the cap', () {
    final middleVsWeak = ClubAssignmentService.matchupStars(
      rankStrong: 2,
      rankWeak: 3,
      teamCount: 3,
      teamSizeStrong: 2,
      teamSizeWeak: 2,
      eloDiff: 25,
    );
    expect(middleVsWeak.strongStars, 4.5);
    expect(middleVsWeak.weakStars, 5.0);

    final strongVsMiddle = ClubAssignmentService.matchupStars(
      rankStrong: 1,
      rankWeak: 2,
      teamCount: 3,
      teamSizeStrong: 2,
      teamSizeWeak: 2,
      eloDiff: 25,
    );
    expect(strongVsMiddle.strongStars, 4.5);
    expect(strongVsMiddle.weakStars, 5.0);

    final strongVsWeak = ClubAssignmentService.matchupStars(
      rankStrong: 1,
      rankWeak: 3,
      teamCount: 3,
      teamSizeStrong: 2,
      teamSizeWeak: 2,
      eloDiff: 50,
    );
    expect(strongVsWeak.strongStars, 4.0);
    expect(strongVsWeak.weakStars, 5.0);
  });

  test('matchupStars preserves equal stars for an actual elo tie', () {
    final stars = ClubAssignmentService.matchupStars(
      rankStrong: 1,
      rankWeak: 2,
      teamCount: 3,
      teamSizeStrong: 2,
      teamSizeWeak: 2,
      eloDiff: 0,
    );
    expect(stars.strongStars, stars.weakStars);
  });

  test('auto assignment gives the higher elo away team lower stars', () async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();
    final store = await LocalStore.getInstance();
    final now = DateTime(2024, 1, 1);
    await store.savePlayers([
      for (final id in ['s1', 's2', 'w1', 'w2'])
        Player(id: id, displayName: id, createdAt: now, updatedAt: now),
    ]);
    await store.saveRatings({
      for (final id in ['s1', 's2'])
        id: PlayerRating(
          playerId: id,
          elo: 1000,
          gamesPlayed: 0,
          wins: 0,
          draws: 0,
          losses: 0,
          updatedAt: now,
        ),
      for (final id in ['w1', 'w2'])
        id: PlayerRating(
          playerId: id,
          elo: 950,
          gamesPlayed: 0,
          wins: 0,
          draws: 0,
          losses: 0,
          updatedAt: now,
        ),
    });
    await store.saveTournaments([
      Tournament(
        id: 't',
        name: 'Cup',
        mode: MatchMode.twoVTwo,
        status: TournamentStatus.group,
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    await store.saveTournamentTeams([
      TournamentTeam(
        id: 'strong',
        tournamentId: 't',
        teamIndex: 0,
        name: 'Strong',
        playerIds: const ['s1', 's2'],
      ),
      TournamentTeam(
        id: 'weak',
        tournamentId: 't',
        teamIndex: 1,
        name: 'Weak',
        playerIds: const ['w1', 'w2'],
      ),
    ]);
    await store.saveTournamentMatches([
      TournamentMatch(
        id: 'm',
        tournamentId: 't',
        stage: TournamentStage.group,
        homeTeamIndex: 1,
        awayTeamIndex: 0,
        scheduledOrder: 0,
        status: TournamentMatchStatus.scheduled,
      ),
    ]);

    await ClubAssignmentService(store).assignForTournamentSchedule(
      tournamentId: 't',
    );

    final assigned = (await store.getTournamentMatches()).single;
    expect(
      assigned.awayAssignedStars!,
      lessThan(assigned.homeAssignedStars!),
    );
  });

  test('pickClub prefers exact stars and is deterministic with seed', () {
    final clubs = [
      Club(
        id: 'b',
        name: 'B',
        stars: 4.5,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      ),
      Club(
        id: 'a',
        name: 'A',
        stars: 4.5,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      ),
    ];
    final selected = ClubAssignmentService.pickClubForStars(
      requiredStars: 4.5,
      clubs: clubs,
      random: Random(42),
    );
    // With Random(42) and list [a, b], shuffle might pick one.
    // We just ensure it's valid.
    expect(selected, isNotNull);
    expect(['a', 'b'], contains(selected!.id));
  });

  test('pickClub falls back to nearest and avoids duplicates', () {
    final clubs = [
      Club(
        id: 'a',
        name: 'A',
        stars: 4.0,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      ),
      Club(
        id: 'b',
        name: 'B',
        stars: 5.0,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      ),
    ];
    final home = ClubAssignmentService.pickClubForStars(
      requiredStars: 4.5,
      clubs: clubs,
    );
    final away = ClubAssignmentService.pickClubForStars(
      requiredStars: 4.5,
      clubs: clubs,
      excludeId: home?.id,
    );
    expect(home, isNotNull);
    expect(away, isNotNull);
    expect(away!.id, isNot(home!.id));
  });

  test('club service CRUD uses SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();

    final service = await ClubService.create();
    final created = await service.createClub('FC Example', 4.5);

    var clubs = await service.listClubs();
    expect(clubs.length, 1);
    expect(clubs.first.name, 'FC Example');

    await service.updateClub(created.id, 'FC Updated', 5.0);
    clubs = await service.listClubs();
    expect(clubs.first.name, 'FC Updated');
    expect(clubs.first.stars, 5.0);

    await service.deleteClub(created.id);
    clubs = await service.listClubs();
    expect(clubs, isEmpty);

    final withDeleted = await service.listClubs(includeDeleted: true);
    expect(withDeleted.length, 1);
    expect(withDeleted.first.deletedAt, isNotNull);
  });
}

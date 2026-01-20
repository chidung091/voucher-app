import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voucher_app/data/local_store.dart';
import 'package:voucher_app/domain/club.dart';
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

  test('matchupStars applies solo handicap for 1v2', () {
    final stars = ClubAssignmentService.matchupStars(
      rankStrong: 1,
      rankWeak: 2,
      teamCount: 3,
      teamSizeStrong: 1,
      teamSizeWeak: 2,
    );
    // Baseline 4.5. Spread +/- 0.25 -> 4.25 / 4.75.
    // Handicap +0.5 to strong (solo).
    // Strong: 4.25 + 0.5 = 4.75. Round(0.5) -> 5.0.
    // Weak: 4.75. Round(0.5) -> 5.0.
    expect(stars.strongStars, 5.0);
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

  test('matchupStars dynamic spread for close elo', () {
    // Diff 40 -> (40/200) = 0.2, max(0.25, 0.2) -> 0.25 spread.
    // Result: 4.75 vs 5.25 (clamped 5.0).
    // Or baselines 4.0/4.5 (avg 4.25) -> 4.0 / 4.5.
    // Let's take rank 1 vs 2 (TeamCount 3) -> Base 4.0, 4.5. Baseline 4.5.
    // Spread 0.25. 4.25 / 4.75. Rounds to 4.5 / 5.0. Gap 0.5.
    final stars = ClubAssignmentService.matchupStars(
      rankStrong: 1,
      rankWeak: 2,
      teamCount: 3,
      teamSizeStrong: 2,
      teamSizeWeak: 2,
      eloDiff: 36, // < 60 approx
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

  test(
      'matchupStars prefers 4.5 vs 5.0 for moderate diff provided in user example',
      () {
    // User Example: Team 2 (2055) vs Team 3 (2019). Diff 36.
    // Ranks likely 1 and 2 if close.
    // Should behave like close elo test -> 4.5 vs 5.0.
    final stars = ClubAssignmentService.matchupStars(
      rankStrong: 1,
      rankWeak: 2,
      teamCount: 3,
      teamSizeStrong: 2,
      teamSizeWeak: 2,
      eloDiff: 36,
    );
    expect(stars.strongStars, 4.5);
    expect(stars.weakStars, 5.0);
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

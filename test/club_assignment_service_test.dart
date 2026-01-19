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

  test('pickClub prefers exact stars and is deterministic', () {
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
    );
    expect(selected?.id, 'a');
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

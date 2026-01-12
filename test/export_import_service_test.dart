import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voucher_app/data/local_store.dart';
import 'package:voucher_app/domain/enums.dart';
import 'package:voucher_app/services/export_import_service.dart';
import 'package:voucher_app/services/player_service.dart';
import 'package:voucher_app/services/tournament_service.dart';

void main() {
  test('Export then import overwrite restores snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();

    final playerService = await PlayerService.create();
    await playerService.createPlayer('Alice', skillLevel: 1);
    await playerService.createPlayer('Bob', skillLevel: 2);

    final service = await ExportImportService.create();
    final json = await service.exportToJsonString();

    final report = await service.importFromJsonString(
      json,
      mode: ImportMode.overwrite,
    );
    expect(report.addedPlayers, 2);

    final store = await LocalStore.getInstance();
    final snapshot = await store.getAllDataSnapshot();
    final data = jsonDecode(json) as Map<String, dynamic>;
    expect(snapshot['players'].length, (data['data']['players'] as List).length);
  });

  test('Merge creates placeholders for missing players', () async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();

    final service = await ExportImportService.create();
    final payload = {
      'app': 'fc_tracker',
      'exportVersion': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'schemaVersion': 2,
      'data': {
        'players': [],
        'playerRatings': {},
        'matches': [
          {
            'id': '2a278f64-5ee8-4b10-8b6b-cf8ef9b2f3d0',
            'mode': '1V1',
            'sideAPlayerIds': ['p1'],
            'sideBPlayerIds': ['p2'],
            'scoreA': 1,
            'scoreB': 0,
            'result': 'A',
            'playedAt': DateTime.now().toIso8601String(),
            'createdAt': DateTime.now().toIso8601String(),
          },
        ],
        'ratingEvents': [],
        'tournaments': [],
        'tournamentTeams': [],
        'tournamentMatches': [],
        'meta': {'schemaVersion': 2},
      },
    };

    final report = await service.importFromJsonString(
      jsonEncode(payload),
      mode: ImportMode.merge,
    );

    expect(report.errors.isNotEmpty, true);
    final store = await LocalStore.getInstance();
    final players = await store.getPlayers();
    expect(players.length, 2);
  });

  test('Validation rejects invalid payload', () async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();

    final service = await ExportImportService.create();
    final invalidPayload = jsonEncode({
      'app': 'wrong',
      'exportVersion': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'schemaVersion': 2,
      'data': {},
    });

    expect(
      () => service.importFromJsonString(invalidPayload),
      throwsArgumentError,
    );
  });

  test('Merge keeps latest tournament data', () async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();

    final playerService = await PlayerService.create();
    final p1 = await playerService.createPlayer('P1');
    final p2 = await playerService.createPlayer('P2');
    final p3 = await playerService.createPlayer('P3');

    final tournamentService = await TournamentService.create();
    await tournamentService.createTournament(
      TournamentInput(
        name: 'Cup',
        mode: MatchMode.oneVOne,
        teams: [
          TournamentTeamInput(name: 'Team 1', playerIds: [p1.id]),
          TournamentTeamInput(name: 'Team 2', playerIds: [p2.id]),
          TournamentTeamInput(name: 'Team 3', playerIds: [p3.id]),
        ],
      ),
    );

    final exportService = await ExportImportService.create();
    final json = await exportService.exportToJsonString();
    final report = await exportService.importFromJsonString(
      json,
      mode: ImportMode.merge,
    );

    expect(report.errors, isEmpty);
  });

  test('Backup stored before overwrite import', () async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();

    final exportService = await ExportImportService.create();
    final json = await exportService.exportToJsonString();

    await exportService.importFromJsonString(json, mode: ImportMode.overwrite);
    final store = await LocalStore.getInstance();
    final backup = await store.getBackupPayload();

    expect(backup, isNotNull);
  });
}

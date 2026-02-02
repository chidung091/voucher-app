import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../data/local_store.dart';
import '../domain/club.dart';
import '../domain/elo_calculator.dart';
import '../domain/match.dart';
import '../domain/player.dart';
import '../domain/player_rating.dart';
import '../domain/rating_event.dart';
import '../domain/tournament.dart';
import '../domain/tournament_match.dart';
import '../domain/tournament_team.dart';
import '../domain/season.dart';
import 'export_validator.dart';
import 'head_to_head_service.dart';
import 'player_stats_service.dart';
import 'season_service.dart';

enum ImportMode { overwrite, merge }

class ImportReport {
  ImportReport({
    required this.addedPlayers,
    required this.updatedPlayers,
    required this.addedMatches,
    required this.skippedMatches,
    required this.errors,
  });

  final int addedPlayers;
  final int updatedPlayers;
  final int addedMatches;
  final int skippedMatches;
  final List<String> errors;
}

class ExportImportService {
  ExportImportService(this._store);

  final LocalStore _store;

  static Future<ExportImportService> create() async {
    return ExportImportService(await LocalStore.getInstance());
  }

  Future<String> exportToJsonString() async {
    final snapshot = await _store.getAllDataSnapshot();
    final payload = _buildPayload(snapshot);
    return jsonEncode(payload.toJson());
  }

  Future<File?> exportToFile() async {
    final jsonString = await exportToJsonString();
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}/fc_tracker_export_${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(jsonString);
    return file;
  }

  Future<ImportReport> importFromJsonString(
    String json, {
    ImportMode mode = ImportMode.overwrite,
  }) async {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final validation = ExportPayloadValidator.validate(decoded);
    if (!validation.isValid) {
      throw ArgumentError(validation.errors.join('\n'));
    }
    final payload = _migratePayload(validation.payload!);

    return _store.writeTransaction(() async {
      if (mode == ImportMode.overwrite) {
        final backup = await exportToJsonString();
        await _store.saveBackupPayload(backup);
        await _store.clearAppKeys();
        await _store.setAllDataSnapshot(payload.data, overwrite: true);
        await PlayerStatsService(_store, EloCalculator())
            .invalidateAllStatsCache();
        await HeadToHeadService(_store).invalidateAllH2HCache();
        await SeasonService(_store, EloCalculator()).invalidateAllSeasonCache();
        return ImportReport(
          addedPlayers: payload.data['players'].length as int,
          updatedPlayers: 0,
          addedMatches: payload.data['matches'].length as int,
          skippedMatches: 0,
          errors: [],
        );
      }

      final report = await _merge(payload);
      await PlayerStatsService(_store, EloCalculator())
          .invalidateAllStatsCache();
      await HeadToHeadService(_store).invalidateAllH2HCache();
      await SeasonService(_store, EloCalculator()).invalidateAllSeasonCache();
      return report;
    });
  }

  Future<ImportReport> importFromFile(
    File file, {
    ImportMode mode = ImportMode.overwrite,
  }) async {
    final json = await file.readAsString();
    return importFromJsonString(json, mode: mode);
  }

  Future<File?> exportToFilePicker() async {
    final jsonString = await exportToJsonString();
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export FC Tracker data',
      fileName: 'fc_tracker_export.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null) return null;
    final file = File(result);
    await file.writeAsString(jsonString);
    return file;
  }

  Future<ImportReport> importFromFilePicker({
    ImportMode mode = ImportMode.overwrite,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) {
      throw StateError('No file selected');
    }
    final file = File(result.files.single.path!);
    return importFromFile(file, mode: mode);
  }

  Future<ImportReport> restoreLastBackup() async {
    final backup = await _store.getBackupPayload();
    if (backup == null) {
      throw StateError('No backup found');
    }
    return importFromJsonString(backup, mode: ImportMode.overwrite);
  }

  ExportPayload _buildPayload(Map<String, dynamic> snapshot) {
    final players = (snapshot['players'] as List<dynamic>)
        .map((item) => Player.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final matches = (snapshot['matches'] as List<dynamic>)
        .map((item) => Match.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final ratingEvents = (snapshot['ratingEvents'] as List<dynamic>)
        .map((item) => RatingEvent.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final tournaments = (snapshot['tournaments'] as List<dynamic>)
        .map((item) => Tournament.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final tournamentTeams = (snapshot['tournamentTeams'] as List<dynamic>)
        .map((item) => TournamentTeam.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final tournamentMatches = (snapshot['tournamentMatches'] as List<dynamic>)
        .map((item) => TournamentMatch.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.scheduledOrder.compareTo(b.scheduledOrder));
    final clubs = (snapshot['clubs'] as List<dynamic>? ?? [])
        .map((item) => Club.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final seasonConfig = snapshot['seasonConfig'] == null
        ? null
        : SeasonConfig.fromJson(
            snapshot['seasonConfig'] as Map<String, dynamic>,
          );
    final seasonCache = (snapshot['seasonCache'] as Map<String, dynamic>? ?? {})
        .map((key, value) => MapEntry(key, value as String));
    final ratings = (snapshot['playerRatings'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
            key, PlayerRating.fromJson(value as Map<String, dynamic>)));

    return ExportPayload(
      app: 'fc_tracker',
      exportVersion: 1,
      createdAt: DateTime.now(),
      schemaVersion: LocalStore.schemaVersion,
      data: {
        'players': players.map((p) => p.toJson()).toList(),
        'playerRatings':
            ratings.map((key, value) => MapEntry(key, value.toJson())),
        'matches': matches.map((m) => m.toJson()).toList(),
        'ratingEvents': ratingEvents.map((e) => e.toJson()).toList(),
        'tournaments': tournaments.map((t) => t.toJson()).toList(),
        'tournamentTeams': tournamentTeams.map((t) => t.toJson()).toList(),
        'tournamentMatches': tournamentMatches.map((m) => m.toJson()).toList(),
        'clubs': clubs.map((c) => c.toJson()).toList(),
        'seasonConfig': seasonConfig?.toJson(),
        'seasonCache': seasonCache,
        'meta': snapshot['meta'] ?? {},
      },
    );
  }

  ExportPayload _migratePayload(ExportPayload payload) {
    if (payload.schemaVersion >= LocalStore.schemaVersion) {
      return payload;
    }
    final data = Map<String, dynamic>.from(payload.data);
    final players = (data['players'] as List<dynamic>?) ?? [];
    data['players'] = players.map((item) {
      final map = Map<String, dynamic>.from(item as Map<String, dynamic>);
      map.putIfAbsent('skillLevel', () => 2);
      return map;
    }).toList();
    final matches = (data['matches'] as List<dynamic>?) ?? [];
    data['matches'] = matches.map((item) {
      final map = Map<String, dynamic>.from(item as Map<String, dynamic>);
      map.putIfAbsent('ratingMode', () => 'RANKED');
      map.putIfAbsent('eloMultiplier', () => 1.0);
      return map;
    }).toList();
    data['clubs'] = data['clubs'] ?? [];
    data['seasonConfig'] =
        data['seasonConfig'] ?? SeasonConfig.defaults().toJson();
    data['seasonCache'] = data['seasonCache'] ?? <String, dynamic>{};
    final meta =
        Map<String, dynamic>.from(data['meta'] as Map<String, dynamic>? ?? {});
    meta['schemaVersion'] = LocalStore.schemaVersion;
    data['meta'] = meta;
    return ExportPayload(
      app: payload.app,
      exportVersion: payload.exportVersion,
      createdAt: payload.createdAt,
      schemaVersion: LocalStore.schemaVersion,
      data: data,
    );
  }

  Future<ImportReport> _merge(ExportPayload payload) async {
    final errors = <String>[];
    final data = payload.data;
    final players = (data['players'] as List<dynamic>)
        .map((item) => Player.fromJson(item as Map<String, dynamic>))
        .toList();
    final ratings = (data['playerRatings'] as Map<String, dynamic>).map((key,
            value) =>
        MapEntry(key, PlayerRating.fromJson(value as Map<String, dynamic>)));
    final matches = (data['matches'] as List<dynamic>)
        .map((item) => Match.fromJson(item as Map<String, dynamic>))
        .toList();
    final ratingEvents = (data['ratingEvents'] as List<dynamic>)
        .map((item) => RatingEvent.fromJson(item as Map<String, dynamic>))
        .toList();
    final tournaments = (data['tournaments'] as List<dynamic>)
        .map((item) => Tournament.fromJson(item as Map<String, dynamic>))
        .toList();
    final tournamentTeams = (data['tournamentTeams'] as List<dynamic>)
        .map((item) => TournamentTeam.fromJson(item as Map<String, dynamic>))
        .toList();
    final tournamentMatches = (data['tournamentMatches'] as List<dynamic>)
        .map((item) => TournamentMatch.fromJson(item as Map<String, dynamic>))
        .toList();
    final clubs = (data['clubs'] as List<dynamic>? ?? [])
        .map((item) => Club.fromJson(item as Map<String, dynamic>))
        .toList();
    final incomingSeasonConfig = data['seasonConfig'] != null
        ? SeasonConfig.fromJson(data['seasonConfig'] as Map<String, dynamic>)
        : SeasonConfig.defaults();
    final incomingSeasonCache =
        (data['seasonCache'] as Map<String, dynamic>? ?? {})
            .map((key, value) => MapEntry(key, value as String));

    final localPlayers = await _store.getPlayers();
    final localRatings = await _store.getRatings();
    final localMatches = await _store.getMatches();
    final localEvents = await _store.getRatingEvents();
    final localTournaments = await _store.getTournaments();
    final localTeams = await _store.getTournamentTeams();
    final localMatchesMeta = await _store.getTournamentMatches();
    final localClubs = await _store.getClubs();
    final localSeasonConfig = await _store.getSeasonConfig();
    final localSeasonCache = await _store.getSeasonCacheEntries();

    final playerMap = {for (final player in localPlayers) player.id: player};
    var addedPlayers = 0;
    var updatedPlayers = 0;
    for (final player in players) {
      final existing = playerMap[player.id];
      if (existing == null) {
        playerMap[player.id] = player;
        addedPlayers++;
      } else {
        final incomingNewer = player.updatedAt.isAfter(existing.updatedAt);
        if (incomingNewer) {
          playerMap[player.id] = existing.copyWith(
            displayName: player.displayName,
            skillLevel: player.skillLevel,
            updatedAt: player.updatedAt,
            deletedAt: player.deletedAt ?? existing.deletedAt,
          );
          updatedPlayers++;
        } else if (existing.deletedAt == null && player.deletedAt != null) {
          playerMap[player.id] = existing.copyWith(
            deletedAt: player.deletedAt,
            updatedAt: existing.updatedAt,
          );
        }
      }
    }
    final mergedPlayers = playerMap.values.toList();

    final ratingMap = {...localRatings};
    ratings.forEach((key, value) {
      final existing = ratingMap[key];
      if (existing == null || value.updatedAt.isAfter(existing.updatedAt)) {
        ratingMap[key] = value;
      }
    });

    final matchMap = {for (final match in localMatches) match.id: match};
    final idempotencyMap = {
      for (final match in localMatches)
        if (match.idempotencyKey != null) match.idempotencyKey!: match
    };
    var addedMatches = 0;
    var skippedMatches = 0;
    for (final match in matches) {
      final existing =
          matchMap[match.id] ?? idempotencyMap[match.idempotencyKey];
      if (existing == null) {
        matchMap[match.id] = match;
        addedMatches++;
      } else if (match.createdAt.isAfter(existing.createdAt)) {
        matchMap[match.id] = match;
      } else {
        skippedMatches++;
      }
    }

    final eventMap = {
      for (final event in localEvents)
        '${event.matchId}-${event.playerId}': event
    };
    for (final event in ratingEvents) {
      eventMap['${event.matchId}-${event.playerId}'] = event;
    }

    final tournamentMap = {
      for (final tournament in localTournaments) tournament.id: tournament
    };
    for (final tournament in tournaments) {
      final existing = tournamentMap[tournament.id];
      if (existing == null ||
          tournament.updatedAt.isAfter(existing.updatedAt)) {
        tournamentMap[tournament.id] = tournament;
      }
    }

    final teamMap = {
      for (final team in localTeams)
        '${team.tournamentId}-${team.teamIndex}': team
    };
    for (final team in tournamentTeams) {
      teamMap['${team.tournamentId}-${team.teamIndex}'] = team;
    }

    final tournamentMatchMap = {
      for (final match in localMatchesMeta) match.id: match
    };
    for (final match in tournamentMatches) {
      tournamentMatchMap[match.id] = match;
    }

    final clubMap = {for (final club in localClubs) club.id: club};
    for (final club in clubs) {
      final existing = clubMap[club.id];
      if (existing == null || club.updatedAt.isAfter(existing.updatedAt)) {
        clubMap[club.id] = club;
      }
    }

    final selectedSeasonConfig = localSeasonConfig == null ||
            incomingSeasonConfig.updatedAt.isAfter(localSeasonConfig.updatedAt)
        ? incomingSeasonConfig
        : localSeasonConfig;
    final mergedSeasonCache = {...localSeasonCache, ...incomingSeasonCache};

    final updatedMatches = matchMap.values.toList();
    final updatedEvents = eventMap.values.toList();

    final localMeta = await _store.getMeta();
    final incomingMeta = Map<String, dynamic>.from(
      data['meta'] as Map<String, dynamic>? ?? {},
    );
    final metaUpdated = _pickLatestMeta(localMeta, incomingMeta);

    final playerIds = mergedPlayers.map((p) => p.id).toSet();
    for (final match in updatedMatches) {
      for (final pid in [
        ...match.sideAPlayerIds,
        ...match.sideBPlayerIds,
      ]) {
        if (!playerIds.contains(pid)) {
          mergedPlayers.add(
            Player(
              id: pid,
              displayName: 'Unknown',
              skillLevel: 2,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          playerIds.add(pid);
          errors.add('Placeholder created for missing player $pid.');
        }
      }
    }

    await _store.savePlayers(mergedPlayers);
    await _store.saveRatings(ratingMap);
    await _store.saveMatches(updatedMatches);
    await _store.saveRatingEvents(updatedEvents);
    await _store.saveTournaments(tournamentMap.values.toList());
    await _store.saveTournamentTeams(teamMap.values.toList());
    await _store.saveTournamentMatches(tournamentMatchMap.values.toList());
    await _store.saveClubs(clubMap.values.toList());
    await _store.saveSeasonConfig(selectedSeasonConfig);
    await _store.saveSeasonCacheEntries(mergedSeasonCache);
    await _store.saveMeta(metaUpdated);

    return ImportReport(
      addedPlayers: addedPlayers,
      updatedPlayers: updatedPlayers,
      addedMatches: addedMatches,
      skippedMatches: skippedMatches,
      errors: errors,
    );
  }
}

Map<String, dynamic> _pickLatestMeta(
  Map<String, dynamic> local,
  Map<String, dynamic> incoming,
) {
  final localUpdated = DateTime.tryParse(
        local['lastUpdatedAt'] as String? ?? '',
      ) ??
      DateTime.fromMillisecondsSinceEpoch(0);
  final incomingUpdated = DateTime.tryParse(
        incoming['lastUpdatedAt'] as String? ?? '',
      ) ??
      DateTime.fromMillisecondsSinceEpoch(0);
  if (incomingUpdated.isAfter(localUpdated)) {
    return {
      ...local,
      ...incoming,
    };
  }
  return local;
}

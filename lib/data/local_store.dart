import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/match.dart';
import '../domain/player.dart';
import '../domain/player_rating.dart';
import '../domain/rating_event.dart';
import '../domain/tournament.dart';
import '../domain/tournament_match.dart';
import '../domain/tournament_team.dart';

class LocalStore {
  LocalStore._(this._prefs);

  final SharedPreferences _prefs;
  static LocalStore? _instance;

  // Using separate keys avoids rewriting a single large blob on each update.
  static const String _playersKey = 'players_v1';
  static const String _ratingsKey = 'player_ratings_v1';
  static const String _matchesKey = 'matches_v1';
  static const String _ratingEventsKey = 'rating_events_v1';
  static const String _tournamentsKey = 'tournaments_v1';
  static const String _tournamentTeamsKey = 'tournament_teams_v1';
  static const String _tournamentMatchesKey = 'tournament_matches_v1';
  static const String _metaKey = 'app_meta_v1';
  static const String _backupKey = 'last_backup_export_v1';

  static const Map<String, String> _tempKeyMap = {
    _playersKey: 'players_v1_tmp',
    _ratingsKey: 'player_ratings_v1_tmp',
    _matchesKey: 'matches_v1_tmp',
    _ratingEventsKey: 'rating_events_v1_tmp',
    _tournamentsKey: 'tournaments_v1_tmp',
    _tournamentTeamsKey: 'tournament_teams_v1_tmp',
    _tournamentMatchesKey: 'tournament_matches_v1_tmp',
    _metaKey: 'app_meta_v1_tmp',
  };

  static const int _schemaVersion = 2;

  Future<void> _ensureMeta() async {
    final existing = _prefs.getString(_metaKey);
    if (existing != null) {
      final meta = jsonDecode(existing) as Map<String, dynamic>;
      final version = meta['schemaVersion'] as int? ?? 1;
      if (version < 2) {
        await _migrateToV2();
        meta['schemaVersion'] = _schemaVersion;
        meta['lastUpdatedAt'] = DateTime.now().toIso8601String();
        await _prefs.setString(_metaKey, jsonEncode(meta));
      }
      return;
    }
    final meta = {
      'schemaVersion': _schemaVersion,
      'lastUpdatedAt': DateTime.now().toIso8601String(),
    };
    await _prefs.setString(_metaKey, jsonEncode(meta));
  }

  Future<void> _migrateToV2() async {
    final rawPlayers = _prefs.getString(_playersKey);
    if (rawPlayers == null) return;
    final decoded = jsonDecode(rawPlayers) as List<dynamic>;
    final migrated = decoded.map((item) {
      final map = Map<String, dynamic>.from(item as Map<String, dynamic>);
      map.putIfAbsent('skillLevel', () => 2);
      return map;
    }).toList();
    await _prefs.setString(_playersKey, jsonEncode(migrated));
  }

  static Future<LocalStore> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }
    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore._(prefs);
    await store._ensureMeta();
    _instance = store;
    return store;
  }

  static void resetForTest() {
    _instance = null;
  }

  static int get schemaVersion => _schemaVersion;

  static Future<LocalStore> withPrefs(SharedPreferences prefs) async {
    final store = LocalStore._(prefs);
    await store._ensureMeta();
    return store;
  }

  Future<void> _touchMeta() async {
    final raw = _prefs.getString(_metaKey);
    if (raw == null) return;
    final meta = jsonDecode(raw) as Map<String, dynamic>;
    meta['lastUpdatedAt'] = DateTime.now().toIso8601String();
    await _prefs.setString(_metaKey, jsonEncode(meta));
  }

  Future<List<Player>> getPlayers() async {
    final raw = _prefs.getString(_playersKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Player.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> savePlayers(List<Player> players) async {
    final payload = jsonEncode(players.map((p) => p.toJson()).toList());
    await _prefs.setString(_playersKey, payload);
    await _touchMeta();
  }

  Future<Map<String, PlayerRating>> getRatings() async {
    final raw = _prefs.getString(_ratingsKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (key, value) =>
          MapEntry(key, PlayerRating.fromJson(value as Map<String, dynamic>)),
    );
  }

  Future<void> saveRatings(Map<String, PlayerRating> ratings) async {
    final payload = jsonEncode(
      ratings.map((key, value) => MapEntry(key, value.toJson())),
    );
    await _prefs.setString(_ratingsKey, payload);
    await _touchMeta();
  }

  Future<List<Match>> getMatches() async {
    final raw = _prefs.getString(_matchesKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Match.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveMatches(List<Match> matches) async {
    final payload = jsonEncode(matches.map((m) => m.toJson()).toList());
    await _prefs.setString(_matchesKey, payload);
    await _touchMeta();
  }

  Future<List<RatingEvent>> getRatingEvents() async {
    final raw = _prefs.getString(_ratingEventsKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => RatingEvent.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveRatingEvents(List<RatingEvent> events) async {
    final payload = jsonEncode(events.map((e) => e.toJson()).toList());
    await _prefs.setString(_ratingEventsKey, payload);
    await _touchMeta();
  }

  Future<List<Tournament>> getTournaments() async {
    final raw = _prefs.getString(_tournamentsKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Tournament.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveTournaments(List<Tournament> tournaments) async {
    final payload = jsonEncode(tournaments.map((t) => t.toJson()).toList());
    await _prefs.setString(_tournamentsKey, payload);
    await _touchMeta();
  }

  Future<List<TournamentTeam>> getTournamentTeams() async {
    final raw = _prefs.getString(_tournamentTeamsKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => TournamentTeam.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveTournamentTeams(List<TournamentTeam> teams) async {
    final payload = jsonEncode(teams.map((t) => t.toJson()).toList());
    await _prefs.setString(_tournamentTeamsKey, payload);
    await _touchMeta();
  }

  Future<List<TournamentMatch>> getTournamentMatches() async {
    final raw = _prefs.getString(_tournamentMatchesKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => TournamentMatch.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveTournamentMatches(List<TournamentMatch> matches) async {
    final payload = jsonEncode(matches.map((m) => m.toJson()).toList());
    await _prefs.setString(_tournamentMatchesKey, payload);
    await _touchMeta();
  }

  Future<Map<String, dynamic>> getMeta() async {
    final raw = _prefs.getString(_metaKey);
    if (raw == null) {
      return {
        'schemaVersion': _schemaVersion,
        'lastUpdatedAt': DateTime.now().toIso8601String(),
      };
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveMeta(Map<String, dynamic> meta) async {
    await _prefs.setString(_metaKey, jsonEncode(meta));
  }

  Future<String?> getBackupPayload() async {
    return _prefs.getString(_backupKey);
  }

  Future<void> saveBackupPayload(String payload) async {
    await _prefs.setString(_backupKey, payload);
  }

  Future<void> clearAppKeys() async {
    for (final key in _appKeys()) {
      await _prefs.remove(key);
    }
  }

  Future<Map<String, dynamic>> getAllDataSnapshot() async {
    return {
      'players': (await getPlayers()).map((p) => p.toJson()).toList(),
      'playerRatings': (await getRatings())
          .map((key, value) => MapEntry(key, value.toJson())),
      'matches': (await getMatches()).map((m) => m.toJson()).toList(),
      'ratingEvents':
          (await getRatingEvents()).map((e) => e.toJson()).toList(),
      'tournaments': (await getTournaments()).map((t) => t.toJson()).toList(),
      'tournamentTeams':
          (await getTournamentTeams()).map((t) => t.toJson()).toList(),
      'tournamentMatches':
          (await getTournamentMatches()).map((m) => m.toJson()).toList(),
      'meta': await getMeta(),
    };
  }

  Future<void> setAllDataSnapshot(
    Map<String, dynamic> snapshot, {
    bool overwrite = true,
  }) async {
    Future<void> writePayload({required bool useTemp}) async {
      Future<void> write(String key, Object value) async {
        final target = useTemp ? _tempKeyMap[key] ?? key : key;
        await _prefs.setString(target, jsonEncode(value));
      }

      await write(_playersKey, snapshot['players'] ?? []);
      await write(_ratingsKey, snapshot['playerRatings'] ?? {});
      await write(_matchesKey, snapshot['matches'] ?? []);
      await write(_ratingEventsKey, snapshot['ratingEvents'] ?? []);
      await write(_tournamentsKey, snapshot['tournaments'] ?? []);
      await write(_tournamentTeamsKey, snapshot['tournamentTeams'] ?? []);
      await write(_tournamentMatchesKey, snapshot['tournamentMatches'] ?? []);
      await write(_metaKey, snapshot['meta'] ?? {});
    }

    if (!overwrite) {
      await writePayload(useTemp: false);
      return;
    }

    await writePayload(useTemp: true);
    for (final key in _appKeys()) {
      final temp = _tempKeyMap[key]!;
      final payload = _prefs.getString(temp);
      if (payload != null) {
        await _prefs.setString(key, payload);
        await _prefs.remove(temp);
      }
    }
  }

  static List<String> _appKeys() {
    return [
      _playersKey,
      _ratingsKey,
      _matchesKey,
      _ratingEventsKey,
      _tournamentsKey,
      _tournamentTeamsKey,
      _tournamentMatchesKey,
      _metaKey,
    ];
  }

  Future<T> writeTransaction<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _writeQueue = Future.value();
}

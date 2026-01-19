import '../domain/enums.dart';

class ValidationResult {
  ValidationResult({required this.isValid, required this.errors, this.payload});

  final bool isValid;
  final List<String> errors;
  final ExportPayload? payload;
}

class ExportPayload {
  ExportPayload({
    required this.app,
    required this.exportVersion,
    required this.createdAt,
    required this.schemaVersion,
    required this.data,
  });

  final String app;
  final int exportVersion;
  final DateTime createdAt;
  final int schemaVersion;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() {
    return {
      'app': app,
      'exportVersion': exportVersion,
      'createdAt': createdAt.toIso8601String(),
      'schemaVersion': schemaVersion,
      'data': data,
    };
  }
}

class ExportPayloadValidator {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  static ValidationResult validate(Map<String, dynamic> payload) {
    final errors = <String>[];
    if (payload['app'] != 'fc_tracker') {
      errors.add('Invalid app identifier.');
    }
    if (payload['exportVersion'] != 1) {
      errors.add('Unsupported exportVersion.');
    }
    if (payload['schemaVersion'] is! int) {
      errors.add('schemaVersion missing or invalid.');
    }
    if (payload['data'] is! Map<String, dynamic>) {
      errors.add('data missing or invalid.');
    }

    if (errors.isNotEmpty) {
      return ValidationResult(isValid: false, errors: errors);
    }

    final data = payload['data'] as Map<String, dynamic>;
    _validatePlayers(data['players'], errors);
    _validateClubs(data['clubs'], errors);
    _validateMatches(data['matches'], errors);
    _validateTournaments(data['tournaments'], data['tournamentTeams'], errors);
    _validateRatingEvents(data['ratingEvents'], errors);

    if (errors.isNotEmpty) {
      return ValidationResult(isValid: false, errors: errors);
    }

    return ValidationResult(
      isValid: true,
      errors: [],
      payload: ExportPayload(
        app: payload['app'] as String,
        exportVersion: payload['exportVersion'] as int,
        createdAt: DateTime.parse(payload['createdAt'] as String),
        schemaVersion: payload['schemaVersion'] as int,
        data: data,
      ),
    );
  }

  static void _validatePlayers(Object? players, List<String> errors) {
    if (players is! List<dynamic>) {
      errors.add('players must be a list.');
      return;
    }
    for (final item in players) {
      if (item is! Map<String, dynamic>) {
        errors.add('player item invalid.');
        continue;
      }
      final id = item['id'] as String?;
      if (id == null || !_uuidRegex.hasMatch(id)) {
        errors.add('player id invalid.');
      }
    }
  }

  static void _validateMatches(Object? matches, List<String> errors) {
    if (matches is! List<dynamic>) {
      errors.add('matches must be a list.');
      return;
    }
    for (final item in matches) {
      if (item is! Map<String, dynamic>) {
        errors.add('match item invalid.');
        continue;
      }
      final id = item['id'] as String?;
      if (id == null || !_uuidRegex.hasMatch(id)) {
        errors.add('match id invalid.');
      }
      final mode = item['mode'] as String?;
      if (mode != '1V1' && mode != '2V2') {
        errors.add('match mode invalid.');
      }
      final sideA = item['sideAPlayerIds'];
      final sideB = item['sideBPlayerIds'];
      if (sideA is! List || sideB is! List) {
        errors.add('match sides invalid.');
      } else {
        final expected = mode == '2V2' ? 2 : 1;
        if (sideA.length != expected || sideB.length != expected) {
          errors.add('match side length invalid.');
        }
      }
      if (item['scoreA'] is! int || item['scoreB'] is! int) {
        errors.add('match score invalid.');
      }
    }
  }

  static void _validateClubs(Object? clubs, List<String> errors) {
    if (clubs == null) return;
    if (clubs is! List<dynamic>) {
      errors.add('clubs must be a list.');
      return;
    }
    for (final item in clubs) {
      if (item is! Map<String, dynamic>) {
        errors.add('club item invalid.');
        continue;
      }
      final id = item['id'] as String?;
      if (id == null || !_uuidRegex.hasMatch(id)) {
        errors.add('club id invalid.');
      }
      if (item['stars'] is! num) {
        errors.add('club stars invalid.');
      }
    }
  }

  static void _validateTournaments(
    Object? tournaments,
    Object? teams,
    List<String> errors,
  ) {
    if (tournaments is! List<dynamic> || teams is! List<dynamic>) {
      errors.add('tournaments or teams invalid.');
      return;
    }
    final teamMap = <String, List<Map<String, dynamic>>>{};
    for (final item in teams) {
      if (item is Map<String, dynamic>) {
        final id = item['tournamentId'] as String? ?? '';
        teamMap.putIfAbsent(id, () => []).add(item);
        final teamId = item['id'] as String?;
        if (teamId == null || !_uuidRegex.hasMatch(teamId)) {
          errors.add('tournament team id invalid.');
        }
      }
    }
    for (final item in tournaments) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id'] as String? ?? '';
      if (id.isEmpty || !_uuidRegex.hasMatch(id)) {
        errors.add('tournament id invalid.');
      }
      final mode = MatchModeJson.fromJson(item['mode'] as String? ?? '1V1');
      final teamList = teamMap[id] ?? [];
      if (teamList.length < 2) {
        errors.add('tournament $id must have at least 2 teams.');
        continue;
      }
      for (final team in teamList) {
        final players = team['playerIds'];
        if (players is! List || players.isEmpty || players.length > 2) {
          errors.add('tournament team size invalid.');
          continue;
        }
        if (mode == MatchMode.oneVOne && players.length != 1) {
          errors.add('tournament team size mismatch.');
        }
      }
    }
  }

  static void _validateRatingEvents(Object? events, List<String> errors) {
    if (events == null) return;
    if (events is! List<dynamic>) {
      errors.add('ratingEvents must be a list.');
      return;
    }
    for (final item in events) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id'] as String?;
      if (id == null || !_uuidRegex.hasMatch(id)) {
        errors.add('ratingEvent id invalid.');
      }
    }
  }
}

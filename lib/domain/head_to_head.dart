import 'enums.dart';

class HeadToHeadKey {
  HeadToHeadKey({
    required this.mode,
    required this.ids,
  });

  final MatchMode mode;
  final List<String> ids;

  factory HeadToHeadKey.for1v1(String aId, String bId) {
    final ids = [aId, bId]..sort();
    return HeadToHeadKey(mode: MatchMode.oneVOne, ids: ids);
  }

  factory HeadToHeadKey.for2v2(
    String aId,
    String bId,
    String cId,
    String dId,
  ) {
    final pair1 = [aId, bId]..sort();
    final pair2 = [cId, dId]..sort();
    final leftKey = '${pair1[0]}_${pair1[1]}';
    final rightKey = '${pair2[0]}_${pair2[1]}';
    final ordered = leftKey.compareTo(rightKey) <= 0
        ? [...pair1, ...pair2]
        : [...pair2, ...pair1];
    return HeadToHeadKey(mode: MatchMode.twoVTwo, ids: ordered);
  }

  String toCacheKey() {
    final prefix = mode == MatchMode.oneVOne ? '1V1' : '2V2';
    return '$prefix:${ids.join('_')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.toJson(),
      'ids': ids,
    };
  }

  factory HeadToHeadKey.fromJson(Map<String, dynamic> json) {
    return HeadToHeadKey(
      mode: MatchModeJson.fromJson(json['mode'] as String),
      ids: (json['ids'] as List<dynamic>).cast<String>(),
    );
  }
}

class HeadToHeadMatchSummary {
  HeadToHeadMatchSummary({
    required this.matchId,
    required this.playedAt,
    required this.scoreSide1,
    required this.scoreSide2,
    required this.resultForSide1,
    required this.tournamentId,
  });

  final String matchId;
  final DateTime playedAt;
  final int scoreSide1;
  final int scoreSide2;
  final String resultForSide1;
  final String? tournamentId;

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'playedAt': playedAt.toIso8601String(),
      'scoreSide1': scoreSide1,
      'scoreSide2': scoreSide2,
      'resultForSide1': resultForSide1,
      'tournamentId': tournamentId,
    };
  }

  factory HeadToHeadMatchSummary.fromJson(Map<String, dynamic> json) {
    return HeadToHeadMatchSummary(
      matchId: json['matchId'] as String,
      playedAt: DateTime.parse(json['playedAt'] as String),
      scoreSide1: json['scoreSide1'] as int,
      scoreSide2: json['scoreSide2'] as int,
      resultForSide1: json['resultForSide1'] as String,
      tournamentId: json['tournamentId'] as String?,
    );
  }
}

class HeadToHeadStats {
  HeadToHeadStats({
    required this.key,
    required this.computedAt,
    required this.totalMatches,
    required this.winsSide1,
    required this.draws,
    required this.winsSide2,
    required this.goalsForSide1,
    required this.goalsAgainstSide1,
    required this.recentMatches,
  });

  final HeadToHeadKey key;
  final DateTime computedAt;
  final int totalMatches;
  final int winsSide1;
  final int draws;
  final int winsSide2;
  final int goalsForSide1;
  final int goalsAgainstSide1;
  final List<HeadToHeadMatchSummary> recentMatches;

  Map<String, dynamic> toJson() {
    return {
      'key': key.toJson(),
      'computedAt': computedAt.toIso8601String(),
      'totalMatches': totalMatches,
      'winsSide1': winsSide1,
      'draws': draws,
      'winsSide2': winsSide2,
      'goalsForSide1': goalsForSide1,
      'goalsAgainstSide1': goalsAgainstSide1,
      'recentMatches': recentMatches.map((item) => item.toJson()).toList(),
    };
  }

  factory HeadToHeadStats.fromJson(Map<String, dynamic> json) {
    return HeadToHeadStats(
      key: HeadToHeadKey.fromJson(json['key'] as Map<String, dynamic>),
      computedAt: DateTime.parse(json['computedAt'] as String),
      totalMatches: json['totalMatches'] as int,
      winsSide1: json['winsSide1'] as int,
      draws: json['draws'] as int,
      winsSide2: json['winsSide2'] as int,
      goalsForSide1: json['goalsForSide1'] as int,
      goalsAgainstSide1: json['goalsAgainstSide1'] as int,
      recentMatches: (json['recentMatches'] as List<dynamic>)
          .map((item) =>
              HeadToHeadMatchSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

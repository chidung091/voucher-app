import '../domain/elo_config.dart';
import '../domain/player.dart';
import '../domain/player_rating.dart';

class PlayerEloEntry {
  PlayerEloEntry({required this.player, required this.elo});

  final Player player;
  final int elo;
}

class TeamBalanceResult {
  TeamBalanceResult({required this.teams, required this.teamTotals});

  final List<List<PlayerEloEntry>> teams;
  final List<int> teamTotals;
}

class TeamBalancer {
  TeamBalanceResult balanceFor1v1(List<PlayerEloEntry> pool) {
    if (pool.length < 2) {
      throw ArgumentError('Need at least 2 players for 1v1 tournament.');
    }
    final sorted = [...pool]..sort(_byId);
    return TeamBalanceResult(
      teams: [
        for (final entry in sorted) [entry]
      ],
      teamTotals: [for (final entry in sorted) entry.elo],
    );
  }

  TeamBalanceResult balanceFor2v2(
    List<PlayerEloEntry> pool, {
    String? forceSoloPlayerId,
  }) {
    if (pool.length < 3) {
      throw ArgumentError('Need at least 3 players for team tournament.');
    }
    final sorted = [...pool]..sort(_byId);
    if (sorted.length.isOdd) {
      if (forceSoloPlayerId != null) {
        final soloIndex =
            sorted.indexWhere((e) => e.player.id == forceSoloPlayerId);
        if (soloIndex != -1) {
          final solo = sorted[soloIndex];
          final remaining = [...sorted]..removeAt(soloIndex);
          final pairing = _bestPairing(remaining);
          return _buildResult(pairing, solo);
        }
      }

      final mixed = _bestMixedPairing(sorted);
      return _buildResult(mixed.teams, mixed.solo);
    }
    final pairing = _bestPairing(sorted);
    return _buildResult(pairing, null);
  }

  TeamBalanceResult _buildResult(
    List<List<PlayerEloEntry>> pairs,
    PlayerEloEntry? solo,
  ) {
    final teams = <List<PlayerEloEntry>>[
      for (final pair in pairs) [...pair],
      if (solo != null) [solo],
    ];
    teams.sort((a, b) => _teamSignature(a).compareTo(_teamSignature(b)));
    final totals = teams
        .map((team) => team.map((entry) => entry.elo).reduce((a, b) => a + b))
        .toList();
    return TeamBalanceResult(teams: teams, teamTotals: totals);
  }

  _MixedPairingResult _bestMixedPairing(List<PlayerEloEntry> players) {
    _MixedPairingResult? best;
    for (var i = 0; i < players.length; i++) {
      final solo = players[i];
      final remaining = [
        for (var j = 0; j < players.length; j++)
          if (j != i) players[j],
      ];
      final pairs = _bestPairing(remaining);
      final totals = [
        for (final pair in pairs) pair[0].elo + pair[1].elo,
        solo.elo,
      ];
      totals.sort();
      final range = totals.last - totals.first;
      final variance = _varianceTotals(totals);
      final signature = _mixedSignature(pairs, solo);
      final candidate = _MixedPairingResult(
        teams: pairs,
        solo: solo,
        range: range,
        variance: variance,
        signature: signature,
      );
      if (best == null || candidate.compareTo(best) < 0) {
        best = candidate;
      }
    }
    return best!;
  }

  List<List<PlayerEloEntry>> _bestPairing(List<PlayerEloEntry> players) {
    final pairings = <List<List<PlayerEloEntry>>>[];
    final used = List<bool>.filled(players.length, false);

    final targetPairs = players.length ~/ 2;
    void backtrack(List<List<PlayerEloEntry>> current) {
      if (current.length == targetPairs) {
        pairings.add(current.map((pair) => [...pair]).toList());
        return;
      }
      int first = -1;
      for (var i = 0; i < players.length; i++) {
        if (!used[i]) {
          first = i;
          break;
        }
      }
      used[first] = true;
      for (var j = first + 1; j < players.length; j++) {
        if (!used[j]) {
          used[j] = true;
          current.add([players[first], players[j]]);
          backtrack(current);
          current.removeLast();
          used[j] = false;
        }
      }
      used[first] = false;
    }

    backtrack([]);

    pairings.sort((a, b) {
      final scoreA = _pairingScore(a);
      final scoreB = _pairingScore(b);
      if (scoreA != scoreB) return scoreA.compareTo(scoreB);
      final varianceA = _variance(a);
      final varianceB = _variance(b);
      if (varianceA != varianceB) return varianceA.compareTo(varianceB);
      return _pairingLex(a, b);
    });
    return pairings.first;
  }

  int _pairingScore(List<List<PlayerEloEntry>> pairing) {
    final totals = pairing.map((pair) => pair[0].elo + pair[1].elo).toList()
      ..sort();
    return totals.last - totals.first;
  }

  double _variance(List<List<PlayerEloEntry>> pairing) {
    final totals = pairing.map((pair) => pair[0].elo + pair[1].elo).toList();
    return _varianceTotals(totals);
  }

  double _varianceTotals(List<int> totals) {
    final avg = totals.reduce((a, b) => a + b) / totals.length;
    final variance = totals
        .map((value) => (value - avg) * (value - avg))
        .reduce((a, b) => a + b);
    return variance;
  }

  int _pairingLex(
    List<List<PlayerEloEntry>> a,
    List<List<PlayerEloEntry>> b,
  ) {
    final aPairs = _pairingSignature(a);
    final bPairs = _pairingSignature(b);
    for (var i = 0; i < aPairs.length; i++) {
      final diff = aPairs[i].compareTo(bPairs[i]);
      if (diff != 0) return diff;
    }
    return 0;
  }

  List<String> _pairingSignature(List<List<PlayerEloEntry>> pairing) {
    final pairs = pairing.map((pair) {
      final ids = [pair[0].player.id, pair[1].player.id]..sort();
      return ids.join('-');
    }).toList()
      ..sort();
    return pairs;
  }

  String _mixedSignature(
    List<List<PlayerEloEntry>> pairing,
    PlayerEloEntry solo,
  ) {
    final pairs = _pairingSignature(pairing);
    return '${solo.player.id}|${pairs.join(',')}';
  }

  String _teamSignature(List<PlayerEloEntry> team) {
    final ids = team.map((entry) => entry.player.id).toList()..sort();
    return ids.join('-');
  }

  int _byId(PlayerEloEntry a, PlayerEloEntry b) {
    return a.player.id.compareTo(b.player.id);
  }

  static List<PlayerEloEntry> buildPool(
    List<Player> players,
    Map<String, PlayerRating> ratings,
  ) {
    return players.map((player) {
      final rating = ratings[player.id];
      final elo = rating?.elo ?? EloConfig.defaultElo;
      return PlayerEloEntry(player: player, elo: elo);
    }).toList();
  }
}

class _MixedPairingResult {
  _MixedPairingResult({
    required this.teams,
    required this.solo,
    required this.range,
    required this.variance,
    required this.signature,
  });

  final List<List<PlayerEloEntry>> teams;
  final PlayerEloEntry solo;
  final int range;
  final double variance;
  final String signature;

  int compareTo(_MixedPairingResult other) {
    final rangeDiff = range.compareTo(other.range);
    if (rangeDiff != 0) return rangeDiff;
    final varianceDiff = variance.compareTo(other.variance);
    if (varianceDiff != 0) return varianceDiff;
    return signature.compareTo(other.signature);
  }
}

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
    if (pool.length < 3) {
      throw ArgumentError('Need at least 3 players for 1v1 tournament.');
    }
    final sorted = [...pool]..sort(_byId);
    final best = _selectClosestRange(sorted, 3);
    return TeamBalanceResult(
      teams: [
        [best[0]],
        [best[1]],
        [best[2]],
      ],
      teamTotals: [best[0].elo, best[1].elo, best[2].elo],
    );
  }

  TeamBalanceResult balanceFor2v2(List<PlayerEloEntry> pool) {
    if (pool.length < 6) {
      throw ArgumentError('Need at least 6 players for 2v2 tournament.');
    }
    final sorted = [...pool]..sort(_byId);
    final chosen = _selectClosestRange(sorted, 6);
    final pairing = _bestPairing(chosen);
    final totals = pairing
        .map((pair) => pair[0].elo + pair[1].elo)
        .toList();
    return TeamBalanceResult(teams: pairing, teamTotals: totals);
  }

  List<PlayerEloEntry> _selectClosestRange(
    List<PlayerEloEntry> sorted,
    int count,
  ) {
    if (sorted.length == count) return sorted;
    final combos = <List<PlayerEloEntry>>[];
    void dfs(int start, List<PlayerEloEntry> current) {
      if (current.length == count) {
        combos.add([...current]);
        return;
      }
      for (var i = start; i < sorted.length; i++) {
        current.add(sorted[i]);
        dfs(i + 1, current);
        current.removeLast();
      }
    }

    dfs(0, []);
    combos.sort((a, b) {
      final rangeA = _range(a);
      final rangeB = _range(b);
      if (rangeA != rangeB) return rangeA.compareTo(rangeB);
      return _lexCompare(a, b);
    });
    return combos.first;
  }

  List<List<PlayerEloEntry>> _bestPairing(List<PlayerEloEntry> players) {
    final pairings = <List<List<PlayerEloEntry>>>[];
    final used = List<bool>.filled(players.length, false);

    void backtrack(List<List<PlayerEloEntry>> current) {
      if (current.length == 3) {
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
    final totals = pairing
        .map((pair) => pair[0].elo + pair[1].elo)
        .toList()
      ..sort();
    return totals.last - totals.first;
  }

  int _range(List<PlayerEloEntry> players) {
    final elos = players.map((e) => e.elo).toList()..sort();
    return elos.last - elos.first;
  }

  double _variance(List<List<PlayerEloEntry>> pairing) {
    final totals = pairing.map((pair) => pair[0].elo + pair[1].elo).toList();
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

  int _lexCompare(List<PlayerEloEntry> a, List<PlayerEloEntry> b) {
    final aIds = a.map((e) => e.player.id).toList();
    final bIds = b.map((e) => e.player.id).toList();
    for (var i = 0; i < aIds.length; i++) {
      final diff = aIds[i].compareTo(bIds[i]);
      if (diff != 0) return diff;
    }
    return 0;
  }

  int _byId(PlayerEloEntry a, PlayerEloEntry b) {
    return a.player.id.compareTo(b.player.id);
  }

  static List<PlayerEloEntry> buildPool(
    List<Player> players,
    Map<String, PlayerRating> ratings,
  ) {
    return players
        .map((player) {
          final rating = ratings[player.id];
          final elo = rating?.elo ??
              EloConfig.initialEloForSkill(player.skillLevel);
          return PlayerEloEntry(player: player, elo: elo);
        })
        .toList();
  }
}

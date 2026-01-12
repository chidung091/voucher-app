import 'package:uuid/uuid.dart';

import '../data/local_store.dart';
import '../domain/elo_config.dart';
import '../domain/player.dart';
import '../domain/player_rating.dart';

class PlayerService {
  PlayerService(this._store, this._uuid);

  final LocalStore _store;
  final Uuid _uuid;

  static Future<PlayerService> create() async {
    return PlayerService(await LocalStore.getInstance(), const Uuid());
  }

  Future<Player> createPlayer(String displayName, {int skillLevel = 2}) async {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('displayName is required');
    }
    if (skillLevel < 1 || skillLevel > 3) {
      throw ArgumentError('skillLevel must be 1, 2, or 3');
    }
    final now = DateTime.now();
    final player = Player(
      id: _uuid.v4(),
      displayName: trimmed,
      skillLevel: skillLevel,
      createdAt: now,
      updatedAt: now,
    );

    return _store.writeTransaction(() async {
      final players = await _store.getPlayers();
      final ratings = await _store.getRatings();
      players.add(player);
      await _store.savePlayers(players);
      ratings[player.id] = PlayerRating(
        playerId: player.id,
        elo: EloConfig.initialEloForSkill(skillLevel),
        gamesPlayed: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        updatedAt: DateTime.now(),
      );
      await _store.saveRatings(ratings);
      return player;
    });
  }

  Future<List<Player>> listPlayers({bool includeDeleted = false}) async {
    final players = await _store.getPlayers();
    if (includeDeleted) return players;
    return players.where((player) => player.deletedAt == null).toList();
  }

  Future<Player> updatePlayer(
    String id,
    String displayName, {
    int? skillLevel,
  }) async {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('displayName is required');
    }
    if (skillLevel != null && (skillLevel < 1 || skillLevel > 3)) {
      throw ArgumentError('skillLevel must be 1, 2, or 3');
    }
    return _store.writeTransaction(() async {
      final players = await _store.getPlayers();
      final index = players.indexWhere((player) => player.id == id);
      if (index == -1) {
        throw StateError('Player not found');
      }
      final updated = players[index].copyWith(
        displayName: trimmed,
        skillLevel: skillLevel ?? players[index].skillLevel,
        updatedAt: DateTime.now(),
      );
      players[index] = updated;
      await _store.savePlayers(players);
      return updated;
    });
  }

  Future<Player> softDeletePlayer(String id) async {
    return _store.writeTransaction(() async {
      final players = await _store.getPlayers();
      final index = players.indexWhere((player) => player.id == id);
      if (index == -1) {
        throw StateError('Player not found');
      }
      final updated = players[index].copyWith(
        updatedAt: DateTime.now(),
        deletedAt: DateTime.now(),
      );
      players[index] = updated;
      await _store.savePlayers(players);
      return updated;
    });
  }
}

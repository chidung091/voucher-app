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

  Future<Player> createPlayer(
    String displayName, {
    int skillLevel = 2,
    int? initialElo,
  }) async {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('displayName is required');
    }
    if (skillLevel < 1 || skillLevel > 3) {
      throw ArgumentError('skillLevel must be 1, 2, or 3');
    }
    final elo = initialElo ?? EloConfig.defaultElo;
    if (!EloConfig.isValidElo(elo)) {
      throw ArgumentError(
        'initialElo must be between ${EloConfig.minElo} and ${EloConfig.maxElo}',
      );
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
        elo: elo,
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
    int? elo,
  }) async {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('displayName is required');
    }
    if (skillLevel != null && (skillLevel < 1 || skillLevel > 3)) {
      throw ArgumentError('skillLevel must be 1, 2, or 3');
    }
    if (elo != null && !EloConfig.isValidElo(elo)) {
      throw ArgumentError(
        'elo must be between ${EloConfig.minElo} and ${EloConfig.maxElo}',
      );
    }
    return _store.writeTransaction(() async {
      final players = await _store.getPlayers();
      final index = players.indexWhere((player) => player.id == id);
      if (index == -1) {
        throw StateError('Player not found');
      }
      final current = players[index];
      final nextSkill = skillLevel ?? current.skillLevel;
      if (nextSkill != current.skillLevel) {
        final matches = await _store.getMatches();
        final hasMatch = matches.any((match) {
          return match.sideAPlayerIds.contains(id) ||
              match.sideBPlayerIds.contains(id);
        });
        if (hasMatch) {
          throw StateError('Skill level is locked after the first match.');
        }
      }
      final updated = players[index].copyWith(
        displayName: trimmed,
        skillLevel: nextSkill,
        updatedAt: DateTime.now(),
      );
      players[index] = updated;
      await _store.savePlayers(players);

      // Update ELO if provided, or reset if skill level changed
      if (elo != null || nextSkill != current.skillLevel) {
        final ratings = await _store.getRatings();
        final currentRating = ratings[id];
        final newElo = elo ?? EloConfig.defaultElo;
        ratings[id] = PlayerRating(
          playerId: id,
          elo: newElo,
          gamesPlayed: currentRating?.gamesPlayed ?? 0,
          wins: currentRating?.wins ?? 0,
          draws: currentRating?.draws ?? 0,
          losses: currentRating?.losses ?? 0,
          updatedAt: DateTime.now(),
        );
        await _store.saveRatings(ratings);
      }
      return updated;
    });
  }

  /// Updates only the ELO rating for a player without changing other fields.
  Future<PlayerRating> updatePlayerElo(String playerId, int newElo) async {
    if (!EloConfig.isValidElo(newElo)) {
      throw ArgumentError(
        'elo must be between ${EloConfig.minElo} and ${EloConfig.maxElo}',
      );
    }
    return _store.writeTransaction(() async {
      final ratings = await _store.getRatings();
      final existing = ratings[playerId];
      if (existing == null) {
        throw StateError('Player rating not found');
      }
      final updated = existing.copyWith(
        elo: newElo,
        updatedAt: DateTime.now(),
      );
      ratings[playerId] = updated;
      await _store.saveRatings(ratings);
      return updated;
    });
  }

  /// Gets all player ratings.
  Future<Map<String, PlayerRating>> getRatings() async {
    return _store.getRatings();
  }

  /// Resets all player ratings.
  ///
  /// [customElos] - Optional map of playerId -> custom ELO value.
  /// Players not in the map will be reset to [EloConfig.defaultElo].
  /// This also clears all rating events and invalidates caches.
  Future<void> resetAllRatings({Map<String, int>? customElos}) async {
    return _store.writeTransaction(() async {
      final players = await _store.getPlayers();
      final activePlayers = players.where((p) => p.deletedAt == null).toList();

      final now = DateTime.now();
      final newRatings = <String, PlayerRating>{};

      for (final player in activePlayers) {
        final customElo = customElos?[player.id];
        final elo = customElo ?? EloConfig.defaultElo;

        // Validate custom ELO if provided
        if (customElo != null && !EloConfig.isValidElo(customElo)) {
          throw ArgumentError(
            'ELO for ${player.displayName} must be between ${EloConfig.minElo} and ${EloConfig.maxElo}',
          );
        }

        newRatings[player.id] = PlayerRating(
          playerId: player.id,
          elo: elo,
          gamesPlayed: 0,
          wins: 0,
          draws: 0,
          losses: 0,
          updatedAt: now,
        );
      }

      await _store.saveRatings(newRatings);
      await _store.saveRatingEvents([]);
      await _store.clearPlayerStatsCache();
      await _store.clearSeasonCache();
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

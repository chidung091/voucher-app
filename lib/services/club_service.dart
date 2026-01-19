import 'package:uuid/uuid.dart';

import '../data/local_store.dart';
import '../domain/club.dart';

class ClubService {
  ClubService(this._store, this._uuid);

  final LocalStore _store;
  final Uuid _uuid;

  static Future<ClubService> create() async {
    return ClubService(await LocalStore.getInstance(), const Uuid());
  }

  Future<Club> createClub(String name, double stars) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('name is required');
    }
    _validateStars(stars);
    final now = DateTime.now();
    final club = Club(
      id: _uuid.v4(),
      name: trimmed,
      stars: stars,
      createdAt: now,
      updatedAt: now,
    );

    return _store.writeTransaction(() async {
      final clubs = await _store.getClubs();
      clubs.add(club);
      await _store.saveClubs(clubs);
      return club;
    });
  }

  Future<List<Club>> listClubs({bool includeDeleted = false}) async {
    final clubs = await _store.getClubs();
    if (includeDeleted) return clubs;
    return clubs.where((club) => club.deletedAt == null).toList();
  }

  Future<Club> updateClub(
    String id,
    String name,
    double stars,
  ) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('name is required');
    }
    _validateStars(stars);

    return _store.writeTransaction(() async {
      final clubs = await _store.getClubs();
      final index = clubs.indexWhere((club) => club.id == id);
      if (index == -1) {
        throw StateError('Club not found');
      }
      final updated = clubs[index].copyWith(
        name: trimmed,
        stars: stars,
        updatedAt: DateTime.now(),
      );
      clubs[index] = updated;
      await _store.saveClubs(clubs);
      return updated;
    });
  }

  Future<Club> deleteClub(String id) async {
    return _store.writeTransaction(() async {
      final clubs = await _store.getClubs();
      final index = clubs.indexWhere((club) => club.id == id);
      if (index == -1) {
        throw StateError('Club not found');
      }
      final updated = clubs[index].copyWith(
        updatedAt: DateTime.now(),
        deletedAt: DateTime.now(),
      );
      clubs[index] = updated;
      await _store.saveClubs(clubs);
      return updated;
    });
  }

  void _validateStars(double stars) {
    if (stars < 1.0 || stars > 5.0) {
      throw ArgumentError('stars must be between 1.0 and 5.0');
    }
    final scaled = stars * 2;
    if ((scaled - scaled.round()).abs() > 0.0001) {
      throw ArgumentError('stars must be in 0.5 increments');
    }
  }
}

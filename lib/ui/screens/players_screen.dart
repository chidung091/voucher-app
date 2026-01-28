import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../domain/elo_config.dart';
import '../../domain/player.dart';
import '../../domain/player_rating.dart';
import '../../services/player_service.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _eloController = TextEditingController();
  int _skillLevel = 2;
  late Future<PlayerService> _serviceFuture;
  List<Player> _players = [];
  Map<String, PlayerRating> _ratings = {};

  @override
  void initState() {
    super.initState();
    _eloController.text = EloConfig.defaultElo.toString();
    _serviceFuture = PlayerService.create();
    _serviceFuture.then(_load);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _eloController.dispose();
    super.dispose();
  }

  Future<void> _load(PlayerService service) async {
    final players = await service.listPlayers();
    final ratings = await service.getRatings();
    setState(() {
      _players = players;
      _ratings = ratings;
    });
  }

  Future<void> _add(PlayerService service) async {
    final elo = int.tryParse(_eloController.text) ?? EloConfig.defaultElo;
    try {
      await service.createPlayer(
        _nameController.text,
        skillLevel: _skillLevel,
        initialElo: elo,
      );
      _nameController.clear();
      _eloController.text = EloConfig.defaultElo.toString();
      await _load(service);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _edit(PlayerService service, Player player) async {
    final nameController = TextEditingController(text: player.displayName);
    final currentRating = _ratings[player.id];
    final eloController = TextEditingController(
      text: (currentRating?.elo ?? EloConfig.defaultElo).toString(),
    );
    var selectedSkill = player.skillLevel;

    final result = await showDialog<_EditResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit player'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: eloController,
              decoration: InputDecoration(
                labelText: 'ELO Rating',
                helperText: '${EloConfig.minElo} - ${EloConfig.maxElo}',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: selectedSkill,
              decoration: const InputDecoration(labelText: 'Skill level'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 · Strong')),
                DropdownMenuItem(value: 2, child: Text('2 · Medium')),
                DropdownMenuItem(value: 3, child: Text('3 · Beginner')),
              ],
              onChanged: (value) {
                if (value != null) {
                  selectedSkill = value;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              _EditResult(
                nameController.text,
                selectedSkill,
                int.tryParse(eloController.text),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      try {
        await service.updatePlayer(
          player.id,
          result.name,
          skillLevel: result.skillLevel,
          elo: result.elo,
        );
        await _load(service);
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _delete(PlayerService service, Player player) async {
    await service.softDeletePlayer(player.id);
    await _load(service);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlayerService>(
      future: _serviceFuture,
      builder: (context, snapshot) {
        final service = snapshot.data;
        if (service == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Players',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Player name',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _add(service),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _eloController,
                    decoration: const InputDecoration(
                      labelText: 'ELO',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (_) => _add(service),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _skillLevel,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('L1')),
                    DropdownMenuItem(value: 2, child: Text('L2')),
                    DropdownMenuItem(value: 3, child: Text('L3')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _skillLevel = value);
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _add(service),
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_players.isEmpty)
              const Text('No players yet.')
            else
              ..._players.map(
                (player) {
                  final rating = _ratings[player.id];
                  final eloDisplay = rating?.elo ?? EloConfig.defaultElo;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(player.displayName),
                      subtitle: Text('ELO: $eloDisplay'),
                      leading: Chip(
                        label: Text('L${player.skillLevel}'),
                      ),
                      onTap: () => context.go('/players/${player.id}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _edit(service, player),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () => _delete(service, player),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _load(service),
              child: const Text('Refresh'),
            ),
          ],
        );
      },
    );
  }
}

class _EditResult {
  const _EditResult(this.name, this.skillLevel, this.elo);

  final String name;
  final int skillLevel;
  final int? elo;
}

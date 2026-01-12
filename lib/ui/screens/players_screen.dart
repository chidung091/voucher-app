import 'package:flutter/material.dart';

import '../../domain/player.dart';
import '../../services/player_service.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final TextEditingController _controller = TextEditingController();
  int _skillLevel = 2;
  late Future<PlayerService> _serviceFuture;
  List<Player> _players = [];

  @override
  void initState() {
    super.initState();
    _serviceFuture = PlayerService.create();
    _serviceFuture.then(_load);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load(PlayerService service) async {
    final players = await service.listPlayers();
    setState(() => _players = players);
  }

  Future<void> _add(PlayerService service) async {
    await service.createPlayer(_controller.text, skillLevel: _skillLevel);
    _controller.clear();
    await _load(service);
  }

  Future<void> _edit(PlayerService service, Player player) async {
    final controller = TextEditingController(text: player.displayName);
    var selectedSkill = player.skillLevel;
    final result = await showDialog<_EditResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit player'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Display name'),
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
              _EditResult(controller.text, selectedSkill),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      await service.updatePlayer(
        player.id,
        result.name,
        skillLevel: result.skillLevel,
      );
      await _load(service);
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
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Player name',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _add(service),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _skillLevel,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 · Strong')),
                    DropdownMenuItem(value: 2, child: Text('2 · Medium')),
                    DropdownMenuItem(value: 3, child: Text('3 · Beginner')),
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
                (player) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(player.displayName),
                    subtitle: Text('ID: ${player.id.substring(0, 6)}'),
                    leading: Chip(
                      label: Text('L${player.skillLevel}'),
                    ),
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
                ),
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
  const _EditResult(this.name, this.skillLevel);

  final String name;
  final int skillLevel;
}

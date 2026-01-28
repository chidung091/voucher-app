import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../domain/elo_config.dart';
import '../../domain/player.dart';
import '../../domain/player_rating.dart';
import '../../services/player_service.dart';

class EloResetScreen extends StatefulWidget {
  const EloResetScreen({super.key});

  @override
  State<EloResetScreen> createState() => _EloResetScreenState();
}

class _EloResetScreenState extends State<EloResetScreen> {
  late Future<PlayerService> _serviceFuture;
  List<Player> _players = [];
  Map<String, PlayerRating> _ratings = {};
  Map<String, TextEditingController> _controllers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _serviceFuture = PlayerService.create();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final service = await _serviceFuture;
    final players = await service.listPlayers();
    final ratings = await service.getRatings();

    // Dispose old controllers
    for (final controller in _controllers.values) {
      controller.dispose();
    }

    // Create new controllers
    final controllers = <String, TextEditingController>{};
    for (final player in players) {
      final currentElo = ratings[player.id]?.elo ?? EloConfig.defaultElo;
      controllers[player.id] =
          TextEditingController(text: currentElo.toString());
    }

    setState(() {
      _players = players;
      _ratings = ratings;
      _controllers = controllers;
      _isLoading = false;
    });
  }

  void _setAllToDefault() {
    for (final controller in _controllers.values) {
      controller.text = EloConfig.defaultElo.toString();
    }
  }

  void _resetToCurrentElo(String playerId) {
    final currentElo = _ratings[playerId]?.elo ?? EloConfig.defaultElo;
    _controllers[playerId]?.text = currentElo.toString();
  }

  Future<void> _confirmAndReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All ELO Ratings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will reset all player ratings and clear match history from ELO calculations.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('• All wins/draws/losses will be reset to 0'),
            Text('• Rating events will be cleared'),
            Text('• Season and player stats caches will be invalidated'),
            SizedBox(height: 12),
            Text(
              'This action cannot be undone!',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Build custom ELOs map
    final customElos = <String, int>{};
    for (final player in _players) {
      final text = _controllers[player.id]?.text ?? '';
      final elo = int.tryParse(text);
      if (elo != null && EloConfig.isValidElo(elo)) {
        customElos[player.id] = elo;
      }
    }

    try {
      final service = await _serviceFuture;
      await service.resetAllRatings(customElos: customElos);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All ELO ratings have been reset!'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reset failed: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset ELO Ratings'),
        actions: [
          TextButton.icon(
            onPressed: _setAllToDefault,
            icon: const Icon(Icons.restart_alt),
            label: Text('All to ${EloConfig.defaultElo}'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _players.isEmpty
              ? const Center(child: Text('No players found.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Set custom ELO values below, then tap Reset to apply.',
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Players (${_players.length})',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ..._players.map((player) => _PlayerEloRow(
                          player: player,
                          currentElo:
                              _ratings[player.id]?.elo ?? EloConfig.defaultElo,
                          controller: _controllers[player.id]!,
                          onResetToCurrent: () => _resetToCurrentElo(player.id),
                        )),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _confirmAndReset,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset All Ratings'),
                    ),
                  ],
                ),
    );
  }
}

class _PlayerEloRow extends StatelessWidget {
  const _PlayerEloRow({
    required this.player,
    required this.currentElo,
    required this.controller,
    required this.onResetToCurrent,
  });

  final Player player;
  final int currentElo;
  final TextEditingController controller;
  final VoidCallback onResetToCurrent;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.displayName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    'Current: $currentElo',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 100,
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'New ELO',
                  border: const OutlineInputBorder(),
                  helperText: '${EloConfig.minElo}-${EloConfig.maxElo}',
                  helperStyle: const TextStyle(fontSize: 10),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            IconButton(
              onPressed: onResetToCurrent,
              icon: const Icon(Icons.undo),
              tooltip: 'Reset to current',
            ),
          ],
        ),
      ),
    );
  }
}

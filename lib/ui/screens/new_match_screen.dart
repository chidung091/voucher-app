import 'package:flutter/material.dart';

import '../../domain/enums.dart';
import '../../domain/player.dart';
import '../../services/match_service.dart';
import '../../services/player_service.dart';

class NewMatchScreen extends StatefulWidget {
  const NewMatchScreen({super.key});

  @override
  State<NewMatchScreen> createState() => _NewMatchScreenState();
}

class _NewMatchScreenState extends State<NewMatchScreen> {
  MatchMode _mode = MatchMode.oneVOne;
  MatchRatingMode _ratingMode = MatchRatingMode.ranked;
  List<Player> _players = [];
  String? _sideA1;
  String? _sideA2;
  String? _sideB1;
  String? _sideB2;
  final TextEditingController _scoreA = TextEditingController(text: '0');
  final TextEditingController _scoreB = TextEditingController(text: '0');
  final TextEditingController _customMultiplierController =
      TextEditingController(text: '1.0');
  bool _useCustomMultiplier = false;
  late Future<PlayerService> _playerServiceFuture;
  late Future<MatchService> _matchServiceFuture;
  String? _error;

  @override
  void initState() {
    super.initState();
    _playerServiceFuture = PlayerService.create();
    _matchServiceFuture = MatchService.create();
    _loadPlayers();
  }

  @override
  void dispose() {
    _scoreA.dispose();
    _scoreB.dispose();
    _customMultiplierController.dispose();
    super.dispose();
  }

  Future<void> _loadPlayers() async {
    final service = await _playerServiceFuture;
    final players = await service.listPlayers();
    setState(() => _players = players);
  }

  Future<void> _saveMatch() async {
    try {
      final matchService = await _matchServiceFuture;
      final sideA = [_sideA1, if (_mode == MatchMode.twoVTwo) _sideA2]
          .whereType<String>()
          .toList();
      final sideB = [_sideB1, if (_mode == MatchMode.twoVTwo) _sideB2]
          .whereType<String>()
          .toList();
      if (sideA.isEmpty || sideB.isEmpty) {
        setState(() => _error = 'Select players for both sides.');
        return;
      }
      final scoreA = int.tryParse(_scoreA.text) ?? 0;
      final scoreB = int.tryParse(_scoreB.text) ?? 0;

      final multiplier = _effectiveMultiplier();

      await matchService.createMatch(
        MatchInput(
          mode: _mode,
          sideAPlayerIds: sideA,
          sideBPlayerIds: sideB,
          scoreA: scoreA,
          scoreB: scoreB,
          playedAt: DateTime.now(),
          ratingMode: _ratingMode,
          eloMultiplier: multiplier,
        ),
      );

      setState(() {
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Match saved')),
      );
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    }
  }

  double _effectiveMultiplier() {
    if (_useCustomMultiplier) {
      final parsed = double.tryParse(_customMultiplierController.text);
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }
    return _ratingMode.defaultMultiplier();
  }

  @override
  Widget build(BuildContext context) {
    final playerItems = _players
        .map((player) => DropdownMenuItem(
              value: player.id,
              child: Text(player.displayName),
            ))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'New Match',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<MatchMode>(
          value: _mode,
          items: const [
            DropdownMenuItem(
              value: MatchMode.oneVOne,
              child: Text('1v1'),
            ),
            DropdownMenuItem(
              value: MatchMode.twoVTwo,
              child: Text('2v2'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _mode = value);
          },
          decoration: const InputDecoration(
            labelText: 'Mode',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<MatchRatingMode>(
          value: _ratingMode,
          items: const [
            DropdownMenuItem(
              value: MatchRatingMode.friendly,
              child: Text('Friendly'),
            ),
            DropdownMenuItem(
              value: MatchRatingMode.ranked,
              child: Text('Ranked'),
            ),
            DropdownMenuItem(
              value: MatchRatingMode.tournament,
              child: Text('Tournament'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _ratingMode = value;
              if (!_useCustomMultiplier) {
                _customMultiplierController.text =
                    _ratingMode.defaultMultiplier().toStringAsFixed(1);
              }
            });
          },
          decoration: const InputDecoration(
            labelText: 'Rating mode',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Multiplier: ${_effectiveMultiplier().toStringAsFixed(1)}x',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Custom multiplier'),
          value: _useCustomMultiplier,
          onChanged: (value) {
            setState(() => _useCustomMultiplier = value);
          },
        ),
        if (_useCustomMultiplier) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _customMultiplierController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Elo multiplier',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text('Side A', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _sideA1,
          items: playerItems,
          onChanged: (value) => setState(() => _sideA1 = value),
          decoration: const InputDecoration(
            labelText: 'Player 1',
            border: OutlineInputBorder(),
          ),
        ),
        if (_mode == MatchMode.twoVTwo) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _sideA2,
            items: playerItems,
            onChanged: (value) => setState(() => _sideA2 = value),
            decoration: const InputDecoration(
              labelText: 'Player 2',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text('Side B', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _sideB1,
          items: playerItems,
          onChanged: (value) => setState(() => _sideB1 = value),
          decoration: const InputDecoration(
            labelText: 'Player 1',
            border: OutlineInputBorder(),
          ),
        ),
        if (_mode == MatchMode.twoVTwo) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _sideB2,
            items: playerItems,
            onChanged: (value) => setState(() => _sideB2 = value),
            decoration: const InputDecoration(
              labelText: 'Player 2',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _scoreA,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Score A',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _scoreB,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Score B',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saveMatch,
          child: const Text('Save Match'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _loadPlayers,
          child: const Text('Reload players'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/enums.dart';
import '../../domain/player.dart';
import '../../services/match_service.dart';
import '../../services/player_service.dart';
import '../components/components.dart';

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
  bool _isSaving = false;

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
    setState(() => _isSaving = true);
    try {
      final matchService = await _matchServiceFuture;
      final sideA = [_sideA1, if (_mode == MatchMode.twoVTwo) _sideA2]
          .whereType<String>()
          .toList();
      final sideB = [_sideB1, if (_mode == MatchMode.twoVTwo) _sideB2]
          .whereType<String>()
          .toList();
      if (sideA.isEmpty || sideB.isEmpty) {
        setState(() {
          _error = 'Select players for both sides.';
          _isSaving = false;
        });
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
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Match saved successfully!'),
              ],
            ),
          ),
        );
      }
    } catch (error) {
      setState(() {
        _error = error.toString();
        _isSaving = false;
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

  String _getPlayerName(String? id) {
    if (id == null) return '';
    final player = _players.firstWhere(
      (p) => p.id == id,
      orElse: () => Player(
        id: '',
        displayName: 'Unknown',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return player.displayName;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Match Mode & Rating Cards
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sports_soccer, color: colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Match Setup',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Match Mode Selection
              Text(
                'Match Mode',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _ModeChip(
                      label: '1v1',
                      icon: Icons.person,
                      isSelected: _mode == MatchMode.oneVOne,
                      onTap: () => setState(() => _mode = MatchMode.oneVOne),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _ModeChip(
                      label: '2v2',
                      icon: Icons.group,
                      isSelected: _mode == MatchMode.twoVTwo,
                      onTap: () => setState(() => _mode = MatchMode.twoVTwo),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Rating Mode Selection
              Text(
                'Rating Mode',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _RatingChip(
                    label: 'Friendly',
                    multiplier: 0.5,
                    isSelected: _ratingMode == MatchRatingMode.friendly,
                    onTap: () => setState(() {
                      _ratingMode = MatchRatingMode.friendly;
                      if (!_useCustomMultiplier) {
                        _customMultiplierController.text = '0.5';
                      }
                    }),
                  ),
                  _RatingChip(
                    label: 'Ranked',
                    multiplier: 1.0,
                    isSelected: _ratingMode == MatchRatingMode.ranked,
                    onTap: () => setState(() {
                      _ratingMode = MatchRatingMode.ranked;
                      if (!_useCustomMultiplier) {
                        _customMultiplierController.text = '1.0';
                      }
                    }),
                  ),
                  _RatingChip(
                    label: 'Tournament',
                    multiplier: 1.5,
                    isSelected: _ratingMode == MatchRatingMode.tournament,
                    onTap: () => setState(() {
                      _ratingMode = MatchRatingMode.tournament;
                      if (!_useCustomMultiplier) {
                        _customMultiplierController.text = '1.5';
                      }
                    }),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Multiplier display
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.speed, size: 16, color: colorScheme.primary),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Multiplier: ${_effectiveMultiplier().toStringAsFixed(1)}x',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),

              // Custom multiplier toggle
              SwitchListTile(
                title: const Text('Custom multiplier'),
                value: _useCustomMultiplier,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) =>
                    setState(() => _useCustomMultiplier = value),
              ),
              if (_useCustomMultiplier)
                CustomTextField(
                  controller: _customMultiplierController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  label: 'Custom ELO multiplier',
                  prefixIcon: const Icon(Icons.edit),
                ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Side A
        _TeamCard(
          title: 'Side A',
          color: colorScheme.primary,
          players: _players,
          player1: _sideA1,
          player2: _mode == MatchMode.twoVTwo ? _sideA2 : null,
          onPlayer1Changed: (v) => setState(() => _sideA1 = v),
          onPlayer2Changed: _mode == MatchMode.twoVTwo
              ? (v) => setState(() => _sideA2 = v)
              : null,
          showPlayer2: _mode == MatchMode.twoVTwo,
          getPlayerName: _getPlayerName,
        ),

        const SizedBox(height: AppSpacing.md),

        // VS Divider
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: const Text(
              'VS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Side B
        _TeamCard(
          title: 'Side B',
          color: colorScheme.secondary,
          players: _players,
          player1: _sideB1,
          player2: _mode == MatchMode.twoVTwo ? _sideB2 : null,
          onPlayer1Changed: (v) => setState(() => _sideB1 = v),
          onPlayer2Changed: _mode == MatchMode.twoVTwo
              ? (v) => setState(() => _sideB2 = v)
              : null,
          showPlayer2: _mode == MatchMode.twoVTwo,
          getPlayerName: _getPlayerName,
        ),

        const SizedBox(height: AppSpacing.lg),

        // Score Input
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.scoreboard_outlined, color: colorScheme.secondary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Final Score',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _ScoreInput(
                      label: 'Side A',
                      controller: _scoreA,
                      color: colorScheme.primary,
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Text(
                      '-',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  Expanded(
                    child: _ScoreInput(
                      label: 'Side B',
                      controller: _scoreB,
                      color: colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: colorScheme.error.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: colorScheme.error),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.xl),

        PrimaryButton(
          label: 'Save Match',
          icon: Icons.save,
          onPressed: _saveMatch,
          isLoading: _isSaving,
        ),

        const SizedBox(height: AppSpacing.sm),

        SecondaryButton(
          label: 'Reload Players',
          icon: Icons.refresh,
          onPressed: _loadPlayers,
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.2)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? colorScheme.primary : Colors.white60,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? colorScheme.primary : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({
    required this.label,
    required this.multiplier,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final double multiplier;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.secondary.withOpacity(0.2)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isSelected ? colorScheme.secondary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? colorScheme.secondary : Colors.white60,
              ),
            ),
            Text(
              '${multiplier}x',
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? colorScheme.secondary.withOpacity(0.8)
                    : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.title,
    required this.color,
    required this.players,
    required this.player1,
    required this.player2,
    required this.onPlayer1Changed,
    required this.onPlayer2Changed,
    required this.showPlayer2,
    required this.getPlayerName,
  });

  final String title;
  final Color color;
  final List<Player> players;
  final String? player1;
  final String? player2;
  final void Function(String?) onPlayer1Changed;
  final void Function(String?)? onPlayer2Changed;
  final bool showPlayer2;
  final String Function(String?) getPlayerName;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownField<String>(
            value: player1,
            items: players.map((p) => p.id).toList(),
            itemBuilder: (id) => Text(getPlayerName(id)),
            onSelected: onPlayer1Changed,
            label: 'Player 1',
            prefixIcon: Icon(Icons.person, color: color),
          ),
          if (showPlayer2) ...[
            const SizedBox(height: AppSpacing.md),
            DropdownField<String>(
              value: player2,
              items: players.map((p) => p.id).toList(),
              itemBuilder: (id) => Text(getPlayerName(id)),
              onSelected: (val) => onPlayer2Changed?.call(val),
              label: 'Player 2',
              prefixIcon: Icon(Icons.person, color: color),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreInput extends StatelessWidget {
  const _ScoreInput({
    required this.label,
    required this.controller,
    required this.color,
  });

  final String label;
  final TextEditingController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        CustomTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          // Note: Decoration for borders is handled by CustomTextField but custom big text needs careful check.
          // Since CustomTextField enforces standard borders, we rely on them.
        ),
      ],
    );
  }
}

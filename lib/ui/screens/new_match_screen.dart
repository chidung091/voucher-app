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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final horizontalPadding = isWide ? AppSpacing.xl : AppSpacing.md;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.md,
            horizontalPadding,
            AppSpacing.md,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MatchSetupPanel(
                    mode: _mode,
                    ratingMode: _ratingMode,
                    multiplier: _effectiveMultiplier(),
                    useCustomMultiplier: _useCustomMultiplier,
                    customMultiplierController: _customMultiplierController,
                    onModeChanged: (mode) => setState(() => _mode = mode),
                    onRatingModeChanged: (ratingMode) => setState(() {
                      _ratingMode = ratingMode;
                      if (!_useCustomMultiplier) {
                        _customMultiplierController.text =
                            ratingMode.defaultMultiplier().toStringAsFixed(1);
                      }
                    }),
                    onCustomMultiplierChanged: (value) =>
                        setState(() => _useCustomMultiplier = value),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _MatchBoard(
                    isWide: isWide,
                    mode: _mode,
                    players: _players,
                    sideA1: _sideA1,
                    sideA2: _mode == MatchMode.twoVTwo ? _sideA2 : null,
                    sideB1: _sideB1,
                    sideB2: _mode == MatchMode.twoVTwo ? _sideB2 : null,
                    scoreA: _scoreA,
                    scoreB: _scoreB,
                    onSideA1Changed: (value) => setState(() => _sideA1 = value),
                    onSideA2Changed: _mode == MatchMode.twoVTwo
                        ? (value) => setState(() => _sideA2 = value)
                        : null,
                    onSideB1Changed: (value) => setState(() => _sideB1 = value),
                    onSideB2Changed: _mode == MatchMode.twoVTwo
                        ? (value) => setState(() => _sideB2 = value)
                        : null,
                    getPlayerName: _getPlayerName,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: 'Save Match',
                          icon: Icons.save,
                          onPressed: _saveMatch,
                          isLoading: _isSaving,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Tooltip(
                        message: 'Reload Players',
                        child: IconButton.outlined(
                          onPressed: _loadPlayers,
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MatchSetupPanel extends StatelessWidget {
  const _MatchSetupPanel({
    required this.mode,
    required this.ratingMode,
    required this.multiplier,
    required this.useCustomMultiplier,
    required this.customMultiplierController,
    required this.onModeChanged,
    required this.onRatingModeChanged,
    required this.onCustomMultiplierChanged,
  });

  final MatchMode mode;
  final MatchRatingMode ratingMode;
  final double multiplier;
  final bool useCustomMultiplier;
  final TextEditingController customMultiplierController;
  final ValueChanged<MatchMode> onModeChanged;
  final ValueChanged<MatchRatingMode> onRatingModeChanged;
  final ValueChanged<bool> onCustomMultiplierChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.sports_soccer, color: colorScheme.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text('Match Setup', style: theme.textTheme.titleSmall),
              const Spacer(),
              _MultiplierPill(multiplier: multiplier),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _ModeChip(
                  label: '1v1',
                  icon: Icons.person,
                  isSelected: mode == MatchMode.oneVOne,
                  onTap: () => onModeChanged(MatchMode.oneVOne),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ModeChip(
                  label: '2v2',
                  icon: Icons.group,
                  isSelected: mode == MatchMode.twoVTwo,
                  onTap: () => onModeChanged(MatchMode.twoVTwo),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _RatingChip(
                  label: 'Friendly',
                  multiplier: 0.5,
                  isSelected: ratingMode == MatchRatingMode.friendly,
                  onTap: () => onRatingModeChanged(MatchRatingMode.friendly),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _RatingChip(
                  label: 'Ranked',
                  multiplier: 1.0,
                  isSelected: ratingMode == MatchRatingMode.ranked,
                  onTap: () => onRatingModeChanged(MatchRatingMode.ranked),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _RatingChip(
                  label: 'Tournament',
                  multiplier: 1.5,
                  isSelected: ratingMode == MatchRatingMode.tournament,
                  onTap: () => onRatingModeChanged(MatchRatingMode.tournament),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Switch(
                value: useCustomMultiplier,
                onChanged: onCustomMultiplierChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Custom multiplier',
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (useCustomMultiplier)
                SizedBox(
                  width: 86,
                  child: TextField(
                    controller: customMultiplierController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.edit, size: 16),
                      prefixIconConstraints: BoxConstraints(minWidth: 30),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MultiplierPill extends StatelessWidget {
  const _MultiplierPill({required this.multiplier});

  final double multiplier;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.speed, size: 14, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '${multiplier.toStringAsFixed(1)}x',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              size: 18,
              color: isSelected
                  ? colorScheme.primary
                  : theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? colorScheme.primary
                    : theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? colorScheme.secondary
                    : theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
            ),
            Text(
              '${multiplier}x',
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? colorScheme.secondary.withOpacity(0.8)
                    : theme.textTheme.bodySmall?.color?.withOpacity(0.38),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchBoard extends StatelessWidget {
  const _MatchBoard({
    required this.isWide,
    required this.mode,
    required this.players,
    required this.sideA1,
    required this.sideA2,
    required this.sideB1,
    required this.sideB2,
    required this.scoreA,
    required this.scoreB,
    required this.onSideA1Changed,
    required this.onSideA2Changed,
    required this.onSideB1Changed,
    required this.onSideB2Changed,
    required this.getPlayerName,
  });

  final bool isWide;
  final MatchMode mode;
  final List<Player> players;
  final String? sideA1;
  final String? sideA2;
  final String? sideB1;
  final String? sideB2;
  final TextEditingController scoreA;
  final TextEditingController scoreB;
  final ValueChanged<String?> onSideA1Changed;
  final ValueChanged<String?>? onSideA2Changed;
  final ValueChanged<String?> onSideB1Changed;
  final ValueChanged<String?>? onSideB2Changed;
  final String Function(String?) getPlayerName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scoreWidth = isWide ? 148.0 : 96.0;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _CompactTeamColumn(
              title: 'Side A',
              color: colorScheme.primary,
              players: players,
              player1: sideA1,
              player2: sideA2,
              showPlayer2: mode == MatchMode.twoVTwo,
              onPlayer1Changed: onSideA1Changed,
              onPlayer2Changed: onSideA2Changed,
              getPlayerName: getPlayerName,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: scoreWidth,
            child: _ScorePanel(
              scoreA: scoreA,
              scoreB: scoreB,
              colorA: colorScheme.primary,
              colorB: colorScheme.secondary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _CompactTeamColumn(
              title: 'Side B',
              color: colorScheme.secondary,
              players: players,
              player1: sideB1,
              player2: sideB2,
              showPlayer2: mode == MatchMode.twoVTwo,
              onPlayer1Changed: onSideB1Changed,
              onPlayer2Changed: onSideB2Changed,
              getPlayerName: getPlayerName,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactTeamColumn extends StatelessWidget {
  const _CompactTeamColumn({
    required this.title,
    required this.color,
    required this.players,
    required this.player1,
    required this.player2,
    required this.showPlayer2,
    required this.onPlayer1Changed,
    required this.onPlayer2Changed,
    required this.getPlayerName,
  });

  final String title;
  final Color color;
  final List<Player> players;
  final String? player1;
  final String? player2;
  final bool showPlayer2;
  final ValueChanged<String?> onPlayer1Changed;
  final ValueChanged<String?>? onPlayer2Changed;
  final String Function(String?) getPlayerName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _CompactPlayerPicker(
          label: 'Player 1',
          value: player1,
          players: players,
          color: color,
          getPlayerName: getPlayerName,
          onSelected: onPlayer1Changed,
        ),
        if (showPlayer2) ...[
          const SizedBox(height: AppSpacing.sm),
          _CompactPlayerPicker(
            label: 'Player 2',
            value: player2,
            players: players,
            color: color,
            getPlayerName: getPlayerName,
            onSelected: (value) => onPlayer2Changed?.call(value),
          ),
        ],
      ],
    );
  }
}

class _CompactPlayerPicker extends StatelessWidget {
  const _CompactPlayerPicker({
    required this.label,
    required this.value,
    required this.players,
    required this.color,
    required this.getPlayerName,
    required this.onSelected,
  });

  final String label;
  final String? value;
  final List<Player> players;
  final Color color;
  final String Function(String?) getPlayerName;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasValue = value != null;

    return InkWell(
      onTap: () => _showPlayerSheet(context),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.person, color: color, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                hasValue ? getPlayerName(value) : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: hasValue
                      ? theme.textTheme.bodyMedium?.color
                      : theme.textTheme.bodyMedium?.color?.withOpacity(0.45),
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.55),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlayerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final player = players[index];
                  final isSelected = player.id == value;

                  return ListTile(
                    dense: true,
                    title: Text(player.displayName),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      onSelected(player.id);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({
    required this.scoreA,
    required this.scoreB,
    required this.colorA,
    required this.colorB,
  });

  final TextEditingController scoreA;
  final TextEditingController scoreB;
  final Color colorA;
  final Color colorB;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          'Score',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _CompactScoreInput(controller: scoreA, color: colorA),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Text(
                '-',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: _CompactScoreInput(controller: scoreB, color: colorB),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            'VS',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactScoreInput extends StatelessWidget {
  const _CompactScoreInput({
    required this.controller,
    required this.color,
  });

  final TextEditingController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: color,
      ),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colorScheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

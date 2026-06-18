import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../domain/elo_config.dart';
import '../../domain/player.dart';
import '../../domain/player_rating.dart';
import '../../services/player_service.dart';
import '../../widgets/responsive_page.dart';
import '../components/components.dart';

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
  bool _isAdding = false;

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
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isAdding = true);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Player added successfully!')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _isAdding = false);
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
      builder: (context) => CustomDialog(
        title: 'Edit Player',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              controller: nameController,
              label: 'Display name',
            ),
            const SizedBox(height: AppSpacing.md),
            CustomTextField(
              controller: eloController,
              label: 'ELO Rating',
              hint: '${EloConfig.minElo} - ${EloConfig.maxElo}',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownField<int>(
              value: selectedSkill,
              label: 'Skill level',
              items: const [1, 2, 3],
              itemBuilder: (value) {
                switch (value) {
                  case 1:
                    return const Text('1 · Strong');
                  case 2:
                    return const Text('2 · Medium');
                  default:
                    return const Text('3 · Beginner');
                }
              },
              onSelected: (value) {
                if (value != null) {
                  selectedSkill = value;
                }
              },
            ),
          ],
        ),
        actions: [
          SecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
          PrimaryButton(
            label: 'Save',
            onPressed: () => Navigator.of(context).pop(
              _EditResult(
                nameController.text,
                selectedSkill,
                int.tryParse(eloController.text),
              ),
            ),
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _delete(PlayerService service, Player player) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => CustomDialog(
        title: 'Delete Player?',
        content: Text('Are you sure you want to delete ${player.displayName}?'),
        actions: [
          SecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(false),
          ),
          DangerButton(
            label: 'Delete',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await service.softDeletePlayer(player.id);
      await _load(service);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlayerService>(
      future: _serviceFuture,
      builder: (context, snapshot) {
        final theme = Theme.of(context);
        final service = snapshot.data;
        if (service == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final addPlayerCard = AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.person_add_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Add New Player',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              CustomTextField(
                controller: _nameController,
                label: 'Player name',
                prefixIcon: const Icon(Icons.person_outline),
                onSubmitted: (_) => _add(service),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _eloController,
                      label: 'Starting ELO',
                      prefixIcon: const Icon(Icons.star_outline),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onSubmitted: (_) => _add(service),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: DropdownButton<int>(
                      dropdownColor: theme.colorScheme.surface,
                      value: _skillLevel,
                      underline: const SizedBox.shrink(),
                      items: [
                        DropdownMenuItem(
                          value: 1,
                          child: Text('L1', style: theme.textTheme.bodyMedium),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text('L2', style: theme.textTheme.bodyMedium),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text('L3', style: theme.textTheme.bodyMedium),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _skillLevel = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Add Player',
                icon: Icons.add,
                onPressed: () => _add(service),
                isLoading: _isAdding,
              ),
            ],
          ),
        );

        final playersSection = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'Players'),
            if (_players.isEmpty)
              const EmptyState(
                icon: Icons.group_outlined,
                title: 'No players yet',
                message:
                    'Add your first player to get started tracking matches.',
              )
            else
              ResponsiveGrid(
                minItemWidth: 340,
                maxColumns: 2,
                children: [
                  for (final player in _players)
                    Builder(
                      builder: (context) {
                        final rating = _ratings[player.id];
                        final eloDisplay = rating?.elo ?? EloConfig.defaultElo;
                        final skillColor = _getSkillColor(
                            theme.colorScheme, player.skillLevel);
                        return AppCard(
                          onTap: () => context.go('/players/${player.id}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          child: Row(
                            children: [
                              // Skill Level Badge
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: skillColor.withOpacity(0.2),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Center(
                                  child: Text(
                                    'L${player.skillLevel}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: skillColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              // Player Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      player.displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    Text(
                                      'ELO: $eloDisplay',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              // ELO Display
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(
                                  '$eloDisplay',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              // Actions
                              CustomIconButton(
                                onPressed: () => _edit(service, player),
                                icon: Icons.edit_outlined,
                                tooltip: 'Edit',
                              ),
                              CustomIconButton(
                                onPressed: () => _delete(service, player),
                                icon: Icons.delete_outline,
                                color: Theme.of(context).colorScheme.error,
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
          ],
        );

        return ResponsivePage(
          maxWidth: 1180,
          children: [
            ResponsiveSplit(
              breakpoint: 900,
              startFlex: 2,
              endFlex: 3,
              start: addPlayerCard,
              end: playersSection,
            ),
          ],
        );
      },
    );
  }

  Color _getSkillColor(ColorScheme colors, int level) {
    switch (level) {
      case 1:
        return colors.primary;
      case 2:
        return colors.secondary;
      case 3:
        return colors.tertiary;
      default:
        return colors.outline;
    }
  }
}

class _EditResult {
  const _EditResult(this.name, this.skillLevel, this.elo);

  final String name;
  final int skillLevel;
  final int? elo;
}

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/club.dart';
import '../../services/club_service.dart';
import '../../widgets/responsive_page.dart';
import '../components/components.dart';

class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key});

  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  late Future<ClubService> _serviceFuture;
  List<Club> _clubs = [];

  @override
  void initState() {
    super.initState();
    _serviceFuture = ClubService.create();
    _serviceFuture.then(_load);
  }

  Future<void> _load(ClubService service) async {
    final clubs = await service.listClubs();
    setState(() => _clubs = clubs);
  }

  Future<void> _create(ClubService service) async {
    final result = await _showEditDialog();
    if (result == null) return;
    await service.createClub(result.name, result.stars);
    await _load(service);
  }

  Future<void> _edit(ClubService service, Club club) async {
    final result = await _showEditDialog(club: club);
    if (result == null) return;
    await service.updateClub(club.id, result.name, result.stars);
    await _load(service);
  }

  Future<void> _delete(ClubService service, Club club) async {
    await service.deleteClub(club.id);
    await _load(service);
  }

  Future<_ClubEditResult?> _showEditDialog({Club? club}) async {
    final controller = TextEditingController(text: club?.name ?? '');
    var selectedStars = club?.stars ?? 4.0;
    return showDialog<_ClubEditResult>(
      context: context,
      builder: (context) => CustomDialog(
        title: club == null ? 'Add club' : 'Edit club',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              controller: controller,
              label: 'Club name',
            ),
            const SizedBox(height: 12),
            DropdownField<double>(
              value: selectedStars,
              label: 'Stars',
              items: _starOptions,
              itemBuilder: (value) => Text(_formatStars(value)),
              onSelected: (value) {
                if (value != null) selectedStars = value;
              },
            ),
          ],
        ),
        actions: [
          SecondaryButton(
            onPressed: () => Navigator.of(context).pop(),
            label: 'Cancel',
          ),
          PrimaryButton(
            onPressed: () => Navigator.of(context).pop(
              _ClubEditResult(controller.text, selectedStars),
            ),
            label: 'Save',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ClubService>(
      future: _serviceFuture,
      builder: (context, snapshot) {
        final service = snapshot.data;
        if (service == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final sorted = [..._clubs]..sort((a, b) {
            final diff = b.stars.compareTo(a.stars);
            if (diff != 0) return diff;
            return a.name.compareTo(b.name);
          });
        return ResponsivePage(
          maxWidth: 1040,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Clubs',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                PrimaryButton(
                  onPressed: () => _create(service),
                  label: 'Add',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (sorted.isEmpty)
              const EmptyState(
                title: 'No clubs yet',
                icon: Icons.shield_outlined,
              )
            else
              ..._buildClubSections(sorted, service),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: SecondaryButton(
                onPressed: () => _load(service),
                label: 'Refresh',
                icon: Icons.refresh,
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildClubSections(List<Club> clubs, ClubService service) {
    final sections = <Widget>[];
    double? currentStars;
    final currentGroup = <Club>[];

    void flushGroup() {
      final stars = currentStars;
      if (stars == null || currentGroup.isEmpty) return;
      final groupedClubs = [...currentGroup];
      sections.add(
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            _formatStars(stars),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
      sections.add(
        ResponsiveGrid(
          minItemWidth: 300,
          maxColumns: 3,
          children: [
            for (final club in groupedClubs) _buildClubCard(club, service),
          ],
        ),
      );
      currentGroup.clear();
    }

    for (final club in clubs) {
      if (currentStars != club.stars) {
        flushGroup();
        currentStars = club.stars;
      }
      currentGroup.add(club);
    }
    flushGroup();
    return sections;
  }

  Widget _buildClubCard(Club club, ClubService service) {
    return AppCard(
      child: CustomListTile(
        title: club.name,
        subtitle: _formatStars(club.stars),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomIconButton(
              onPressed: () => _edit(service, club),
              icon: Icons.edit_outlined,
            ),
            CustomIconButton(
              onPressed: () => _delete(service, club),
              icon: Icons.delete_outline,
            ),
          ],
        ),
      ),
    );
  }

  static const List<double> _starOptions = [
    1.0,
    1.5,
    2.0,
    2.5,
    3.0,
    3.5,
    4.0,
    4.5,
    5.0,
  ];

  String _formatStars(double value) {
    return '${value.toStringAsFixed(1)}★';
  }
}

class _ClubEditResult {
  const _ClubEditResult(this.name, this.stars);

  final String name;
  final double stars;
}

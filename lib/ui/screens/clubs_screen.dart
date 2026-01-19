import 'package:flutter/material.dart';

import '../../domain/club.dart';
import '../../services/club_service.dart';

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
      builder: (context) => AlertDialog(
        title: Text(club == null ? 'Add club' : 'Edit club'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Club name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<double>(
              value: selectedStars,
              decoration: const InputDecoration(labelText: 'Stars'),
              items: _starOptions
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_formatStars(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) selectedStars = value;
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
              _ClubEditResult(controller.text, selectedStars),
            ),
            child: const Text('Save'),
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
        final sorted = [..._clubs]
          ..sort((a, b) {
            final diff = b.stars.compareTo(a.stars);
            if (diff != 0) return diff;
            return a.name.compareTo(b.name);
          });
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Clubs',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                FilledButton(
                  onPressed: () => _create(service),
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (sorted.isEmpty)
              const Text('No clubs yet.')
            else
              ..._buildClubList(sorted, service),
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

  List<Widget> _buildClubList(List<Club> clubs, ClubService service) {
    final widgets = <Widget>[];
    double? currentStars;
    for (final club in clubs) {
      if (currentStars != club.stars) {
        currentStars = club.stars;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              _formatStars(club.stars),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        );
      }
      widgets.add(
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(club.name),
            subtitle: Text(_formatStars(club.stars)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _edit(service, club),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: () => _delete(service, club),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
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

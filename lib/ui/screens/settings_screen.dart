import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: const Text('Data Management'),
            subtitle: const Text('Export or import data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/data'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            title: const Text('Clubs'),
            subtitle: const Text('Manage club catalog and stars'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/clubs'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            title: const Text('Head-to-Head'),
            subtitle: const Text('Compare head-to-head stats'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/h2h'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            title: const Text('Seasons'),
            subtitle: const Text('Seasonal leaderboards'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/seasons'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: ListTile(
            leading: Icon(
              Icons.restart_alt,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Reset ELO Ratings',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            subtitle: Text(
              'Reset all ratings and start fresh',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onErrorContainer
                    .withOpacity(0.7),
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            onTap: () => context.go('/settings/elo-reset'),
          ),
        ),
      ],
    );
  }
}

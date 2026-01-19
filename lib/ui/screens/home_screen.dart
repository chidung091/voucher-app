import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'FC Match Tracker',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Offline tracker for players, matches, Elo, and tournaments.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        _ActionCard(
          title: 'Players',
          subtitle: 'Create and manage player profiles.',
          icon: Icons.group_outlined,
          onTap: () => context.go('/players'),
        ),
        _ActionCard(
          title: 'Clubs',
          subtitle: 'Manage club catalog and stars.',
          icon: Icons.shield_outlined,
          onTap: () => context.go('/clubs'),
        ),
        _ActionCard(
          title: 'New Match',
          subtitle: 'Record 1v1 or 2v2 matches.',
          icon: Icons.sports_soccer_outlined,
          onTap: () => context.go('/matches/new'),
        ),
        _ActionCard(
          title: 'Leaderboard',
          subtitle: 'Track Elo rankings.',
          icon: Icons.emoji_events_outlined,
          onTap: () => context.go('/leaderboard'),
        ),
        _ActionCard(
          title: 'Seasons',
          subtitle: 'Monthly/quarterly/yearly rankings.',
          icon: Icons.calendar_month_outlined,
          onTap: () => context.go('/seasons'),
        ),
        _ActionCard(
          title: 'Head-to-Head',
          subtitle: 'Compare 1v1 and 2v2 matchups.',
          icon: Icons.compare_arrows_outlined,
          onTap: () => context.go('/h2h'),
        ),
        _ActionCard(
          title: 'Tournament',
          subtitle: '3-team round robin + final.',
          icon: Icons.emoji_objects_outlined,
          onTap: () => context.go('/tournaments'),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

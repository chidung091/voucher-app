import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
      ),
      body: ListView(
        children: [
          _MoreTile(
            icon: Icons.group_outlined,
            title: 'Players',
            subtitle: 'Manage player profiles',
            onTap: () => context.go('/players'),
          ),
          _MoreTile(
            icon: Icons.shield_outlined,
            title: 'Clubs',
            subtitle: 'Manage clubs',
            onTap: () => context.go('/clubs'),
          ),
          _MoreTile(
            icon: Icons.calendar_month_outlined,
            title: 'Seasons',
            subtitle: 'Rankings history',
            onTap: () => context.go('/seasons'),
          ),
          _MoreTile(
            icon: Icons.compare_arrows_outlined,
            title: 'Head-to-Head',
            subtitle: 'Compare matchups',
            onTap: () => context.go('/h2h'),
          ),
          const Divider(),
          _MoreTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'App configuration',
            onTap: () => context.go('/settings'),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

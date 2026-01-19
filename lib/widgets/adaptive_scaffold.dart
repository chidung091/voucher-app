import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/responsive.dart';

class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(
        label: 'Home',
        title: 'Home',
        icon: Icons.home_outlined,
        route: '/home',
      ),
      _NavItem(
        label: 'Players',
        title: 'Players',
        icon: Icons.group_outlined,
        route: '/players',
      ),
      _NavItem(
        label: 'Clubs',
        title: 'Clubs',
        icon: Icons.shield_outlined,
        route: '/clubs',
      ),
      _NavItem(
        label: 'Matches',
        title: 'New Match',
        icon: Icons.sports_soccer_outlined,
        route: '/matches/new',
      ),
      _NavItem(
        label: 'Leaderboard',
        title: 'Leaderboard',
        icon: Icons.emoji_events_outlined,
        route: '/leaderboard',
      ),
      _NavItem(
        label: 'Seasons',
        title: 'Seasons',
        icon: Icons.calendar_month_outlined,
        route: '/seasons',
      ),
      _NavItem(
        label: 'Tournament',
        title: 'Tournament',
        icon: Icons.emoji_objects_outlined,
        route: '/tournaments',
      ),
      _NavItem(
        label: 'Settings',
        title: 'Settings',
        icon: Icons.settings_outlined,
        route: '/settings',
      ),
    ];

    final location = GoRouterState.of(context).uri.path;
    final selectedIndex =
        items.indexWhere((item) => location.startsWith(item.route));
    final currentIndex = selectedIndex == -1 ? 0 : selectedIndex;
    final pageTitle = items[currentIndex].title;
    final isTablet = ResponsiveBreakpoints.isTablet(context);
    final rail = NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) => context.go(items[index].route),
      destinations: [
        for (final item in items)
          NavigationRailDestination(
            icon: Icon(item.icon),
            label: Text(item.label),
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle),
      ),
      body: isTablet
          ? Row(
              children: [
                rail,
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            )
          : child,
      bottomNavigationBar: isTablet
          ? null
          : BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: (index) => context.go(items[index].route),
              items: [
                for (final item in items)
                  BottomNavigationBarItem(
                    icon: Icon(item.icon),
                    label: item.label,
                  ),
              ],
            ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.title,
    required this.icon,
    required this.route,
  });

  final String label;
  final String title;
  final IconData icon;
  final String route;
}

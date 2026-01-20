import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/responsive.dart';

class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({super.key, required this.child});

  final Widget child;

  @override
  @override
  Widget build(BuildContext context) {
    // Full list for Tablet/Desktop
    final allItems = [
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
        label: 'Head-to-Head',
        title: 'Head-to-Head',
        icon: Icons.compare_arrows_outlined,
        route: '/h2h',
      ),
      _NavItem(
        label: 'Settings',
        title: 'Settings',
        icon: Icons.settings_outlined,
        route: '/settings',
      ),
    ];

    // 5 Main tabs for Mobile
    final mobileItems = [
      allItems[0], // Home
      allItems[3], // Matches
      allItems[4], // Leaderboard
      allItems[6], // Tournament
      _NavItem(
        label: 'More',
        title: 'More',
        icon: Icons.menu_outlined,
        route: '/more',
      ),
    ];

    final isTablet = ResponsiveBreakpoints.isTablet(context);
    final activeItems = isTablet ? allItems : mobileItems;

    final location = GoRouterState.of(context).uri.path;

    // Find active index based on activeItems
    // For mobile, if we are on a route not in main tabs (e.g. players), select 'More'
    int selectedIndex =
        activeItems.indexWhere((item) => location.startsWith(item.route));
    if (selectedIndex == -1) {
      if (!isTablet) {
        // On mobile, check if the current location is one of the "More" items
        // The "More" item is the last one (index 4)
        // Routes under "More" are: /players, /clubs, /seasons, /h2h, /settings
        // The 'More' tab route itself is '/more'
        // If location is any of those, we highly likely want to highlight 'More'.
        // But wait, if I am in /players, activeItems doesn't contain /players on mobile.
        // So I should default to the last tab (More) if no match found?
        // Or maybe just highlight nothing?
        // Standard pattern: Highlight 'More' if inside a section that belongs to it.
        // Let's assume 'More' is the catch-all for unknown routes at this level?
        // Actually, if I navigate to /players on mobile, navigation bar should show 'More' selected?
        // Yes.
        selectedIndex = 4; // 'More' tab
      } else {
        selectedIndex = 0; // Default to Home if lost on Tablet
      }
    }

    // Safety check
    if (selectedIndex >= activeItems.length) selectedIndex = 0;

    final pageTitle = selectedIndex < activeItems.length
        ? activeItems[selectedIndex].title
        : 'FC Match Tracker';

    final rail = NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) => context.go(activeItems[index].route),
      destinations: [
        for (final item in activeItems)
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
              currentIndex: selectedIndex,
              onTap: (index) => context.go(activeItems[index].route),
              type: BottomNavigationBarType.fixed,
              items: [
                for (final item in activeItems)
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

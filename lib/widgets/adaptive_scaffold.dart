import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/responsive.dart';

class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({super.key, required this.child});

  final Widget child;

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

    int selectedIndex =
        activeItems.indexWhere((item) => location.startsWith(item.route));
    if (selectedIndex == -1) {
      if (!isTablet) {
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

    // Animated content with smooth transitions
    final animatedChild = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.02, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            )),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<String>(location),
        child: child,
      ),
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
                Expanded(child: animatedChild),
              ],
            )
          : animatedChild,
      bottomNavigationBar: isTablet
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              animationDuration: const Duration(milliseconds: 400),
              onDestinationSelected: (index) =>
                  context.go(activeItems[index].route),
              destinations: [
                for (final item in activeItems)
                  NavigationDestination(
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

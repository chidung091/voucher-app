import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/splash/splash_screen.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/leaderboard_screen.dart';
import '../ui/screens/new_match_screen.dart';
import '../ui/screens/players_screen.dart';
import '../ui/screens/settings_screen.dart';
import '../ui/screens/tournament_screen.dart';
import '../ui/screens/data_management_screen.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/error_view.dart';

GoRouter buildRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AdaptiveScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/players',
            name: 'players',
            builder: (context, state) => const PlayersScreen(),
          ),
          GoRoute(
            path: '/matches/new',
            name: 'new-match',
            builder: (context, state) => const NewMatchScreen(),
          ),
          GoRoute(
            path: '/leaderboard',
            name: 'leaderboard',
            builder: (context, state) => const LeaderboardScreen(),
          ),
          GoRoute(
            path: '/tournaments',
            name: 'tournaments',
            builder: (context, state) => const TournamentScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/settings/data',
            name: 'data-management',
            builder: (context, state) => const DataManagementScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) {
      return ErrorView(
        title: 'Something went wrong',
        message: state.error?.toString() ?? 'Unknown navigation error',
        retryLabel: 'Try again',
        onRetry: () => context.go('/home'),
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/splash/splash_screen.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/leaderboard_screen.dart';
import '../ui/screens/more_screen.dart';
import '../ui/screens/new_match_screen.dart';
import '../ui/screens/clubs_screen.dart';
import '../ui/screens/elo_reset_screen.dart';
import '../ui/screens/head_to_head_screen.dart';
import '../ui/screens/player_profile_screen.dart';
import '../ui/screens/players_screen.dart';
import '../ui/screens/seasons_screen.dart';
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
            pageBuilder: (context, state) =>
                _navigationPage(state, const HomeScreen()),
          ),
          GoRoute(
            path: '/players',
            name: 'players',
            pageBuilder: (context, state) =>
                _navigationPage(state, const PlayersScreen()),
          ),
          GoRoute(
            path: '/clubs',
            name: 'clubs',
            pageBuilder: (context, state) =>
                _navigationPage(state, const ClubsScreen()),
          ),
          GoRoute(
            path: '/h2h',
            name: 'head-to-head',
            pageBuilder: (context, state) =>
                _navigationPage(state, const HeadToHeadScreen()),
          ),
          GoRoute(
            path: '/seasons',
            name: 'seasons',
            pageBuilder: (context, state) =>
                _navigationPage(state, const SeasonsScreen()),
          ),
          GoRoute(
            path: '/players/:id',
            name: 'player-profile',
            builder: (context, state) {
              final playerId = state.pathParameters['id']!;
              return PlayerProfileScreen(playerId: playerId);
            },
          ),
          GoRoute(
            path: '/matches/new',
            name: 'new-match',
            pageBuilder: (context, state) =>
                _navigationPage(state, const NewMatchScreen()),
          ),
          GoRoute(
            path: '/leaderboard',
            name: 'leaderboard',
            pageBuilder: (context, state) =>
                _navigationPage(state, const LeaderboardScreen()),
          ),
          GoRoute(
            path: '/tournaments',
            name: 'tournaments',
            pageBuilder: (context, state) =>
                _navigationPage(state, const TournamentScreen()),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) =>
                _navigationPage(state, const SettingsScreen()),
          ),
          GoRoute(
            path: '/settings/data',
            name: 'data-management',
            builder: (context, state) => const DataManagementScreen(),
          ),
          GoRoute(
            path: '/settings/elo-reset',
            name: 'elo-reset',
            builder: (context, state) => const EloResetScreen(),
          ),
          GoRoute(
            path: '/more',
            name: 'more',
            pageBuilder: (context, state) =>
                _navigationPage(state, const MoreScreen()),
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

Page<void> _navigationPage(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(
    key: state.pageKey,
    child: child,
  );
}

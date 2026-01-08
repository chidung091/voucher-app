import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/vouchers/vouchers_screen.dart';
import '../features/vouchers/voucher_detail_screen.dart';
import '../widgets/adaptive_scaffold.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
            path: '/vouchers',
            name: 'vouchers',
            builder: (context, state) => const VouchersScreen(),
          ),
          GoRoute(
            path: '/vouchers/:id',
            name: 'voucher-detail',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              return VoucherDetailScreen(voucherId: id);
            },
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) {
      final localizations = AppLocalizations.of(context)!;
      return ErrorView(
        title: localizations.errorsTitle,
        message: state.error?.toString() ?? 'Unknown navigation error',
        retryLabel: localizations.tryAgain,
        onRetry: () => context.go('/home'),
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voucher_app/app.dart';
import 'package:voucher_app/core/app_theme.dart';
import 'package:voucher_app/data/local_store.dart';
import 'package:voucher_app/domain/enums.dart';
import 'package:voucher_app/state/providers.dart';
import 'package:voucher_app/services/player_service.dart';
import 'package:voucher_app/services/tournament_service.dart';
import 'package:voucher_app/ui/screens/home_screen.dart';

void main() {
  testWidgets('App builds and shows splash content', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VoucherApp()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('MinmaFC'), findsOneWidget);
  });

  testWidgets('App applies selected theme mode and brand palette',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeModeProvider.overrideWith((ref) => ThemeMode.dark),
        ],
        child: const VoucherApp(),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.theme!.colorScheme.primary, AppColors.deepTeal);
    expect(app.theme!.scaffoldBackgroundColor, AppColors.neutral);
    expect(app.darkTheme!.colorScheme.primary, AppColors.mint);
  });

  testWidgets('Home provides direct quick player creation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quick add player'), findsOneWidget);
    expect(find.text('Active tournament results'), findsOneWidget);
    expect(find.text('New Match'), findsNothing);
    expect(find.text('Leaderboard'), findsNothing);

    final nameField = find.descendant(
      of: find.byKey(const Key('quick-player-name')),
      matching: find.byType(TextField),
    );
    await tester.enterText(nameField, 'Quick Player');
    await tester.tap(find.byKey(const Key('quick-add-player')));
    await tester.pumpAndSettle();

    final players = await (await PlayerService.create()).listPlayers();
    expect(players.single.displayName, 'Quick Player');
  });

  testWidgets('Home records the next active tournament result', (tester) async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();
    final playerService = await PlayerService.create();
    final home = await playerService.createPlayer('Home Player');
    final away = await playerService.createPlayer('Away Player');
    final tournamentService = await TournamentService.create();
    final view = await tournamentService.createTournament(
      TournamentInput(
        name: 'Quick Cup',
        mode: MatchMode.oneVOne,
        finalsEnabled: false,
        teams: [
          TournamentTeamInput(name: 'Home Team', playerIds: [home.id]),
          TournamentTeamInput(name: 'Away Team', playerIds: [away.id]),
        ],
      ),
    );
    final match = view.matches.single;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quick Cup'), findsOneWidget);
    await tester.enterText(
      find.byKey(Key('home-score-${match.id}')),
      '2',
    );
    await tester.enterText(
      find.byKey(Key('away-score-${match.id}')),
      '1',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('record-result-${match.id}')));
    await tester.pumpAndSettle();

    final completed = await tournamentService.getTournament(view.tournament.id);
    expect(completed.tournament.status, TournamentStatus.completed);
    expect(find.text('No active tournaments'), findsOneWidget);
  });

  testWidgets('Bottom tabs replace page content without a stale route frame',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();
    await tester.pumpWidget(const ProviderScope(child: VoucherApp()));
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    expect(find.text('Quick add player'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(NavigationDestination, 'Matches'),
    );
    await tester.pump();

    expect(find.text('Match Setup'), findsOneWidget);
    expect(find.text('Quick add player'), findsNothing);
  });

  testWidgets('Settings theme switch applies without text style errors',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.resetForTest();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeModeProvider.overrideWith((ref) => ThemeMode.light),
        ],
        child: const VoucherApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
    await tester.pump();
    await tester.tap(find.text('Settings'));
    await tester.pump();
    expect(find.text('Appearance'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

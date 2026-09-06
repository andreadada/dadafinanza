import 'package:dadafinanza/app_state.dart';
import 'package:dadafinanza/data/app_database.dart';
import 'package:dadafinanza/main.dart';
import 'package:dadafinanza/models/models.dart';
import 'package:dadafinanza/screens/home_screen.dart';
import 'package:dadafinanza/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('it_IT'));

  testWidgets('Home respects enabled dashboard widgets', (tester) async {
    final state = AppState(AppDatabase())
      ..loading = false
      ..dashboardWidgets = const [
        DashboardWidgetConfig(
          type: DashboardWidgetType.totalBalance,
          enabled: false,
          orderIndex: 0,
          size: DashboardWidgetSize.medium,
        ),
        DashboardWidgetConfig(
          type: DashboardWidgetType.monthlyIncome,
          enabled: true,
          orderIndex: 1,
          size: DashboardWidgetSize.small,
        ),
      ];

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: DadaHomeScreen()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('PATRIMONIO'), findsNothing);
    expect(find.text('Entrate del mese'), findsOneWidget);
    expect(find.text('Conti'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('advanced dashboard opens inside a Material scaffold', (
    tester,
  ) async {
    final state = AppState(AppDatabase())
      ..loading = false
      ..dashboardWidgets = const [
        DashboardWidgetConfig(
          type: DashboardWidgetType.totalBalance,
          enabled: true,
          orderIndex: 0,
          size: DashboardWidgetSize.medium,
        ),
      ];

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: DadaHomeScreen()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Dashboard avanzata'));
    await tester.pumpAndSettle();

    expect(find.text('Saldo totale'), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

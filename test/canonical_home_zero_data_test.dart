import 'package:dadafinanza/app_state.dart';
import 'package:dadafinanza/data/app_database.dart';
import 'package:dadafinanza/main.dart';
import 'package:dadafinanza/screens/home_screen.dart';
import 'package:dadafinanza/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('it_IT'));

  for (final size in const [
    Size(320, 700),
    Size(360, 800),
    Size(390, 844),
    Size(430, 932),
  ]) {
    testWidgets('zero-data Home keeps the account empty state compact at ${size.width}dp', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState(AppDatabase())..loading = false;
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

      expect(find.byTooltip('Dashboard avanzata'), findsOneWidget);
      expect(find.text('PATRIMONIO'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('Nessun conto'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      expect(find.text('Nessun conto'), findsOneWidget);
      final sectionTop = tester.getTopLeft(find.text('Conti')).dy;
      final emptyTop = tester.getTopLeft(find.text('Nessun conto')).dy;
      expect(emptyTop - sectionTop, lessThan(260));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('zero-data Home supports large text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState(AppDatabase())..loading = false;
    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(body: DadaHomeScreen()),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Dashboard avanzata'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Nessun conto'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Nessun conto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

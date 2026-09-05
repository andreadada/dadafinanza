import 'package:dadafinanza/app_state.dart';
import 'package:dadafinanza/data/app_database.dart';
import 'package:dadafinanza/main.dart';
import 'package:dadafinanza/screens/advances_screen.dart';
import 'package:dadafinanza/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in const [
    Size(320, 700),
    Size(360, 800),
    Size(390, 844),
    Size(430, 932),
  ]) {
    testWidgets('Anticipi empty state has no overflow at ${size.width}dp', (
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
            home: const AdvancesScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Anticipi'), findsOneWidget);
      expect(find.text('Da ricevere'), findsOneWidget);
      expect(find.text('Da restituire'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Anticipi supports large text without overflow', (tester) async {
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
            home: const AdvancesScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Anticipi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

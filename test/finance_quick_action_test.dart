import 'package:dadafinanza/widgets/finance_quick_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('three quick actions fit a 320dp row without wrapping', (
    tester,
  ) async {
    var tapped = '';
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: FinanceQuickAction(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Spesa',
                  onTap: () => tapped = 'expense',
                ),
              ),
              Expanded(
                child: FinanceQuickAction(
                  icon: Icons.arrow_downward_rounded,
                  label: 'Entrata',
                  onTap: () => tapped = 'income',
                ),
              ),
              Expanded(
                child: FinanceQuickAction(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Trasferisci',
                  onTap: () => tapped = 'transfer',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Spesa'), findsOneWidget);
    expect(find.text('Entrata'), findsOneWidget);
    expect(find.text('Trasferisci'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Trasferisci'));
    expect(tapped, 'transfer');
  });

  testWidgets('quick action exposes button semantics', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinanceQuickAction(
            icon: Icons.arrow_upward_rounded,
            label: 'Spesa',
            onTap: () {},
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(FinanceQuickAction));
    expect(semantics.flagsCollection.isButton, isTrue);
  });
}

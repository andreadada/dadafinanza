import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest publishes all DadaFinanza widget variants', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('.DadaFinanceWidgetProvider'));
    expect(manifest, contains('.DadaBalanceWidgetProvider'));
    expect(manifest, contains('.DadaQuickAddWidgetProvider'));
    expect(manifest, contains('@xml/dada_finance_widget_info'));
    expect(manifest, contains('@xml/dada_balance_widget_info'));
    expect(manifest, contains('@xml/dada_quick_add_widget_info'));
  });

  test('Android widgets declare distinct target home-screen sizes', () {
    final balance = File(
      'android/app/src/main/res/xml/dada_balance_widget_info.xml',
    ).readAsStringSync();
    final quick = File(
      'android/app/src/main/res/xml/dada_quick_add_widget_info.xml',
    ).readAsStringSync();
    final summary = File(
      'android/app/src/main/res/xml/dada_finance_widget_info.xml',
    ).readAsStringSync();

    expect(balance, contains('android:targetCellWidth="2"'));
    expect(balance, contains('android:targetCellHeight="1"'));
    expect(quick, contains('android:targetCellWidth="2"'));
    expect(quick, contains('android:targetCellHeight="2"'));
    expect(summary, contains('android:targetCellWidth="4"'));
    expect(summary, contains('android:targetCellHeight="2"'));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active Home consumes saved dashboard widget configuration', () {
    final source = File(
      'lib/screens/account_context_home_screen.dart',
    ).readAsStringSync();

    expect(source, contains("import '../widgets/home_dashboard_widget.dart';"));
    expect(source, contains('HomeDashboardWidget(config: config)'));
    expect(source, contains('state.dashboardWidgets'));
    expect(source, contains('item.enabled'));
    expect(source, contains('a.orderIndex.compareTo(b.orderIndex)'));
    expect(source, contains('config.size'));
  });

  test('advanced dashboard is opened inside a Scaffold', () {
    final source = File(
      'lib/screens/account_context_home_screen.dart',
    ).readAsStringSync();

    expect(source, contains('const Scaffold(body: advanced.HomeScreen())'));
  });
}

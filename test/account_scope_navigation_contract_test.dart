import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('primary shell shares account scope and uses history-aware back', () {
    final source = File('lib/screens/app_shell.dart').readAsStringSync();

    expect(source, contains('int? selectedAccountId'));
    expect(source, contains('DadaHomeScreen('));
    expect(source, contains('ExpertTransactionsScreen('));
    expect(source, contains('AccountAnalyticsScreen('));
    expect(source, contains('final List<int> _tabHistory = [0]'));
    expect(source, contains('Premi di nuovo Indietro per uscire'));
    expect(source, contains('SystemNavigator.pop()'));
  });

  test('Home title is the shared account selector', () {
    final source = File('lib/screens/home_screen.dart').readAsStringSync();

    expect(source, contains('AccountScopeSelector('));
    expect(
      source,
      contains("selectedAccount == null ? 'PATRIMONIO' : 'SALDO'"),
    );
    expect(source, isNot(contains("const Text('DadaFinanza')")));
  });

  test('movements exposes list, accounts and categories modes', () {
    final source = File(
      'lib/screens/expert_transactions_screen.dart',
    ).readAsStringSync();

    expect(source, contains('TransactionsViewMode.list'));
    expect(source, contains('TransactionsViewMode.accounts'));
    expect(source, contains('TransactionsViewMode.categories'));
    expect(source, contains("label: Text('Elenco')"));
    expect(source, contains("label: Text('Conti')"));
    expect(source, contains("label: Text('Categorie')"));
  });

  test('safe account detail delegates editing to full icon-capable editor', () {
    final source = File(
      'lib/screens/account_management_screen.dart',
    ).readAsStringSync();

    expect(source, contains('showAccountEditor(context, existing: account)'));
    expect(source, isNot(contains('Future<void> _editMetadata(')));
  });
}

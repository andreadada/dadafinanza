import 'package:dadafinanza/app_state.dart';
import 'package:dadafinanza/data/app_database.dart';
import 'package:dadafinanza/models/models.dart';
import 'package:dadafinanza/services/account_context_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Account account(int id, String name) => Account(
    id: id,
    name: name,
    balance: id == 1 ? 100 : 200,
    colorValue: 0xFF000000,
    iconKey: 'wallet',
    accountType: AccountType.checking,
    includeInTotal: true,
    includeInAnalytics: true,
    isLocked: false,
    isArchived: false,
    hideBalance: false,
    isSystem: false,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  FinanceTransaction transaction({
    required int id,
    required TransactionType type,
    required double amount,
    required int accountId,
    int? toAccountId,
    int? categoryId,
  }) => FinanceTransaction(
    id: id,
    type: type,
    amount: amount,
    accountId: accountId,
    toAccountId: toAccountId,
    categoryId: categoryId,
    date: DateTime(2026, 9, 1),
    includeInAnalytics: true,
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );

  test('account context includes transfers where account is destination', () {
    final state = AppState(AppDatabase())..loading = false;
    state.accounts = [account(1, 'A'), account(2, 'B')];
    state.transactions = [
      transaction(
        id: 1,
        type: TransactionType.transfer,
        amount: 20,
        accountId: 1,
        toAccountId: 2,
      ),
      transaction(
        id: 2,
        type: TransactionType.expense,
        amount: 5,
        accountId: 1,
      ),
    ];

    final forSecond = AccountContextService.transactionsFor(state, 2);
    expect(forSecond.map((item) => item.id), contains(1));
    expect(forSecond.map((item) => item.id), isNot(contains(2)));
  });

  test('grouped movements report totals and percentages by category', () {
    final state = AppState(AppDatabase())..loading = false;
    state.accounts = [account(1, 'A')];
    state.categories = [
      const Category(
        id: 10,
        name: 'Amici',
        iconKey: 'group',
        colorValue: 0xFF000000,
        type: TransactionType.expense,
        quickOrder: null,
      ),
      const Category(
        id: 11,
        name: 'Cibo',
        iconKey: 'restaurant',
        colorValue: 0xFF000000,
        type: TransactionType.expense,
        quickOrder: null,
      ),
    ];
    final items = [
      transaction(
        id: 1,
        type: TransactionType.expense,
        amount: 30,
        accountId: 1,
        categoryId: 10,
      ),
      transaction(
        id: 2,
        type: TransactionType.expense,
        amount: 10,
        accountId: 1,
        categoryId: 11,
      ),
    ];

    final groups = AccountContextService.groupByCategory(state, items);
    final friends = groups.firstWhere((item) => item.categoryId == 10);
    expect(friends.total, 30);
    expect(friends.count, 1);
    expect(friends.percentage, 75);
  });
}

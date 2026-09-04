import 'package:dadafinanza/app_state.dart';
import 'package:dadafinanza/data/app_database.dart';
import 'package:dadafinanza/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 4, 12);

  Account account({
    required int id,
    required String name,
    required double balance,
    bool includeInTotal = true,
    bool includeInAnalytics = true,
    bool archived = false,
    bool system = false,
  }) =>
      Account(
        id: id,
        name: name,
        balance: balance,
        colorValue: 0xFF8E8E93,
        iconKey: system ? 'help' : 'wallet',
        accountType: AccountType.checking,
        includeInTotal: includeInTotal,
        includeInAnalytics: includeInAnalytics,
        isLocked: false,
        isArchived: archived,
        hideBalance: false,
        isSystem: system,
        createdAt: now,
        updatedAt: now,
      );

  Category category(int id, String name) => Category(
        id: id,
        name: name,
        iconKey: 'category',
        colorValue: 0xFF8E8E93,
        type: TransactionType.expense,
        quickOrder: null,
      );

  FinanceTransaction transaction({
    required int id,
    required TransactionType type,
    required double amount,
    required int accountId,
    int? categoryId,
    int? refundOf,
    bool analytics = true,
  }) =>
      FinanceTransaction(
        id: id,
        type: type,
        amount: amount,
        accountId: accountId,
        categoryId: categoryId,
        date: now,
        includeInAnalytics: analytics,
        refundOfTransactionId: refundOf,
        createdAt: now,
        updatedAt: now,
      );

  test('total balance excludes archived, system and excluded accounts', () {
    final state = AppState(AppDatabase());
    state.accounts = [
      account(id: 1, name: 'Main', balance: 1000),
      account(id: 2, name: 'Excluded', balance: 500, includeInTotal: false),
      account(id: 3, name: 'Archived', balance: 300, archived: true),
      account(id: 4, name: 'System', balance: 900, system: true),
    ];

    expect(state.totalBalance, 1000);
    expect(state.activeAccounts.map((item) => item.id), containsAll([1, 2]));
    expect(state.activeAccounts.map((item) => item.id), isNot(contains(3)));
  });

  test('refund reduces effective expense and is not counted as ordinary income', () {
    final state = AppState(AppDatabase());
    state.accounts = [account(id: 1, name: 'Main', balance: 1000)];
    final dinner = transaction(
      id: 10,
      type: TransactionType.expense,
      amount: 120,
      accountId: 1,
    );
    final refund = transaction(
      id: 11,
      type: TransactionType.income,
      amount: 80,
      accountId: 1,
      refundOf: 10,
    );
    state.transactions = [dinner, refund];

    expect(state.refundsFor(10), 80);
    expect(state.effectiveExpense(dinner), 40);
    expect(
      state.periodTotal(
        TransactionType.expense,
        DateTime(2026, 9, 1),
        DateTime(2026, 10, 1),
      ),
      40,
    );
    expect(
      state.periodTotal(
        TransactionType.income,
        DateTime(2026, 9, 1),
        DateTime(2026, 10, 1),
      ),
      0,
    );
  });

  test('excluded transaction is ignored by analytics', () {
    final state = AppState(AppDatabase());
    state.accounts = [account(id: 1, name: 'Main', balance: 1000)];
    state.transactions = [
      transaction(
        id: 1,
        type: TransactionType.expense,
        amount: 50,
        accountId: 1,
        analytics: false,
      ),
      transaction(
        id: 2,
        type: TransactionType.expense,
        amount: 25,
        accountId: 1,
      ),
    ];

    expect(
      state.periodTotal(
        TransactionType.expense,
        DateTime(2026, 9, 1),
        DateTime(2026, 10, 1),
      ),
      25,
    );
  });

  test('category totals use split amounts without duplicating parent amount', () {
    final state = AppState(AppDatabase());
    state.accounts = [account(id: 1, name: 'Main', balance: 1000)];
    state.categories = [category(1, 'Food'), category(2, 'Home')];
    state.transactions = [
      transaction(
        id: 20,
        type: TransactionType.expense,
        amount: 82,
        accountId: 1,
        categoryId: 1,
      ),
    ];
    state.splits = const [
      TransactionSplit(id: 1, transactionId: 20, amount: 54, categoryId: 1),
      TransactionSplit(id: 2, transactionId: 20, amount: 28, categoryId: 2),
    ];

    expect(state.monthCategoryTotal(1, month: now), 54);
    expect(state.monthCategoryTotal(2, month: now), 28);
    expect(state.monthTotal(TransactionType.expense, month: now), 82);
  });

  test('transfers are excluded from analytics by default', () {
    final state = AppState(AppDatabase());
    state.accounts = [
      account(id: 1, name: 'A', balance: 1000),
      account(id: 2, name: 'B', balance: 500),
    ];
    state.transactions = [
      FinanceTransaction(
        id: 30,
        type: TransactionType.transfer,
        amount: 200,
        accountId: 1,
        toAccountId: 2,
        date: now,
        includeInAnalytics: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    expect(state.analyticTransactions().isEmpty, isTrue);
    state.showTransfersInAnalytics = true;
    expect(state.analyticTransactions().length, 1);
  });

  test('weekly budget follows configured first day of week', () {
    final state = AppState(AppDatabase())..weekStart = DateTime.monday;
    final budget = Budget(
      id: 1,
      name: 'Week',
      limit: 100,
      period: BudgetPeriod.weekly,
      startDate: DateTime(2026, 1, 1),
      enabled: true,
    );

    final (from, to) = state.budgetRange(budget, now: now);
    expect(from, DateTime(2026, 8, 31));
    expect(to, DateTime(2026, 9, 7));
  });

  test('monthly budget follows financial month start day', () {
    final state = AppState(AppDatabase())..financialMonthStart = 15;
    final budget = Budget(
      id: 2,
      name: 'Month',
      limit: 500,
      period: BudgetPeriod.monthly,
      startDate: DateTime(2026, 1, 1),
      enabled: true,
    );

    final (from, to) = state.budgetRange(budget, now: now);
    expect(from, DateTime(2026, 8, 15));
    expect(to, DateTime(2026, 9, 15));
  });

  test('custom budget includes the selected end date', () {
    final state = AppState(AppDatabase());
    final budget = Budget(
      id: 3,
      name: 'Trip',
      limit: 300,
      period: BudgetPeriod.custom,
      startDate: DateTime(2026, 9, 2),
      endDate: DateTime(2026, 9, 4),
      enabled: true,
    );

    final (from, to) = state.budgetRange(budget, now: now);
    expect(from, DateTime(2026, 9, 2));
    expect(to, DateTime(2026, 9, 5));
  });

  test('custom category budget counts split values only once', () {
    final state = AppState(AppDatabase());
    state.accounts = [account(id: 1, name: 'Main', balance: 1000)];
    state.categories = [category(1, 'Food'), category(2, 'Home')];
    state.transactions = [
      transaction(
        id: 50,
        type: TransactionType.expense,
        amount: 82,
        accountId: 1,
        categoryId: 1,
      ),
    ];
    state.splits = const [
      TransactionSplit(id: 3, transactionId: 50, amount: 54, categoryId: 1),
      TransactionSplit(id: 4, transactionId: 50, amount: 28, categoryId: 2),
    ];
    final foodBudget = Budget(
      id: 4,
      name: 'Food custom',
      limit: 100,
      period: BudgetPeriod.custom,
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 30),
      enabled: true,
      categoryId: 1,
    );

    expect(state.budgetSpent(foodBudget, now: now), 54);
    expect(state.budgetProgressFor(foodBudget, now: now), closeTo(.54, .0001));
  });

  test('all dashboard widget types have a non-empty label', () {
    expect(DashboardWidgetType.values.length, 22);
    for (final type in DashboardWidgetType.values) {
      expect(type.label.trim(), isNotEmpty);
    }
  });

  test('transaction copyWith preserves immutable identity and updates fields', () {
    final original = transaction(
      id: 40,
      type: TransactionType.expense,
      amount: 10,
      accountId: 1,
    );
    final edited = original.copyWith(
      amount: 25,
      type: TransactionType.income,
      updatedAt: now.add(const Duration(minutes: 1)),
    );

    expect(edited.id, 40);
    expect(edited.amount, 25);
    expect(edited.type, TransactionType.income);
    expect(edited.createdAt, original.createdAt);
  });
}

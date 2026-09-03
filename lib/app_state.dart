import 'dart:math' as math;

import 'package:flutter/foundation.dart' hide Category;

import 'data/app_database.dart';
import 'models/models.dart';
import 'services/widget_service.dart';

class AppState extends ChangeNotifier {
  AppState(this.database, {WidgetService? widgetService})
      : widgetService = widgetService ?? WidgetService();

  final AppDatabase database;
  final WidgetService widgetService;

  List<Account> accounts = [];
  List<Category> categories = [];
  List<FinanceTransaction> transactions = [];
  List<RecurringPayment> recurring = [];
  double monthlyBudget = 0;
  bool hideBalance = false;
  bool loading = true;

  Future<void> load() async {
    accounts = await database.accounts();
    categories = await database.categories();
    transactions = await database.transactions();
    recurring = await database.recurring();
    monthlyBudget = await database.getMonthlyBudget();
    hideBalance = await database.getHideBalance();
    loading = false;
    notifyListeners();
    await syncWidget();
  }

  double get totalBalance => accounts
      .where((a) => a.includeInTotal)
      .fold(0, (sum, item) => sum + item.balance);

  List<Category> categoriesFor(TransactionType type) =>
      categories.where((c) => c.type == type).toList(growable: false);

  Account? accountById(int? id) {
    if (id == null) return null;
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  Category? categoryById(int? id) {
    if (id == null) return null;
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  double monthTotal(TransactionType type, {DateTime? month}) {
    final target = month ?? DateTime.now();
    return transactions
        .where((t) =>
            t.type == type &&
            t.date.year == target.year &&
            t.date.month == target.month)
        .fold(0, (sum, item) => sum + item.amount);
  }

  double monthCategoryTotal(int categoryId, {DateTime? month}) {
    final target = month ?? DateTime.now();
    return transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.categoryId == categoryId &&
            t.date.year == target.year &&
            t.date.month == target.month)
        .fold(0, (sum, item) => sum + item.amount);
  }

  List<MapEntry<Category, double>> topExpenseCategories({int limit = 5}) {
    final items = categoriesFor(TransactionType.expense)
        .map((c) => MapEntry(c, monthCategoryTotal(c.id)))
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return items.take(limit).toList();
  }

  double get budgetProgress => monthlyBudget <= 0
      ? 0
      : math.min(1, monthTotal(TransactionType.expense) / monthlyBudget);

  int transactionCountForAccount(int accountId) => transactions
      .where((t) => t.accountId == accountId || t.toAccountId == accountId)
      .length;

  int recurringCountForAccount(int accountId) =>
      recurring.where((r) => r.accountId == accountId).length;

  int transactionCountForCategory(int categoryId) =>
      transactions.where((t) => t.categoryId == categoryId).length;

  Future<void> addTransaction({
    required TransactionType type,
    required double amount,
    required int accountId,
    int? toAccountId,
    int? categoryId,
    required DateTime date,
    String? note,
    List<String> tags = const [],
    String? receiptPath,
  }) async {
    await database.addTransaction(
      type: type,
      amount: amount,
      accountId: accountId,
      toAccountId: toAccountId,
      categoryId: categoryId,
      date: date,
      note: note,
      tags: tags,
      receiptPath: receiptPath,
    );
    await _refreshCore();
  }

  Future<void> deleteTransaction(FinanceTransaction item) async {
    await database.deleteTransaction(item);
    await _refreshCore();
  }

  Future<void> addAccount(String name, double balance, int colorValue) async {
    await database.addAccount(name, balance, colorValue);
    accounts = await database.accounts();
    notifyListeners();
    await syncWidget();
  }

  Future<void> deleteAccount(Account account) async {
    await database.deleteAccount(account.id);
    accounts = await database.accounts();
    transactions = await database.transactions();
    recurring = await database.recurring();
    notifyListeners();
    await syncWidget();
  }

  Future<void> setAccountIncluded(Account account, bool included) async {
    await database.setAccountIncluded(account.id, included);
    accounts = await database.accounts();
    notifyListeners();
    await syncWidget();
  }

  Future<Category> addCategory({
    required String name,
    required TransactionType type,
    required String iconKey,
    required int colorValue,
  }) async {
    final id = await database.addCategory(
      name: name,
      type: type,
      iconKey: iconKey,
      colorValue: colorValue,
    );
    categories = await database.categories();
    final created = categoryById(id)!;
    notifyListeners();
    await syncWidget();
    return created;
  }

  Future<void> deleteCategory(Category category) async {
    await database.deleteCategory(category.id);
    categories = await database.categories();
    transactions = await database.transactions();
    recurring = await database.recurring();
    notifyListeners();
    await syncWidget();
  }

  Future<void> addRecurring({
    required String name,
    required double amount,
    required TransactionType type,
    required int accountId,
    int? categoryId,
    required String frequency,
    required DateTime nextDate,
  }) async {
    await database.addRecurring(
      name: name,
      amount: amount,
      type: type,
      accountId: accountId,
      categoryId: categoryId,
      frequency: frequency,
      nextDate: nextDate,
    );
    recurring = await database.recurring();
    notifyListeners();
  }

  Future<void> setRecurringEnabled(RecurringPayment item, bool enabled) async {
    await database.setRecurringEnabled(item.id, enabled);
    recurring = await database.recurring();
    notifyListeners();
  }

  Future<void> deleteRecurring(RecurringPayment item) async {
    await database.deleteRecurring(item.id);
    recurring = await database.recurring();
    notifyListeners();
  }

  Future<void> setMonthlyBudget(double value) async {
    monthlyBudget = value;
    await database.setSetting('monthly_budget', value.toString());
    notifyListeners();
  }

  Future<void> setHideBalance(bool value) async {
    hideBalance = value;
    await database.setSetting('hide_balance', value ? '1' : '0');
    notifyListeners();
  }

  Future<void> _refreshCore() async {
    accounts = await database.accounts();
    transactions = await database.transactions();
    notifyListeners();
    await syncWidget();
  }

  Future<void> syncWidget() => widgetService.sync(
        balance: totalBalance,
        expenseCategories: categoriesFor(TransactionType.expense),
      );
}

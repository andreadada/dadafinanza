import 'dart:math' as math;

import 'package:flutter/foundation.dart' hide Category;

import 'data/app_database.dart';
import 'models/models.dart';
import 'services/widget_service.dart';

class AppState extends ChangeNotifier {
  AppState(this.database, {WidgetService? widgetService}) : widgetService = widgetService ?? WidgetService();

  final AppDatabase database;
  final WidgetService widgetService;

  List<Account> accounts = [];
  List<Category> categories = [];
  List<FinanceTransaction> transactions = [];
  List<TransactionSplit> splits = [];
  List<RecurringPayment> recurring = [];
  List<Budget> budgets = [];
  List<Goal> goals = [];
  List<DashboardWidgetConfig> dashboardWidgets = [];
  List<AutomationRule> rules = [];
  List<Map<String, Object?>> netWorthSnapshots = [];

  bool loading = true;
  bool hideBalance = false;
  bool allowUnassigned = true;
  bool showTransfersInAnalytics = false;
  bool confirmDelete = true;
  bool showCents = true;
  bool haptics = true;
  String currency = 'EUR';
  AppThemePreference themePreference = AppThemePreference.system;
  int weekStart = 1;
  int financialMonthStart = 1;

  Future<void> load() async {
    await _reloadAll();
    await _processDueRecurring();
    loading = false;
    notifyListeners();
    await database.snapshotNetWorth(totalBalance);
    netWorthSnapshots = await database.netWorthSnapshots();
    await syncWidget();
  }

  Future<void> _reloadAll() async {
    accounts = await database.accounts();
    categories = await database.categories();
    transactions = await database.transactions();
    splits = await database.splits();
    recurring = await database.recurring();
    budgets = await database.budgets();
    goals = await database.goals();
    dashboardWidgets = await database.dashboardWidgets();
    rules = await database.rules();
    netWorthSnapshots = await database.netWorthSnapshots();
    hideBalance = (await database.getSetting('hide_balance') ?? '0') == '1';
    allowUnassigned = (await database.getSetting('allow_unassigned') ?? '1') == '1';
    showTransfersInAnalytics = (await database.getSetting('show_transfers_analytics') ?? '0') == '1';
    confirmDelete = (await database.getSetting('confirm_delete') ?? '1') == '1';
    showCents = (await database.getSetting('show_cents') ?? '1') == '1';
    haptics = (await database.getSetting('haptics') ?? '1') == '1';
    currency = await database.getSetting('currency') ?? 'EUR';
    weekStart = int.tryParse(await database.getSetting('week_start') ?? '1') ?? 1;
    financialMonthStart = int.tryParse(await database.getSetting('financial_month_start') ?? '1') ?? 1;
    final theme = await database.getSetting('theme_mode') ?? 'system';
    themePreference = AppThemePreference.values.firstWhere((e) => e.name == theme, orElse: () => AppThemePreference.system);
  }

  Future<void> _processDueRecurring() async {
    final now = DateTime.now();
    var changed = false;
    for (final item in [...recurring]) {
      if (!item.enabled || !item.autoCreate || item.nextDate.isAfter(now)) continue;
      final account = accountById(item.accountId);
      if (account == null || account.isLocked || account.isArchived || account.isSystem) continue;
      var next = item.nextDate;
      var safety = 0;
      while (!next.isAfter(now) && safety < 24) {
        if (item.endDate != null && next.isAfter(item.endDate!)) break;
        await database.addTransaction(
          type: item.type,
          amount: item.amount,
          accountId: item.accountId,
          categoryId: item.categoryId,
          date: next,
          note: item.note,
          recurringId: item.id,
        );
        next = _advanceRecurring(next, item.frequency);
        safety++;
        changed = true;
      }
      if (next != item.nextDate) {
        await database.updateRecurring(RecurringPayment(
          id: item.id,
          name: item.name,
          amount: item.amount,
          type: item.type,
          accountId: item.accountId,
          frequency: item.frequency,
          nextDate: next,
          enabled: item.enabled,
          autoCreate: item.autoCreate,
          categoryId: item.categoryId,
          note: item.note,
          endDate: item.endDate,
        ));
      }
    }
    if (changed) await _reloadAll();
  }

  DateTime _advanceRecurring(DateTime date, String frequency) => switch (frequency) {
        'Settimanale' => date.add(const Duration(days: 7)),
        'Trimestrale' => DateTime(date.year, date.month + 3, date.day, date.hour, date.minute),
        'Annuale' => DateTime(date.year + 1, date.month, date.day, date.hour, date.minute),
        _ => DateTime(date.year, date.month + 1, date.day, date.hour, date.minute),
      };

  List<Account> get userAccounts => accounts.where((a) => !a.isSystem).toList(growable: false);
  List<Account> get activeAccounts => accounts.where((a) => !a.isSystem && !a.isArchived).toList(growable: false);
  List<Account> get archivedAccounts => accounts.where((a) => !a.isSystem && a.isArchived).toList(growable: false);
  Account? get unassignedAccount => accounts.where((a) => a.isSystem).firstOrNull;
  int get unassignedCount => unassignedAccount == null ? 0 : transactions.where((t) => t.accountId == unassignedAccount!.id).length;

  double get totalBalance => accounts.where((a) => !a.isSystem && !a.isArchived && a.includeInTotal).fold(0, (sum, item) => sum + item.balance);
  double get allVisibleBalances => activeAccounts.fold(0, (sum, item) => sum + item.balance);

  Account? accountById(int? id) => id == null ? null : accounts.where((a) => a.id == id).firstOrNull;
  Category? categoryById(int? id) => id == null ? null : categories.where((c) => c.id == id).firstOrNull;
  FinanceTransaction? transactionById(int? id) => id == null ? null : transactions.where((t) => t.id == id).firstOrNull;
  List<TransactionSplit> splitsFor(int transactionId) => splits.where((s) => s.transactionId == transactionId).toList();
  List<Category> categoriesFor(TransactionType type) => categories.where((c) => c.type == type).toList(growable: false);

  Iterable<FinanceTransaction> analyticTransactions({DateTime? from, DateTime? to}) => transactions.where((t) {
        if (!t.includeInAnalytics) return false;
        final account = accountById(t.accountId);
        if (account != null && !account.isSystem && !account.includeInAnalytics) return false;
        if (t.type == TransactionType.transfer && !showTransfersInAnalytics) return false;
        if (from != null && t.date.isBefore(from)) return false;
        if (to != null && !t.date.isBefore(to)) return false;
        return true;
      });

  double refundsFor(int transactionId) => transactions
      .where((t) => t.refundOfTransactionId == transactionId && t.type == TransactionType.income)
      .fold(0, (sum, item) => sum + item.amount);

  double effectiveExpense(FinanceTransaction t) => math.max(0, t.amount - refundsFor(t.id));

  double periodTotal(TransactionType type, DateTime from, DateTime to) {
    var total = 0.0;
    for (final t in analyticTransactions(from: from, to: to)) {
      if (t.type != type) continue;
      if (type == TransactionType.income && t.refundOfTransactionId != null) continue;
      total += type == TransactionType.expense ? effectiveExpense(t) : t.amount;
    }
    return total;
  }

  double monthTotal(TransactionType type, {DateTime? month}) {
    final target = month ?? DateTime.now();
    final from = DateTime(target.year, target.month);
    final to = DateTime(target.year, target.month + 1);
    return periodTotal(type, from, to);
  }

  double accountMonthTotal(int accountId, TransactionType type, {DateTime? month}) {
    final target = month ?? DateTime.now();
    final from = DateTime(target.year, target.month);
    final to = DateTime(target.year, target.month + 1);
    return analyticTransactions(from: from, to: to)
        .where((t) => t.accountId == accountId && t.type == type)
        .fold(0.0, (sum, t) => sum + (type == TransactionType.expense ? effectiveExpense(t) : t.amount));
  }

  double monthCategoryTotal(int categoryId, {DateTime? month}) {
    final target = month ?? DateTime.now();
    final from = DateTime(target.year, target.month);
    final to = DateTime(target.year, target.month + 1);
    var total = 0.0;
    for (final t in analyticTransactions(from: from, to: to).where((t) => t.type == TransactionType.expense)) {
      final itemSplits = splitsFor(t.id);
      if (itemSplits.isNotEmpty) {
        total += itemSplits.where((s) => s.categoryId == categoryId).fold(0.0, (sum, s) => sum + s.amount);
      } else if (t.categoryId == categoryId) {
        total += effectiveExpense(t);
      }
    }
    return total;
  }

  List<MapEntry<Category, double>> topExpenseCategories({int limit = 5}) {
    final items = categoriesFor(TransactionType.expense)
        .map((c) => MapEntry(c, monthCategoryTotal(c.id)))
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return items.take(limit).toList();
  }

  List<String> get allTags {
    final values = <String>{};
    for (final t in transactions) {
      values.addAll(t.tags);
    }
    return values.toList()..sort();
  }

  double get monthlyCashFlow => monthTotal(TransactionType.income) - monthTotal(TransactionType.expense);
  double get safeToSpend {
    final now = DateTime.now();
    final monthEnd = DateTime(now.year, now.month + 1);
    final upcomingExpense = recurring.where((r) => r.enabled && r.type == TransactionType.expense && !r.nextDate.isBefore(now) && r.nextDate.isBefore(monthEnd)).fold(0.0, (sum, r) => sum + r.amount);
    final goalReserve = goals.where((g) => !g.archived && !g.completed).fold(0.0, (sum, g) => sum + math.max(0, g.targetAmount - g.currentAmount));
    return math.max(0, totalBalance - upcomingExpense - math.min(goalReserve, totalBalance * .25)).toDouble();
  }

  double get endOfMonthForecast {
    final now = DateTime.now();
    final monthEnd = DateTime(now.year, now.month + 1);
    var result = totalBalance;
    for (final r in recurring.where((r) => r.enabled && !r.nextDate.isBefore(now) && r.nextDate.isBefore(monthEnd))) {
      result += r.type == TransactionType.income ? r.amount : r.type == TransactionType.expense ? -r.amount : 0;
    }
    return result;
  }

  double get todayExpense {
    final now = DateTime.now();
    return periodTotal(TransactionType.expense, DateTime(now.year, now.month, now.day), DateTime(now.year, now.month, now.day + 1));
  }

  double get weekExpense {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    return periodTotal(TransactionType.expense, start, start.add(const Duration(days: 7)));
  }

  int get noSpendDaysThisMonth {
    final now = DateTime.now();
    final days = <int>{};
    for (final t in analyticTransactions(from: DateTime(now.year, now.month), to: DateTime(now.year, now.month + 1)).where((t) => t.type == TransactionType.expense)) {
      days.add(t.date.day);
    }
    return math.max(0, now.day - days.length).toInt();
  }

  double get dailyAverageExpense {
    final now = DateTime.now();
    return now.day == 0 ? 0 : monthTotal(TransactionType.expense) / now.day;
  }

  int transactionCountForAccount(int accountId) => transactions.where((t) => t.accountId == accountId || t.toAccountId == accountId).length;
  int recurringCountForAccount(int accountId) => recurring.where((r) => r.accountId == accountId).length;
  int transactionCountForCategory(int categoryId) => transactions.where((t) => t.categoryId == categoryId).length + splits.where((s) => s.categoryId == categoryId).length;

  Future<void> addTransaction({required TransactionType type, required double amount, required int accountId, int? toAccountId, int? categoryId, required DateTime date, String? note, List<String> tags = const [], String? receiptPath, bool includeInAnalytics = true, int? refundOfTransactionId}) async {
    await database.addTransaction(type: type, amount: amount, accountId: accountId, toAccountId: toAccountId, categoryId: categoryId, date: date, note: note, tags: tags, receiptPath: receiptPath, includeInAnalytics: includeInAnalytics, refundOfTransactionId: refundOfTransactionId);
    await refreshCore();
  }

  Future<void> updateTransaction(FinanceTransaction oldItem, FinanceTransaction newItem) async {
    await database.updateTransaction(oldItem, newItem);
    await refreshCore();
  }

  Future<void> duplicateTransaction(FinanceTransaction item) async {
    await database.duplicateTransaction(item);
    await refreshCore();
  }

  Future<void> deleteTransaction(FinanceTransaction item) async {
    await database.deleteTransaction(item);
    await refreshCore();
  }

  Future<void> replaceSplits(int transactionId, List<TransactionSplit> items, double amount) async {
    await database.replaceSplits(transactionId, items, amount);
    splits = await database.splits();
    notifyListeners();
  }

  Future<Account> addAccount({required String name, double balance = 0, int colorValue = 0xFF8E8E93, String iconKey = 'wallet', AccountType type = AccountType.other, bool includeInTotal = true, bool includeInAnalytics = true, bool hideBalance = false, String? note}) async {
    final id = await database.addAccount(name: name, balance: balance, colorValue: colorValue, iconKey: iconKey, type: type, includeInTotal: includeInTotal, includeInAnalytics: includeInAnalytics, hideBalance: hideBalance, note: note);
    accounts = await database.accounts();
    notifyListeners();
    await syncWidget();
    return accountById(id)!;
  }

  Future<void> updateAccount(Account account) async {
    await database.updateAccount(account);
    accounts = await database.accounts();
    notifyListeners();
    await database.snapshotNetWorth(totalBalance);
    await syncWidget();
  }

  Future<void> deleteAccount(Account account) async {
    await database.deleteAccount(account.id);
    await refreshCore(includePlanning: true);
  }

  Future<Category> addCategory({required String name, required TransactionType type, required String iconKey, required int colorValue}) async {
    final id = await database.addCategory(name: name, type: type, iconKey: iconKey, colorValue: colorValue);
    categories = await database.categories();
    final created = categoryById(id)!;
    notifyListeners();
    await syncWidget();
    return created;
  }

  Future<void> updateCategory(Category category) async {
    await database.updateCategory(category);
    categories = await database.categories();
    notifyListeners();
    await syncWidget();
  }

  Future<void> deleteCategory(Category category) async {
    await database.deleteCategory(category.id);
    await refreshCore(includePlanning: true);
  }

  Future<void> addRecurring({required String name, required double amount, required TransactionType type, required int accountId, int? categoryId, required String frequency, required DateTime nextDate, String? note, DateTime? endDate, bool autoCreate = false}) async {
    await database.addRecurring(name: name, amount: amount, type: type, accountId: accountId, categoryId: categoryId, frequency: frequency, nextDate: nextDate, note: note, endDate: endDate, autoCreate: autoCreate);
    recurring = await database.recurring();
    notifyListeners();
  }

  Future<void> updateRecurring(RecurringPayment item) async {
    await database.updateRecurring(item);
    recurring = await database.recurring();
    notifyListeners();
  }

  Future<void> deleteRecurring(RecurringPayment item) async {
    await database.deleteRecurring(item.id);
    recurring = await database.recurring();
    notifyListeners();
  }

  Future<void> addBudget({required String name, int? categoryId, required double limit, BudgetPeriod period = BudgetPeriod.monthly, DateTime? startDate, DateTime? endDate}) async {
    await database.addBudget(name: name, categoryId: categoryId, limit: limit, period: period, startDate: startDate ?? DateTime(DateTime.now().year, DateTime.now().month), endDate: endDate);
    budgets = await database.budgets();
    notifyListeners();
  }

  Future<void> updateBudget(Budget item) async { await database.updateBudget(item); budgets = await database.budgets(); notifyListeners(); }
  Future<void> deleteBudget(Budget item) async { await database.deleteBudget(item.id); budgets = await database.budgets(); notifyListeners(); }

  double budgetSpent(Budget budget) => budget.categoryId == null ? monthTotal(TransactionType.expense) : monthCategoryTotal(budget.categoryId!);
  double budgetProgressFor(Budget budget) => budget.limit <= 0 ? 0 : budgetSpent(budget) / budget.limit;

  Future<void> addGoal({required String name, required double targetAmount, String iconKey = 'savings', int colorValue = 0xFF8E8E93, DateTime? targetDate, int? linkedAccountId}) async {
    await database.addGoal(name: name, iconKey: iconKey, colorValue: colorValue, targetAmount: targetAmount, targetDate: targetDate, linkedAccountId: linkedAccountId);
    goals = await database.goals(); notifyListeners();
  }
  Future<void> updateGoal(Goal item) async { await database.updateGoal(item); goals = await database.goals(); notifyListeners(); }
  Future<void> deleteGoal(Goal item) async { await database.deleteGoal(item.id); goals = await database.goals(); notifyListeners(); }
  Future<void> contributeGoal(Goal item, double delta) async {
    final current = math.max(0, math.min(item.targetAmount, item.currentAmount + delta)).toDouble();
    await updateGoal(Goal(id: item.id, name: item.name, iconKey: item.iconKey, colorValue: item.colorValue, targetAmount: item.targetAmount, currentAmount: current, targetDate: item.targetDate, linkedAccountId: item.linkedAccountId, archived: item.archived, completed: current >= item.targetAmount));
  }

  Future<void> saveDashboard(List<DashboardWidgetConfig> items) async {
    dashboardWidgets = items;
    await database.saveDashboardWidgets(items);
    notifyListeners();
  }

  Future<void> resetDashboard() async {
    final defaults = <DashboardWidgetType>[
      DashboardWidgetType.totalBalance,
      DashboardWidgetType.monthlyCashFlow,
      DashboardWidgetType.safeToSpend,
      DashboardWidgetType.accounts,
      DashboardWidgetType.monthlyBudget,
      DashboardWidgetType.recentTransactions,
      DashboardWidgetType.upcomingRecurring,
      DashboardWidgetType.goals,
      DashboardWidgetType.topCategories,
      DashboardWidgetType.endMonthForecast,
      DashboardWidgetType.unassignedTransactions,
    ];
    final items = <DashboardWidgetConfig>[];
    for (var i = 0; i < DashboardWidgetType.values.length; i++) {
      final type = DashboardWidgetType.values[i];
      final index = defaults.indexOf(type);
      items.add(DashboardWidgetConfig(type: type, enabled: index >= 0, orderIndex: index >= 0 ? index : defaults.length + i, size: DashboardWidgetSize.medium));
    }
    await saveDashboard(items);
  }

  Future<void> addRule(AutomationRule rule) async { await database.addRule(rule); rules = await database.rules(); notifyListeners(); }
  Future<void> deleteRule(AutomationRule rule) async { await database.deleteRule(rule.id); rules = await database.rules(); notifyListeners(); }

  Future<void> setSetting(String key, String value) async {
    await database.setSetting(key, value);
    await _loadSettingsOnly();
    notifyListeners();
  }

  Future<void> _loadSettingsOnly() async {
    hideBalance = (await database.getSetting('hide_balance') ?? '0') == '1';
    allowUnassigned = (await database.getSetting('allow_unassigned') ?? '1') == '1';
    showTransfersInAnalytics = (await database.getSetting('show_transfers_analytics') ?? '0') == '1';
    confirmDelete = (await database.getSetting('confirm_delete') ?? '1') == '1';
    showCents = (await database.getSetting('show_cents') ?? '1') == '1';
    haptics = (await database.getSetting('haptics') ?? '1') == '1';
    currency = await database.getSetting('currency') ?? 'EUR';
    final theme = await database.getSetting('theme_mode') ?? 'system';
    themePreference = AppThemePreference.values.firstWhere((e) => e.name == theme, orElse: () => AppThemePreference.system);
  }

  Future<void> setHideBalance(bool value) => setSetting('hide_balance', value ? '1' : '0');
  Future<void> setThemePreference(AppThemePreference value) => setSetting('theme_mode', value.name);

  Future<void> refreshCore({bool includePlanning = false}) async {
    accounts = await database.accounts();
    transactions = await database.transactions();
    splits = await database.splits();
    if (includePlanning) {
      categories = await database.categories();
      recurring = await database.recurring();
      budgets = await database.budgets();
      goals = await database.goals();
    }
    notifyListeners();
    await database.snapshotNetWorth(totalBalance);
    await syncWidget();
  }

  Future<int> importCsv(String content) async {
    final lines = content.split(RegExp(r'\r?\n')).where((line) => line.trim().isNotEmpty).toList();
    if (lines.length <= 1) return 0;
    var imported = 0;
    final fallback = unassignedAccount?.id ?? await database.unassignedAccountId();
    for (final line in lines.skip(1)) {
      final fields = _parseCsvLine(line);
      if (fields.length < 10) continue;
      final type = TransactionTypeX.fromDb(fields[1]);
      final amount = double.tryParse(fields[2]);
      final originalAccountId = int.tryParse(fields[3]);
      final account = accountById(originalAccountId);
      final accountId = account == null || account.isArchived || account.isLocked ? fallback : account.id;
      final toIdRaw = int.tryParse(fields[4]);
      final toAccount = accountById(toIdRaw);
      final categoryRaw = int.tryParse(fields[5]);
      final date = DateTime.tryParse(fields[6]);
      if (amount == null || amount <= 0 || date == null) continue;
      if (type == TransactionType.transfer && (toAccount == null || toAccount.isArchived || toAccount.isLocked || toAccount.id == accountId)) continue;
      await database.addTransaction(
        type: type,
        amount: amount,
        accountId: accountId,
        toAccountId: type == TransactionType.transfer ? toAccount!.id : null,
        categoryId: type == TransactionType.transfer || categoryById(categoryRaw) == null ? null : categoryRaw,
        date: date,
        note: fields[7].isEmpty ? null : fields[7],
        tags: fields[8].split('|').where((e) => e.isNotEmpty).toList(),
        includeInAnalytics: fields[9] != '0',
      );
      imported++;
    }
    await refreshCore(includePlanning: true);
    return imported;
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  Future<void> clearAllUserData() async {
    await database.clearAllUserData();
    await _reloadAll();
    notifyListeners();
    await syncWidget();
  }

  Future<String> exportCsv() => database.exportTransactionsCsv();
  Future<String> databaseFilePath() => database.databaseFilePath();
  Future<void> restoreDatabaseFrom(String path) async { await database.restoreDatabaseFrom(path); loading = true; notifyListeners(); await load(); }
  Future<void> syncWidget() => widgetService.sync(balance: totalBalance, expenseCategories: categoriesFor(TransactionType.expense));
}

extension FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

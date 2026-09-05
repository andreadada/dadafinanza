import 'dart:math' as math;

import 'package:flutter/foundation.dart' hide Category;

import 'core/money.dart';
import 'data/app_database.dart';
import 'models/advance_models.dart';
import 'models/models.dart';
import 'models/smart_models.dart';
import 'services/advance_service.dart';
import 'services/goal_ledger_service.dart';
import 'services/smart_finance_engine.dart';
import 'services/widget_service.dart';

class AppState extends ChangeNotifier {
  AppState(this.database, {WidgetService? widgetService})
    : widgetService = widgetService ?? WidgetService();

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
  List<FinancePerson> people = [];
  List<Advance> advances = [];
  List<AdvanceSettlement> advanceSettlements = [];
  List<LearnedPattern> learnedPatterns = [];
  List<DetectedRecurringPattern> detectedRecurringPatterns = [];
  Set<String> suppressedSuggestionTexts = {};
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

  bool smartSuggestionsEnabled = true;
  bool smartUseDescription = true;
  bool smartUseAmount = true;
  bool smartUseTime = true;
  bool smartDetectRecurring = true;
  bool smartGoalSuggestions = true;
  SmartSensitivity smartSensitivity = SmartSensitivity.balanced;

  Future<void> load() async {
    await _reloadAll();
    await _processDueRecurring();
    if (smartSuggestionsEnabled) {
      await _rebuildLearning(notify: false);
    }
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
    final advanceService = AdvanceService(database);
    people = await advanceService.people(includeArchived: true);
    advances = await advanceService.advances();
    advanceSettlements = await advanceService.settlements();
    learnedPatterns = await database.learnedPatterns();
    detectedRecurringPatterns = await database.detectedRecurringPatterns();
    suppressedSuggestionTexts = await database.suppressedSuggestionTexts();
    netWorthSnapshots = await database.netWorthSnapshots();
    await _loadSettingsOnly();
  }

  Future<void> _processDueRecurring() async {
    final now = DateTime.now();
    var changed = false;
    for (final item in [...recurring]) {
      if (!item.enabled || !item.autoCreate || item.nextDate.isAfter(now))
        continue;
      final account = accountById(item.accountId);
      if (account == null ||
          account.isLocked ||
          account.isArchived ||
          account.isSystem)
        continue;
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
          note: item.note ?? item.name,
          recurringId: item.id,
        );
        next = _advanceRecurring(next, item.frequency);
        safety++;
        changed = true;
      }
      if (next != item.nextDate) {
        await database.updateRecurring(
          RecurringPayment(
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
          ),
        );
      }
    }
    if (changed) await _reloadAll();
  }

  DateTime _advanceRecurring(DateTime date, String frequency) =>
      switch (frequency) {
        'Settimanale' => date.add(const Duration(days: 7)),
        'Quindicinale' => date.add(const Duration(days: 14)),
        'Trimestrale' => DateTime(
          date.year,
          date.month + 3,
          date.day,
          date.hour,
          date.minute,
        ),
        'Annuale' => DateTime(
          date.year + 1,
          date.month,
          date.day,
          date.hour,
          date.minute,
        ),
        _ => DateTime(
          date.year,
          date.month + 1,
          date.day,
          date.hour,
          date.minute,
        ),
      };

  List<Account> get userAccounts =>
      accounts.where((a) => !a.isSystem).toList(growable: false);
  List<Account> get activeAccounts => accounts
      .where((a) => !a.isSystem && !a.isArchived)
      .toList(growable: false);
  List<Account> get archivedAccounts => accounts
      .where((a) => !a.isSystem && a.isArchived)
      .toList(growable: false);
  Account? get unassignedAccount =>
      accounts.where((a) => a.isSystem).firstOrNull;
  int get unassignedCount => unassignedAccount == null
      ? 0
      : transactions.where((t) => t.accountId == unassignedAccount!.id).length;

  double get totalBalance => accounts
      .where((a) => !a.isSystem && !a.isArchived && a.includeInTotal)
      .fold(0, (sum, item) => sum + item.balance);
  double get allVisibleBalances =>
      activeAccounts.fold(0, (sum, item) => sum + item.balance);

  Account? accountById(int? id) =>
      id == null ? null : accounts.where((a) => a.id == id).firstOrNull;
  Category? categoryById(int? id) =>
      id == null ? null : categories.where((c) => c.id == id).firstOrNull;
  FinanceTransaction? transactionById(int? id) =>
      id == null ? null : transactions.where((t) => t.id == id).firstOrNull;
  List<TransactionSplit> splitsFor(int transactionId) =>
      splits.where((s) => s.transactionId == transactionId).toList();
  List<Category> categoriesFor(TransactionType type) =>
      categories.where((c) => c.type == type).toList(growable: false);

  FinancePerson? personById(int? id) =>
      id == null ? null : people.where((item) => item.id == id).firstOrNull;

  List<AdvanceSettlement> settlementsForAdvance(int advanceId) =>
      advanceSettlements
          .where((item) => item.advanceId == advanceId)
          .toList(growable: false);

  Advance? advanceForSourceTransaction(int transactionId) => advances
      .where((item) => item.sourceTransactionId == transactionId)
      .firstOrNull;

  AdvanceSettlement? settlementForTransaction(int transactionId) =>
      advanceSettlements
          .where((item) => item.transactionId == transactionId)
          .firstOrNull;

  Advance? advanceForSettlementTransaction(int transactionId) {
    final settlement = settlementForTransaction(transactionId);
    if (settlement == null) return null;
    return advances
        .where((item) => item.id == settlement.advanceId)
        .firstOrNull;
  }

  int advanceRemainingCents(int advanceId) {
    final advance = advances.where((item) => item.id == advanceId).firstOrNull;
    if (advance == null) return 0;
    final settled = settlementsForAdvance(
      advanceId,
    ).fold<int>(0, (sum, item) => sum + item.amountCents);
    return math.max(0, advance.originalAmountCents - settled).toInt();
  }

  AdvanceStatus advanceStatus(Advance advance, {DateTime? now}) {
    switch (advance.closedKind) {
      case AdvanceClosedKind.cancelled:
        return AdvanceStatus.cancelled;
      case AdvanceClosedKind.writtenOff:
        return AdvanceStatus.writtenOff;
      case AdvanceClosedKind.forgiven:
        return AdvanceStatus.forgiven;
      case null:
        break;
    }
    final remaining = advanceRemainingCents(advance.id);
    if (remaining <= 0) return AdvanceStatus.settled;
    final due = advance.dueDate;
    final target = now ?? DateTime.now();
    if (due != null &&
        DateTime(
          due.year,
          due.month,
          due.day,
        ).isBefore(DateTime(target.year, target.month, target.day))) {
      return AdvanceStatus.overdue;
    }
    if (remaining < advance.originalAmountCents) return AdvanceStatus.partial;
    return AdvanceStatus.open;
  }

  int get advanceReceivableCents => advances
      .where(
        (item) =>
            item.direction == AdvanceDirection.receivable &&
            item.closedKind == null,
      )
      .fold<int>(0, (sum, item) => sum + advanceRemainingCents(item.id));

  int get advancePayableCents => advances
      .where(
        (item) =>
            item.direction == AdvanceDirection.payable &&
            item.closedKind == null,
      )
      .fold<int>(0, (sum, item) => sum + advanceRemainingCents(item.id));

  int get advanceNetCents => advanceReceivableCents - advancePayableCents;

  int advanceAllocationCentsForTransaction(int transactionId) => advances
      .where(
        (item) =>
            item.sourceTransactionId == transactionId &&
            item.direction == AdvanceDirection.receivable &&
            item.closedKind != AdvanceClosedKind.cancelled,
      )
      .fold<int>(0, (sum, item) => sum + item.originalAmountCents);

  double analyticsAmountForSplit(int transactionId, TransactionSplit split) {
    final original = transactionById(transactionId);
    if (original == null || original.kind != 'mixed_advance')
      return split.amount;
    final totalCents = Money.toCents(original.amount);
    if (totalCents <= 0) return 0;
    final personalCents = math
        .max(
          0,
          totalCents - advanceAllocationCentsForTransaction(transactionId),
        )
        .toInt();
    final splitCents = Money.toCents(split.amount);
    return Money.fromCents((splitCents * personalCents / totalCents).round());
  }

  int advanceSettledInPeriodCents(DateTime from, DateTime to) =>
      advanceSettlements
          .where((item) => !item.date.isBefore(from) && item.date.isBefore(to))
          .fold<int>(0, (sum, item) => sum + item.amountCents);

  bool isAdvanceProtectedTransaction(FinanceTransaction item) =>
      item.kind == 'advance_origin' ||
      item.kind == 'mixed_advance' ||
      item.kind == 'advance_settlement' ||
      item.kind == 'advance_writeoff' ||
      item.kind == 'advance_forgiven_income';

  Iterable<FinanceTransaction> analyticTransactions({
    DateTime? from,
    DateTime? to,
  }) sync* {
    for (final transaction in transactions) {
      if (!transaction.includeInAnalytics) continue;
      final account = accountById(transaction.accountId);
      if (account != null && !account.isSystem && !account.includeInAnalytics) {
        continue;
      }
      if (transaction.type == TransactionType.transfer &&
          !showTransfersInAnalytics) {
        continue;
      }
      if (from != null && transaction.date.isBefore(from)) continue;
      if (to != null && !transaction.date.isBefore(to)) continue;

      var projected = transaction;
      if (transaction.type == TransactionType.expense &&
          transaction.kind == 'mixed_advance') {
        final originalCents = Money.toCents(transaction.amount);
        final personalCents = math
            .max(
              0,
              originalCents -
                  advanceAllocationCentsForTransaction(transaction.id),
            )
            .toInt();
        if (personalCents <= 0) continue;
        projected = transaction.copyWith(
          amount: Money.fromCents(personalCents),
        );
      }
      yield projected;
    }
  }

  double refundsFor(int transactionId) => transactions
      .where(
        (t) =>
            t.refundOfTransactionId == transactionId &&
            t.type == TransactionType.income,
      )
      .fold(0, (sum, item) => sum + item.amount);

  double effectiveExpense(FinanceTransaction t) =>
      math.max(0, t.amount - refundsFor(t.id)).toDouble();

  double periodTotal(TransactionType type, DateTime from, DateTime to) {
    var total = 0.0;
    for (final t in analyticTransactions(from: from, to: to)) {
      if (t.type != type) continue;
      if (type == TransactionType.income && t.refundOfTransactionId != null)
        continue;
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

  double accountMonthTotal(
    int accountId,
    TransactionType type, {
    DateTime? month,
  }) {
    final target = month ?? DateTime.now();
    final from = DateTime(target.year, target.month);
    final to = DateTime(target.year, target.month + 1);
    return analyticTransactions(from: from, to: to)
        .where((t) => t.accountId == accountId && t.type == type)
        .fold(
          0.0,
          (sum, t) =>
              sum +
              (type == TransactionType.expense
                  ? effectiveExpense(t)
                  : t.amount),
        );
  }

  double monthCategoryTotal(int categoryId, {DateTime? month}) {
    final target = month ?? DateTime.now();
    final from = DateTime(target.year, target.month);
    final to = DateTime(target.year, target.month + 1);
    var total = 0.0;
    for (final t in analyticTransactions(
      from: from,
      to: to,
    ).where((t) => t.type == TransactionType.expense)) {
      final itemSplits = splitsFor(t.id);
      if (itemSplits.isNotEmpty) {
        total += itemSplits
            .where((s) => s.categoryId == categoryId)
            .fold(0.0, (sum, s) => sum + analyticsAmountForSplit(t.id, s));
      } else if (t.categoryId == categoryId) {
        total += effectiveExpense(t);
      }
    }
    return total;
  }

  List<MapEntry<Category, double>> topExpenseCategories({int limit = 5}) {
    final items =
        categoriesFor(TransactionType.expense)
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

  double get monthlyCashFlow =>
      monthTotal(TransactionType.income) - monthTotal(TransactionType.expense);

  ForecastSummary forecastForDays(int days, {DateTime? now}) =>
      SmartFinanceEngine.forecast(
        days: days,
        startingBalance: totalBalance,
        transactions: analyticTransactions().toList(),
        recurring: recurring,
        detectedRecurring: detectedRecurringPatterns,
        now: now,
      );

  double get safeToSpend {
    final forecast = forecastForDays(30);
    final weeklyExpenses = SmartFinanceEngine.weeklyTotals(
      analyticTransactions().toList(),
      TransactionType.expense,
    );
    final medianWeek = SmartFinanceEngine.median(
      weeklyExpenses.where((value) => value > 0),
    );
    final safetyBuffer = math.max(totalBalance * .12, medianWeek).toDouble();
    return math
        .max(0, math.min(totalBalance, forecast.endingBalance - safetyBuffer))
        .toDouble();
  }

  double get endOfMonthForecast {
    final now = DateTime.now();
    final days = math.max(
      1,
      DateTime(now.year, now.month + 1).difference(now).inDays,
    );
    return forecastForDays(days).endingBalance;
  }

  double get todayExpense {
    final now = DateTime.now();
    return periodTotal(
      TransactionType.expense,
      DateTime(now.year, now.month, now.day),
      DateTime(now.year, now.month, now.day + 1),
    );
  }

  double get weekExpense {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return periodTotal(
      TransactionType.expense,
      start,
      start.add(const Duration(days: 7)),
    );
  }

  int get noSpendDaysThisMonth {
    final now = DateTime.now();
    final days = <int>{};
    for (final t in analyticTransactions(
      from: DateTime(now.year, now.month),
      to: DateTime(now.year, now.month + 1),
    ).where((t) => t.type == TransactionType.expense)) {
      days.add(t.date.day);
    }
    return math.max(0, now.day - days.length).toInt();
  }

  double get dailyAverageExpense {
    final now = DateTime.now();
    return monthTotal(TransactionType.expense) / math.max(1, now.day);
  }

  int transactionCountForAccount(int accountId) => transactions
      .where((t) => t.accountId == accountId || t.toAccountId == accountId)
      .length;
  int recurringCountForAccount(int accountId) =>
      recurring.where((r) => r.accountId == accountId).length;
  int transactionCountForCategory(int categoryId) =>
      transactions.where((t) => t.categoryId == categoryId).length +
      splits.where((s) => s.categoryId == categoryId).length;

  Future<int> addTransaction({
    required TransactionType type,
    required double amount,
    required int accountId,
    int? toAccountId,
    int? categoryId,
    required DateTime date,
    String? note,
    List<String> tags = const [],
    String? receiptPath,
    bool includeInAnalytics = true,
    int? refundOfTransactionId,
  }) async {
    final id = await database.addTransaction(
      type: type,
      amount: amount,
      accountId: accountId,
      toAccountId: toAccountId,
      categoryId: categoryId,
      date: date,
      note: note,
      tags: tags,
      receiptPath: receiptPath,
      includeInAnalytics: includeInAnalytics,
      refundOfTransactionId: refundOfTransactionId,
    );
    await refreshCore();
    await _rebuildLearning();
    return id;
  }

  Future<void> updateTransaction(
    FinanceTransaction oldItem,
    FinanceTransaction newItem,
  ) async {
    if (isAdvanceProtectedTransaction(oldItem)) {
      throw StateError('Gestisci questo movimento dalla sezione Anticipi.');
    }
    await database.updateTransaction(oldItem, newItem);
    await refreshCore(includePlanning: true);
    await _rebuildLearning();
  }

  Future<void> duplicateTransaction(FinanceTransaction item) async {
    if (isAdvanceProtectedTransaction(item)) {
      throw StateError(
        'I movimenti Anticipi non possono essere duplicati direttamente.',
      );
    }
    await database.duplicateTransaction(item);
    await refreshCore();
    await _rebuildLearning();
  }

  Future<void> deleteTransaction(FinanceTransaction item) async {
    if (isAdvanceProtectedTransaction(item)) {
      throw StateError('Gestisci questo movimento dalla sezione Anticipi.');
    }
    await database.deleteTransaction(item);
    await refreshCore(includePlanning: true);
    await _rebuildLearning();
  }

  Future<void> replaceSplits(
    int transactionId,
    List<TransactionSplit> items,
    double amount,
  ) async {
    await database.replaceSplits(transactionId, items, amount);
    splits = await database.splits();
    notifyListeners();
  }

  Future<Account> addAccount({
    required String name,
    double balance = 0,
    int colorValue = 0xFF8E8E93,
    String iconKey = 'wallet',
    AccountType type = AccountType.other,
    bool includeInTotal = true,
    bool includeInAnalytics = true,
    bool hideBalance = false,
    String? note,
  }) async {
    final id = await database.addAccount(
      name: name,
      balance: balance,
      colorValue: colorValue,
      iconKey: iconKey,
      type: type,
      includeInTotal: includeInTotal,
      includeInAnalytics: includeInAnalytics,
      hideBalance: hideBalance,
      note: note,
    );
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
    await _rebuildLearning();
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

  Future<void> updateCategory(Category category) async {
    await database.updateCategory(category);
    categories = await database.categories();
    notifyListeners();
    await syncWidget();
  }

  Future<void> deleteCategory(Category category) async {
    await database.deleteCategory(category.id);
    await refreshCore(includePlanning: true);
    await _rebuildLearning();
  }

  Future<int> createFinancePerson(String name) async {
    final id = await AdvanceService(database).createPerson(name);
    people = await AdvanceService(database).people(includeArchived: true);
    notifyListeners();
    return id;
  }

  Future<int> createPureAdvance({
    required AdvanceDirection direction,
    required int personId,
    required double amount,
    required int accountId,
    required DateTime date,
    DateTime? dueDate,
    DateTime? reminderDate,
    String? note,
  }) async {
    final id = await AdvanceService(database).createPureAdvance(
      direction: direction,
      personId: personId,
      amount: amount,
      accountId: accountId,
      date: date,
      dueDate: dueDate,
      reminderDate: reminderDate,
      note: note,
    );
    await refreshCore(includePlanning: true);
    await _reloadAdvances();
    await _rebuildLearning();
    return id;
  }

  Future<int> createMixedAdvanceExpense({
    required int personId,
    required double totalAmount,
    required double personalAmount,
    required double advanceAmount,
    required int accountId,
    required int categoryId,
    required DateTime date,
    String? note,
    List<String> tags = const [],
    String? receiptPath,
    bool includeInAnalytics = true,
  }) async {
    final id = await AdvanceService(database).createMixedExpense(
      personId: personId,
      totalAmount: totalAmount,
      personalAmount: personalAmount,
      advanceAmount: advanceAmount,
      accountId: accountId,
      categoryId: categoryId,
      date: date,
      note: note,
      tags: tags,
      receiptPath: receiptPath,
      includeInAnalytics: includeInAnalytics,
    );
    await refreshCore(includePlanning: true);
    await _reloadAdvances();
    await _rebuildLearning();
    return id;
  }

  Future<void> recordAdvanceSettlement({
    required int advanceId,
    required double amount,
    required int accountId,
    required DateTime date,
    String? note,
  }) async {
    await AdvanceService(database).recordSettlement(
      advanceId: advanceId,
      amount: amount,
      accountId: accountId,
      date: date,
      note: note,
    );
    await refreshCore(includePlanning: true);
    await _reloadAdvances();
    await _rebuildLearning();
  }

  Future<void> linkTransactionToAdvance({
    required int advanceId,
    required int transactionId,
  }) async {
    await AdvanceService(database).linkExistingTransactionAsSettlement(
      advanceId: advanceId,
      transactionId: transactionId,
    );
    await refreshCore(includePlanning: true);
    await _reloadAdvances();
    await _rebuildLearning();
  }

  Future<void> closeAdvanceWithoutRecovery(
    int advanceId, {
    required bool recognizeInAnalytics,
    int? categoryId,
    int? accountId,
  }) async {
    await AdvanceService(database).closeWithoutRecovery(
      advanceId: advanceId,
      recognizeInAnalytics: recognizeInAnalytics,
      categoryId: categoryId,
      accountId: accountId,
      date: DateTime.now(),
    );
    await refreshCore(includePlanning: true);
    await _reloadAdvances();
    await _rebuildLearning();
  }

  Future<void> updateAdvanceDates(
    int advanceId, {
    DateTime? dueDate,
    DateTime? reminderDate,
  }) async {
    await AdvanceService(database).updateDates(
      advanceId: advanceId,
      dueDate: dueDate,
      reminderDate: reminderDate,
    );
    await _reloadAdvances();
    notifyListeners();
  }

  Future<AdvanceMatchSuggestion?> advanceMatchSuggestion({
    required TransactionType type,
    required double amount,
    String? note,
  }) => AdvanceService(
    database,
  ).suggestMatch(type: type, amount: amount, note: note);

  Future<void> _reloadAdvances() async {
    final service = AdvanceService(database);
    people = await service.people(includeArchived: true);
    advances = await service.advances();
    advanceSettlements = await service.settlements();
  }

  Future<void> addRecurring({
    required String name,
    required double amount,
    required TransactionType type,
    required int accountId,
    int? categoryId,
    required String frequency,
    required DateTime nextDate,
    String? note,
    DateTime? endDate,
    bool autoCreate = false,
  }) async {
    await database.addRecurring(
      name: name,
      amount: amount,
      type: type,
      accountId: accountId,
      categoryId: categoryId,
      frequency: frequency,
      nextDate: nextDate,
      note: note,
      endDate: endDate,
      autoCreate: autoCreate,
    );
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

  Future<void> addBudget({
    required String name,
    int? categoryId,
    required double limit,
    BudgetPeriod period = BudgetPeriod.monthly,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await database.addBudget(
      name: name,
      categoryId: categoryId,
      limit: limit,
      period: period,
      startDate:
          startDate ?? DateTime(DateTime.now().year, DateTime.now().month),
      endDate: endDate,
    );
    budgets = await database.budgets();
    notifyListeners();
  }

  Future<void> updateBudget(Budget item) async {
    await database.updateBudget(item);
    budgets = await database.budgets();
    notifyListeners();
  }

  Future<void> deleteBudget(Budget item) async {
    await database.deleteBudget(item.id);
    budgets = await database.budgets();
    notifyListeners();
  }

  (DateTime, DateTime) budgetRange(Budget budget, {DateTime? now}) {
    final target = now ?? DateTime.now();
    switch (budget.period) {
      case BudgetPeriod.daily:
        final start = DateTime(target.year, target.month, target.day);
        return (start, start.add(const Duration(days: 1)));
      case BudgetPeriod.weekly:
        final day = DateTime(target.year, target.month, target.day);
        final offset = weekStart == DateTime.sunday
            ? target.weekday % 7
            : target.weekday - DateTime.monday;
        final start = day.subtract(Duration(days: offset));
        return (start, start.add(const Duration(days: 7)));
      case BudgetPeriod.monthly:
        final startDay = financialMonthStart.clamp(1, 28).toInt();
        final currentStart = target.day >= startDay
            ? DateTime(target.year, target.month, startDay)
            : DateTime(target.year, target.month - 1, startDay);
        return (
          currentStart,
          DateTime(currentStart.year, currentStart.month + 1, startDay),
        );
      case BudgetPeriod.yearly:
        final start = DateTime(target.year, 1, 1);
        return (start, DateTime(target.year + 1, 1, 1));
      case BudgetPeriod.custom:
        final start = budget.startDate;
        final end = budget.endDate == null
            ? DateTime(9999)
            : DateTime(
                budget.endDate!.year,
                budget.endDate!.month,
                budget.endDate!.day + 1,
              );
        return (start, end);
    }
  }

  double budgetSpent(Budget budget, {DateTime? now}) {
    final (from, to) = budgetRange(budget, now: now);
    var total = 0.0;
    for (final transaction in analyticTransactions(
      from: from,
      to: to,
    ).where((item) => item.type == TransactionType.expense)) {
      final itemSplits = splitsFor(transaction.id);
      if (budget.categoryId == null) {
        total += effectiveExpense(transaction);
      } else if (itemSplits.isNotEmpty) {
        total += itemSplits
            .where((split) => split.categoryId == budget.categoryId)
            .fold(
              0.0,
              (sum, split) =>
                  sum + analyticsAmountForSplit(transaction.id, split),
            );
      } else if (transaction.categoryId == budget.categoryId) {
        total += effectiveExpense(transaction);
      }
    }
    return total;
  }

  double budgetProgressFor(Budget budget, {DateTime? now}) =>
      budget.limit <= 0 ? 0 : budgetSpent(budget, now: now) / budget.limit;

  Future<void> addGoal({
    required String name,
    required double targetAmount,
    String iconKey = 'savings',
    int colorValue = 0xFF8E8E93,
    DateTime? targetDate,
    int? linkedAccountId,
  }) async {
    await database.addGoal(
      name: name,
      iconKey: iconKey,
      colorValue: colorValue,
      targetAmount: targetAmount,
      targetDate: targetDate,
      linkedAccountId: linkedAccountId,
    );
    goals = await database.goals();
    notifyListeners();
  }

  Future<void> updateGoal(Goal item) async {
    await database.updateGoal(item);
    goals = await database.goals();
    notifyListeners();
  }

  Future<void> deleteGoal(Goal item) async {
    await database.deleteGoal(item.id);
    goals = await database.goals();
    notifyListeners();
  }

  Future<void> contributeGoal(Goal item, double delta) async {
    await GoalLedgerService(database).recordManual(item.id, delta);
    goals = await database.goals();
    notifyListeners();
  }

  GoalPlan goalPlan(Goal goal, {DateTime? now}) {
    final activeGoals = goals
        .where((item) => !item.archived && !item.completed)
        .length;
    return SmartFinanceEngine.planGoal(
      goal: goal,
      currentAmount: goal.currentAmount,
      totalBalance: totalBalance,
      transactions: analyticTransactions().toList(),
      recurring: recurring,
      competingGoals: activeGoals,
      now: now,
    );
  }

  Account? suggestedGoalTransferSource(Goal goal) {
    if (goal.linkedAccountId == null) return null;
    final candidates =
        activeAccounts
            .where((item) => !item.isLocked && item.id != goal.linkedAccountId)
            .toList()
          ..sort((a, b) => b.balance.compareTo(a.balance));
    return candidates.firstOrNull;
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
      items.add(
        DashboardWidgetConfig(
          type: type,
          enabled: index >= 0,
          orderIndex: index >= 0 ? index : defaults.length + i,
          size: DashboardWidgetSize.medium,
        ),
      );
    }
    await saveDashboard(items);
  }

  Future<void> addRule(AutomationRule rule) async {
    await database.addRule(rule);
    rules = await database.rules();
    notifyListeners();
  }

  Future<void> deleteRule(AutomationRule rule) async {
    await database.deleteRule(rule.id);
    rules = await database.rules();
    notifyListeners();
  }

  SmartSuggestion? smartSuggestion({
    required String? note,
    required TransactionType type,
    double? amount,
    DateTime? date,
  }) {
    if (!smartSuggestionsEnabled) return null;
    return SmartFinanceEngine.suggest(
      note: note,
      type: type,
      amount: amount,
      date: date ?? DateTime.now(),
      patterns: learnedPatterns,
      rules: rules,
      suppressedTexts: suppressedSuggestionTexts,
      sensitivity: smartSensitivity,
      useDescription: smartUseDescription,
      useAmount: smartUseAmount,
      useTime: smartUseTime,
    );
  }

  Future<void> acceptSuggestion(
    SmartSuggestion suggestion,
    String query,
  ) async {
    await database.recordPatternFeedback(
      suggestion.patternId,
      'accepted',
      SmartFinanceEngine.normalizeText(query),
    );
    learnedPatterns = await database.learnedPatterns();
    notifyListeners();
  }

  Future<void> rejectSuggestion(
    SmartSuggestion suggestion,
    String query, {
    bool modified = false,
  }) async {
    await database.recordPatternFeedback(
      suggestion.patternId,
      modified ? 'modified' : 'rejected',
      SmartFinanceEngine.normalizeText(query),
    );
    learnedPatterns = await database.learnedPatterns();
    notifyListeners();
  }

  Future<void> suppressSuggestion(
    SmartSuggestion suggestion,
    String query,
  ) async {
    final normalized = SmartFinanceEngine.normalizeText(query);
    if (normalized.isEmpty) return;
    await database.recordPatternFeedback(
      suggestion.patternId,
      'rejected',
      normalized,
    );
    await database.suppressSuggestion(normalized);
    suppressedSuggestionTexts = await database.suppressedSuggestionTexts();
    learnedPatterns = await database.learnedPatterns();
    notifyListeners();
  }

  Future<void> setPatternEnabled(LearnedPattern pattern, bool enabled) async {
    await database.setPatternEnabled(pattern.id, enabled);
    learnedPatterns = await database.learnedPatterns();
    notifyListeners();
  }

  Future<void> deleteLearnedPattern(LearnedPattern pattern) async {
    await database.deletePattern(pattern.id);
    learnedPatterns = await database.learnedPatterns();
    notifyListeners();
  }

  Future<void> convertPatternToRule(LearnedPattern pattern) async {
    final category = categoryById(pattern.categoryId);
    await addRule(
      AutomationRule(
        id: 0,
        name: 'Da apprendimento · ${pattern.normalizedText}',
        enabled: true,
        containsText: pattern.normalizedText,
        type: pattern.type,
        categoryId: pattern.type == TransactionType.transfer
            ? null
            : category?.id,
        accountId: pattern.accountId,
        addTag: pattern.tags.firstOrNull,
      ),
    );
  }

  Future<void> clearLearning() async {
    await database.clearLearning();
    learnedPatterns = [];
    detectedRecurringPatterns = [];
    suppressedSuggestionTexts = {};
    notifyListeners();
  }

  Future<void> _rebuildLearning({bool notify = true}) async {
    if (!smartSuggestionsEnabled) return;
    final previous = <String, LearnedPattern>{
      for (final pattern in await database.learnedPatterns())
        pattern.signature: pattern,
    };
    final learningTransactions = analyticTransactions()
        .where((item) => !item.kind.startsWith('advance_'))
        .toList();
    final patterns = SmartFinanceEngine.buildPatterns(
      learningTransactions,
      previous: previous,
    );
    await database.replaceLearnedPatterns(patterns);
    learnedPatterns = await database.learnedPatterns();
    if (smartDetectRecurring) {
      final detected = SmartFinanceEngine.detectRecurring(learningTransactions);
      await database.replaceDetectedRecurringPatterns(detected);
      detectedRecurringPatterns = await database.detectedRecurringPatterns();
    }
    suppressedSuggestionTexts = await database.suppressedSuggestionTexts();
    if (notify) notifyListeners();
  }

  Future<void> setSetting(String key, String value) async {
    await database.setSetting(key, value);
    await _loadSettingsOnly();
    if (key.startsWith('smart_') && smartSuggestionsEnabled) {
      await _rebuildLearning(notify: false);
    }
    notifyListeners();
  }

  Future<void> _loadSettingsOnly() async {
    hideBalance = (await database.getSetting('hide_balance') ?? '0') == '1';
    allowUnassigned =
        (await database.getSetting('allow_unassigned') ?? '1') == '1';
    showTransfersInAnalytics =
        (await database.getSetting('show_transfers_analytics') ?? '0') == '1';
    confirmDelete = (await database.getSetting('confirm_delete') ?? '1') == '1';
    showCents = (await database.getSetting('show_cents') ?? '1') == '1';
    haptics = (await database.getSetting('haptics') ?? '1') == '1';
    currency = await database.getSetting('currency') ?? 'EUR';
    weekStart =
        int.tryParse(await database.getSetting('week_start') ?? '1') ?? 1;
    financialMonthStart =
        int.tryParse(
          await database.getSetting('financial_month_start') ?? '1',
        ) ??
        1;
    final theme = await database.getSetting('theme_mode') ?? 'system';
    themePreference = AppThemePreference.values.firstWhere(
      (e) => e.name == theme,
      orElse: () => AppThemePreference.system,
    );
    smartSuggestionsEnabled =
        (await database.getSetting('smart_suggestions_enabled') ?? '1') == '1';
    smartUseDescription =
        (await database.getSetting('smart_use_description') ?? '1') == '1';
    smartUseAmount =
        (await database.getSetting('smart_use_amount') ?? '1') == '1';
    smartUseTime = (await database.getSetting('smart_use_time') ?? '1') == '1';
    smartDetectRecurring =
        (await database.getSetting('smart_detect_recurring') ?? '1') == '1';
    smartGoalSuggestions =
        (await database.getSetting('smart_goal_suggestions') ?? '1') == '1';
    final sensitivity =
        await database.getSetting('smart_sensitivity') ?? 'balanced';
    smartSensitivity = SmartSensitivity.values.firstWhere(
      (item) => item.name == sensitivity,
      orElse: () => SmartSensitivity.balanced,
    );
  }

  Future<void> setHideBalance(bool value) =>
      setSetting('hide_balance', value ? '1' : '0');
  Future<void> setThemePreference(AppThemePreference value) =>
      setSetting('theme_mode', value.name);

  Future<void> refreshCore({bool includePlanning = false}) async {
    accounts = await database.accounts();
    transactions = await database.transactions();
    splits = await database.splits();
    await _reloadAdvances();
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
    final lines = content
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.length <= 1) return 0;
    var imported = 0;
    final fallback =
        unassignedAccount?.id ?? await database.unassignedAccountId();
    for (final line in lines.skip(1)) {
      final fields = _parseCsvLine(line);
      if (fields.length < 10) continue;
      final type = TransactionTypeX.fromDb(fields[1]);
      final amount = double.tryParse(fields[2]);
      final originalAccountId = int.tryParse(fields[3]);
      final account = accountById(originalAccountId);
      final accountId =
          account == null || account.isArchived || account.isLocked
          ? fallback
          : account.id;
      final toIdRaw = int.tryParse(fields[4]);
      final toAccount = accountById(toIdRaw);
      final categoryRaw = int.tryParse(fields[5]);
      final date = DateTime.tryParse(fields[6]);
      if (amount == null || amount <= 0 || date == null) continue;
      if (type == TransactionType.transfer &&
          (toAccount == null ||
              toAccount.isArchived ||
              toAccount.isLocked ||
              toAccount.id == accountId)) {
        continue;
      }
      await database.addTransaction(
        type: type,
        amount: amount,
        accountId: accountId,
        toAccountId: type == TransactionType.transfer ? toAccount!.id : null,
        categoryId:
            type == TransactionType.transfer ||
                categoryById(categoryRaw) == null
            ? null
            : categoryRaw,
        date: date,
        note: fields[7].isEmpty ? null : fields[7],
        tags: fields[8].split('|').where((e) => e.isNotEmpty).toList(),
        includeInAnalytics: fields[9] != '0',
      );
      imported++;
    }
    await refreshCore(includePlanning: true);
    await _rebuildLearning();
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
  Future<void> restoreDatabaseFrom(String path) async {
    await database.restoreDatabaseFrom(path);
    await GoalLedgerService(database).ensureSchema();
    loading = true;
    notifyListeners();
    await load();
  }

  Future<void> syncWidget() => widgetService.sync(
    balance: totalBalance,
    expenseCategories: categoriesFor(TransactionType.expense),
  );
}

extension FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

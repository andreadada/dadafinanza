import '../core/money.dart';

const _unset = Object();

enum TransactionType { expense, income, transfer }

extension TransactionTypeX on TransactionType {
  String get dbValue => name;
  String get label => switch (this) {
    TransactionType.expense => 'Spesa',
    TransactionType.income => 'Entrata',
    TransactionType.transfer => 'Trasferimento',
  };
  static TransactionType fromDb(String value) =>
      TransactionType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => TransactionType.expense,
      );
}

enum AccountType { cash, checking, savings, card, prepaid, investment, other }

extension AccountTypeX on AccountType {
  String get label => switch (this) {
    AccountType.cash => 'Contanti',
    AccountType.checking => 'Conto corrente',
    AccountType.savings => 'Risparmio',
    AccountType.card => 'Carta',
    AccountType.prepaid => 'Prepagata',
    AccountType.investment => 'Investimenti',
    AccountType.other => 'Altro',
  };
  static AccountType fromDb(String? value) => AccountType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => AccountType.other,
  );
}

enum BudgetPeriod { daily, weekly, monthly, yearly, custom }

enum AppThemePreference { system, light, dark }

enum DashboardWidgetSize { small, medium, large }

enum DashboardWidgetType {
  totalBalance,
  monthlyCashFlow,
  monthlyIncome,
  monthlyExpense,
  monthlyBudget,
  safeToSpend,
  netWorth,
  accounts,
  recentTransactions,
  todayExpense,
  weekExpense,
  previousMonthComparison,
  topCategories,
  closestBudget,
  upcomingRecurring,
  financeCalendar,
  goals,
  netWorthTrend,
  dailyAverage,
  noSpendDays,
  endMonthForecast,
  unassignedTransactions,
}

extension DashboardWidgetTypeX on DashboardWidgetType {
  String get label => switch (this) {
    DashboardWidgetType.totalBalance => 'Saldo totale',
    DashboardWidgetType.monthlyCashFlow => 'Cash flow del mese',
    DashboardWidgetType.monthlyIncome => 'Entrate del mese',
    DashboardWidgetType.monthlyExpense => 'Spese del mese',
    DashboardWidgetType.monthlyBudget => 'Budget mensile',
    DashboardWidgetType.safeToSpend => 'Disponibile da spendere',
    DashboardWidgetType.netWorth => 'Patrimonio netto',
    DashboardWidgetType.accounts => 'Conti',
    DashboardWidgetType.recentTransactions => 'Ultimi movimenti',
    DashboardWidgetType.todayExpense => 'Spese di oggi',
    DashboardWidgetType.weekExpense => 'Spese della settimana',
    DashboardWidgetType.previousMonthComparison => 'Confronto mese precedente',
    DashboardWidgetType.topCategories => 'Categorie principali',
    DashboardWidgetType.closestBudget => 'Budget più vicino al limite',
    DashboardWidgetType.upcomingRecurring => 'Prossimi pagamenti',
    DashboardWidgetType.financeCalendar => 'Calendario finanziario',
    DashboardWidgetType.goals => 'Obiettivi',
    DashboardWidgetType.netWorthTrend => 'Andamento patrimonio',
    DashboardWidgetType.dailyAverage => 'Media spesa giornaliera',
    DashboardWidgetType.noSpendDays => 'Giorni senza spese',
    DashboardWidgetType.endMonthForecast => 'Previsione fine mese',
    DashboardWidgetType.unassignedTransactions => 'Movimenti da assegnare',
  };
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.balance,
    required this.colorValue,
    required this.iconKey,
    required this.accountType,
    required this.includeInTotal,
    required this.includeInAnalytics,
    required this.isLocked,
    required this.isArchived,
    required this.hideBalance,
    required this.isSystem,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.openingBalance = 0,
    this.lastReconciledAt,
  });

  final int id;
  final String name;
  final double balance;
  final double openingBalance;
  final int colorValue;
  final String iconKey;
  final AccountType accountType;
  final bool includeInTotal;
  final bool includeInAnalytics;
  final bool isLocked;
  final bool isArchived;
  final bool hideBalance;
  final bool isSystem;
  final String? note;
  final DateTime? lastReconciledAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Account copyWith({
    String? name,
    double? balance,
    double? openingBalance,
    int? colorValue,
    String? iconKey,
    AccountType? accountType,
    bool? includeInTotal,
    bool? includeInAnalytics,
    bool? isLocked,
    bool? isArchived,
    bool? hideBalance,
    bool? isSystem,
    Object? note = _unset,
    Object? lastReconciledAt = _unset,
    DateTime? updatedAt,
  }) => Account(
    id: id,
    name: name ?? this.name,
    balance: balance ?? this.balance,
    openingBalance: openingBalance ?? this.openingBalance,
    colorValue: colorValue ?? this.colorValue,
    iconKey: iconKey ?? this.iconKey,
    accountType: accountType ?? this.accountType,
    includeInTotal: includeInTotal ?? this.includeInTotal,
    includeInAnalytics: includeInAnalytics ?? this.includeInAnalytics,
    isLocked: isLocked ?? this.isLocked,
    isArchived: isArchived ?? this.isArchived,
    hideBalance: hideBalance ?? this.hideBalance,
    isSystem: isSystem ?? this.isSystem,
    note: identical(note, _unset) ? this.note : note as String?,
    lastReconciledAt: identical(lastReconciledAt, _unset)
        ? this.lastReconciledAt
        : lastReconciledAt as DateTime?,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory Account.fromMap(Map<String, Object?> map) => Account(
    id: map['id'] as int,
    name: map['name'] as String,
    balance: Money.valueFromMap(map, 'balance_cents', 'balance'),
    openingBalance: Money.valueFromMap(
      map,
      'opening_balance_cents',
      'opening_balance',
    ),
    colorValue: map['color'] as int,
    iconKey: (map['icon_key'] as String?) ?? 'wallet',
    accountType: AccountTypeX.fromDb(map['account_type'] as String?),
    includeInTotal: (map['include_in_total'] as int? ?? 1) == 1,
    includeInAnalytics: (map['include_in_analytics'] as int? ?? 1) == 1,
    isLocked: (map['is_locked'] as int? ?? 0) == 1,
    isArchived: (map['is_archived'] as int? ?? 0) == 1,
    hideBalance: (map['hide_balance'] as int? ?? 0) == 1,
    isSystem: (map['is_system'] as int? ?? 0) == 1,
    note: map['note'] as String?,
    lastReconciledAt: map['last_reconciled_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(map['last_reconciled_at'] as int),
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      map['created_at'] as int? ?? 0,
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      map['updated_at'] as int? ?? 0,
    ),
  );
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    required this.type,
    required this.quickOrder,
    this.isFavorite = false,
  });

  final int id;
  final String name;
  final String iconKey;
  final int colorValue;
  final TransactionType type;
  final int? quickOrder;
  final bool isFavorite;

  Category copyWith({
    String? name,
    String? iconKey,
    int? colorValue,
    TransactionType? type,
    Object? quickOrder = _unset,
    bool? isFavorite,
  }) => Category(
    id: id,
    name: name ?? this.name,
    iconKey: iconKey ?? this.iconKey,
    colorValue: colorValue ?? this.colorValue,
    type: type ?? this.type,
    quickOrder: identical(quickOrder, _unset)
        ? this.quickOrder
        : quickOrder as int?,
    isFavorite: isFavorite ?? this.isFavorite,
  );

  factory Category.fromMap(Map<String, Object?> map) => Category(
    id: map['id'] as int,
    name: map['name'] as String,
    iconKey: map['icon_key'] as String,
    colorValue: map['color'] as int,
    type: TransactionTypeX.fromDb(map['type'] as String),
    quickOrder: map['quick_order'] as int?,
    isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
  );
}

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    required this.date,
    required this.includeInAnalytics,
    required this.createdAt,
    required this.updatedAt,
    this.toAccountId,
    this.categoryId,
    this.note,
    this.tags = const [],
    this.receiptPath,
    this.recurringId,
    this.refundOfTransactionId,
    this.kind = 'normal',
  });

  final int id;
  final TransactionType type;
  final double amount;
  final int accountId;
  final int? toAccountId;
  final int? categoryId;
  final DateTime date;
  final String? note;
  final List<String> tags;
  final String? receiptPath;
  final bool includeInAnalytics;
  final int? recurringId;
  final int? refundOfTransactionId;
  final String kind;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isReconciliation => kind == 'reconciliation';

  FinanceTransaction copyWith({
    TransactionType? type,
    double? amount,
    int? accountId,
    Object? toAccountId = _unset,
    Object? categoryId = _unset,
    DateTime? date,
    Object? note = _unset,
    List<String>? tags,
    Object? receiptPath = _unset,
    bool? includeInAnalytics,
    Object? recurringId = _unset,
    Object? refundOfTransactionId = _unset,
    String? kind,
    DateTime? updatedAt,
  }) => FinanceTransaction(
    id: id,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    accountId: accountId ?? this.accountId,
    toAccountId: identical(toAccountId, _unset)
        ? this.toAccountId
        : toAccountId as int?,
    categoryId: identical(categoryId, _unset)
        ? this.categoryId
        : categoryId as int?,
    date: date ?? this.date,
    note: identical(note, _unset) ? this.note : note as String?,
    tags: tags ?? this.tags,
    receiptPath: identical(receiptPath, _unset)
        ? this.receiptPath
        : receiptPath as String?,
    includeInAnalytics: includeInAnalytics ?? this.includeInAnalytics,
    recurringId: identical(recurringId, _unset)
        ? this.recurringId
        : recurringId as int?,
    refundOfTransactionId: identical(refundOfTransactionId, _unset)
        ? this.refundOfTransactionId
        : refundOfTransactionId as int?,
    kind: kind ?? this.kind,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory FinanceTransaction.fromMap(Map<String, Object?> map) =>
      FinanceTransaction(
        id: map['id'] as int,
        type: TransactionTypeX.fromDb(map['type'] as String),
        amount: Money.valueFromMap(map, 'amount_cents', 'amount'),
        accountId: map['account_id'] as int,
        toAccountId: map['to_account_id'] as int?,
        categoryId: map['category_id'] as int?,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        note: map['note'] as String?,
        tags: ((map['tags'] as String?) ?? '')
            .split('|')
            .where((e) => e.isNotEmpty)
            .toList(),
        receiptPath: map['receipt_path'] as String?,
        includeInAnalytics: (map['include_in_analytics'] as int? ?? 1) == 1,
        recurringId: map['recurring_id'] as int?,
        refundOfTransactionId: map['refund_of_transaction_id'] as int?,
        kind: (map['kind'] as String?) ?? 'normal',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          map['created_at'] as int? ?? map['date'] as int,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          map['updated_at'] as int? ?? map['date'] as int,
        ),
      );
}

class TransactionSplit {
  const TransactionSplit({
    required this.id,
    required this.transactionId,
    required this.amount,
    required this.categoryId,
    this.note,
  });

  final int id;
  final int transactionId;
  final double amount;
  final int categoryId;
  final String? note;

  factory TransactionSplit.fromMap(Map<String, Object?> map) =>
      TransactionSplit(
        id: map['id'] as int,
        transactionId: map['transaction_id'] as int,
        amount: Money.valueFromMap(map, 'amount_cents', 'amount'),
        categoryId: map['category_id'] as int,
        note: map['note'] as String?,
      );
}

class RecurringPayment {
  const RecurringPayment({
    required this.id,
    required this.name,
    required this.amount,
    required this.type,
    required this.accountId,
    required this.frequency,
    required this.nextDate,
    required this.enabled,
    required this.autoCreate,
    this.toAccountId,
    this.categoryId,
    this.note,
    this.endDate,
  });

  final int id;
  final String name;
  final double amount;
  final TransactionType type;
  final int accountId;
  final int? toAccountId;
  final int? categoryId;
  final String frequency;
  final DateTime nextDate;
  final bool enabled;
  final bool autoCreate;
  final String? note;
  final DateTime? endDate;

  RecurringPayment copyWith({
    String? name,
    double? amount,
    TransactionType? type,
    int? accountId,
    Object? toAccountId = _unset,
    Object? categoryId = _unset,
    String? frequency,
    DateTime? nextDate,
    bool? enabled,
    bool? autoCreate,
    Object? note = _unset,
    Object? endDate = _unset,
  }) => RecurringPayment(
    id: id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    type: type ?? this.type,
    accountId: accountId ?? this.accountId,
    toAccountId: identical(toAccountId, _unset)
        ? this.toAccountId
        : toAccountId as int?,
    categoryId: identical(categoryId, _unset)
        ? this.categoryId
        : categoryId as int?,
    frequency: frequency ?? this.frequency,
    nextDate: nextDate ?? this.nextDate,
    enabled: enabled ?? this.enabled,
    autoCreate: autoCreate ?? this.autoCreate,
    note: identical(note, _unset) ? this.note : note as String?,
    endDate: identical(endDate, _unset) ? this.endDate : endDate as DateTime?,
  );

  factory RecurringPayment.fromMap(Map<String, Object?> map) =>
      RecurringPayment(
        id: map['id'] as int,
        name: map['name'] as String,
        amount: Money.valueFromMap(map, 'amount_cents', 'amount'),
        type: TransactionTypeX.fromDb(map['type'] as String),
        accountId: map['account_id'] as int,
        toAccountId: map['to_account_id'] as int?,
        categoryId: map['category_id'] as int?,
        frequency: map['frequency'] as String,
        nextDate: DateTime.fromMillisecondsSinceEpoch(map['next_date'] as int),
        enabled: (map['enabled'] as int? ?? 1) == 1,
        autoCreate: (map['auto_create'] as int? ?? 0) == 1,
        note: map['note'] as String?,
        endDate: map['end_date'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['end_date'] as int),
      );
}

class Budget {
  const Budget({
    required this.id,
    required this.name,
    required this.limit,
    required this.period,
    required this.startDate,
    required this.enabled,
    this.categoryId,
    this.endDate,
  });

  final int id;
  final String name;
  final double limit;
  final BudgetPeriod period;
  final DateTime startDate;
  final bool enabled;
  final int? categoryId;
  final DateTime? endDate;

  Budget copyWith({
    String? name,
    double? limit,
    BudgetPeriod? period,
    DateTime? startDate,
    bool? enabled,
    Object? categoryId = _unset,
    Object? endDate = _unset,
  }) => Budget(
    id: id,
    name: name ?? this.name,
    limit: limit ?? this.limit,
    period: period ?? this.period,
    startDate: startDate ?? this.startDate,
    enabled: enabled ?? this.enabled,
    categoryId: identical(categoryId, _unset)
        ? this.categoryId
        : categoryId as int?,
    endDate: identical(endDate, _unset) ? this.endDate : endDate as DateTime?,
  );

  factory Budget.fromMap(Map<String, Object?> map) => Budget(
    id: map['id'] as int,
    name: map['name'] as String,
    limit: Money.valueFromMap(map, 'limit_cents', 'limit_amount'),
    period: BudgetPeriod.values.firstWhere(
      (e) => e.name == map['period'],
      orElse: () => BudgetPeriod.monthly,
    ),
    startDate: DateTime.fromMillisecondsSinceEpoch(map['start_date'] as int),
    enabled: (map['enabled'] as int? ?? 1) == 1,
    categoryId: map['category_id'] as int?,
    endDate: map['end_date'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(map['end_date'] as int),
  );
}

class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    required this.targetAmount,
    required this.currentAmount,
    required this.archived,
    required this.completed,
    this.targetDate,
    this.linkedAccountId,
  });

  final int id;
  final String name;
  final String iconKey;
  final int colorValue;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final int? linkedAccountId;
  final bool archived;
  final bool completed;

  Goal copyWith({
    String? name,
    String? iconKey,
    int? colorValue,
    double? targetAmount,
    double? currentAmount,
    Object? targetDate = _unset,
    Object? linkedAccountId = _unset,
    bool? archived,
    bool? completed,
  }) => Goal(
    id: id,
    name: name ?? this.name,
    iconKey: iconKey ?? this.iconKey,
    colorValue: colorValue ?? this.colorValue,
    targetAmount: targetAmount ?? this.targetAmount,
    currentAmount: currentAmount ?? this.currentAmount,
    targetDate: identical(targetDate, _unset)
        ? this.targetDate
        : targetDate as DateTime?,
    linkedAccountId: identical(linkedAccountId, _unset)
        ? this.linkedAccountId
        : linkedAccountId as int?,
    archived: archived ?? this.archived,
    completed: completed ?? this.completed,
  );

  factory Goal.fromMap(Map<String, Object?> map) => Goal(
    id: map['id'] as int,
    name: map['name'] as String,
    iconKey: map['icon_key'] as String,
    colorValue: map['color'] as int,
    targetAmount: Money.valueFromMap(
      map,
      'target_amount_cents',
      'target_amount',
    ),
    currentAmount: Money.valueFromMap(
      map,
      'current_amount_cents',
      'current_amount',
    ),
    targetDate: map['target_date'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(map['target_date'] as int),
    linkedAccountId: map['linked_account_id'] as int?,
    archived: (map['archived'] as int? ?? 0) == 1,
    completed: (map['completed'] as int? ?? 0) == 1,
  );
}

class DashboardWidgetConfig {
  const DashboardWidgetConfig({
    required this.type,
    required this.enabled,
    required this.orderIndex,
    required this.size,
  });

  final DashboardWidgetType type;
  final bool enabled;
  final int orderIndex;
  final DashboardWidgetSize size;

  factory DashboardWidgetConfig.fromMap(Map<String, Object?> map) =>
      DashboardWidgetConfig(
        type: DashboardWidgetType.values.firstWhere(
          (e) => e.name == map['type'],
        ),
        enabled: (map['enabled'] as int) == 1,
        orderIndex: map['order_index'] as int,
        size: DashboardWidgetSize.values.firstWhere(
          (e) => e.name == map['size'],
          orElse: () => DashboardWidgetSize.medium,
        ),
      );
}

class AutomationRule {
  const AutomationRule({
    required this.id,
    required this.name,
    required this.enabled,
    this.containsText,
    this.type,
    this.minAmount,
    this.maxAmount,
    this.categoryId,
    this.accountId,
    this.addTag,
    this.includeInAnalytics,
    this.priority = 0,
  });

  final int id;
  final String name;
  final bool enabled;
  final String? containsText;
  final TransactionType? type;
  final double? minAmount;
  final double? maxAmount;
  final int? categoryId;
  final int? accountId;
  final String? addTag;
  final bool? includeInAnalytics;
  final int priority;

  AutomationRule copyWith({
    String? name,
    bool? enabled,
    Object? containsText = _unset,
    Object? type = _unset,
    Object? minAmount = _unset,
    Object? maxAmount = _unset,
    Object? categoryId = _unset,
    Object? accountId = _unset,
    Object? addTag = _unset,
    Object? includeInAnalytics = _unset,
    int? priority,
  }) => AutomationRule(
    id: id,
    name: name ?? this.name,
    enabled: enabled ?? this.enabled,
    containsText: identical(containsText, _unset)
        ? this.containsText
        : containsText as String?,
    type: identical(type, _unset) ? this.type : type as TransactionType?,
    minAmount: identical(minAmount, _unset)
        ? this.minAmount
        : minAmount as double?,
    maxAmount: identical(maxAmount, _unset)
        ? this.maxAmount
        : maxAmount as double?,
    categoryId: identical(categoryId, _unset)
        ? this.categoryId
        : categoryId as int?,
    accountId: identical(accountId, _unset)
        ? this.accountId
        : accountId as int?,
    addTag: identical(addTag, _unset) ? this.addTag : addTag as String?,
    includeInAnalytics: identical(includeInAnalytics, _unset)
        ? this.includeInAnalytics
        : includeInAnalytics as bool?,
    priority: priority ?? this.priority,
  );

  factory AutomationRule.fromMap(Map<String, Object?> map) => AutomationRule(
    id: map['id'] as int,
    name: map['name'] as String,
    enabled: (map['enabled'] as int? ?? 1) == 1,
    containsText: map['contains_text'] as String?,
    type: map['type'] == null
        ? null
        : TransactionTypeX.fromDb(map['type'] as String),
    minAmount: map['min_amount_cents'] == null
        ? (map['min_amount'] as num?)?.toDouble()
        : Money.fromCents((map['min_amount_cents'] as num).toInt()),
    maxAmount: map['max_amount_cents'] == null
        ? (map['max_amount'] as num?)?.toDouble()
        : Money.fromCents((map['max_amount_cents'] as num).toInt()),
    categoryId: map['category_id'] as int?,
    accountId: map['account_id'] as int?,
    addTag: map['add_tag'] as String?,
    includeInAnalytics: map['include_in_analytics'] == null
        ? null
        : (map['include_in_analytics'] as int) == 1,
    priority: map['priority'] as int? ?? 0,
  );
}

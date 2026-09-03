enum TransactionType { expense, income, transfer }

extension TransactionTypeX on TransactionType {
  String get dbValue => name;

  String get label => switch (this) {
        TransactionType.expense => 'Spesa',
        TransactionType.income => 'Entrata',
        TransactionType.transfer => 'Giroconto',
      };

  static TransactionType fromDb(String value) =>
      TransactionType.values.firstWhere((e) => e.name == value);
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.balance,
    required this.colorValue,
    required this.includeInTotal,
  });

  final int id;
  final String name;
  final double balance;
  final int colorValue;
  final bool includeInTotal;

  Account copyWith({
    String? name,
    double? balance,
    int? colorValue,
    bool? includeInTotal,
  }) =>
      Account(
        id: id,
        name: name ?? this.name,
        balance: balance ?? this.balance,
        colorValue: colorValue ?? this.colorValue,
        includeInTotal: includeInTotal ?? this.includeInTotal,
      );

  factory Account.fromMap(Map<String, Object?> map) => Account(
        id: map['id'] as int,
        name: map['name'] as String,
        balance: (map['balance'] as num).toDouble(),
        colorValue: map['color'] as int,
        includeInTotal: (map['include_in_total'] as int) == 1,
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
  });

  final int id;
  final String name;
  final String iconKey;
  final int colorValue;
  final TransactionType type;
  final int? quickOrder;

  factory Category.fromMap(Map<String, Object?> map) => Category(
        id: map['id'] as int,
        name: map['name'] as String,
        iconKey: map['icon_key'] as String,
        colorValue: map['color'] as int,
        type: TransactionTypeX.fromDb(map['type'] as String),
        quickOrder: map['quick_order'] as int?,
      );
}

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    required this.date,
    this.toAccountId,
    this.categoryId,
    this.note,
    this.tags = const [],
    this.receiptPath,
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

  factory FinanceTransaction.fromMap(Map<String, Object?> map) =>
      FinanceTransaction(
        id: map['id'] as int,
        type: TransactionTypeX.fromDb(map['type'] as String),
        amount: (map['amount'] as num).toDouble(),
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
    this.categoryId,
  });

  final int id;
  final String name;
  final double amount;
  final TransactionType type;
  final int accountId;
  final int? categoryId;
  final String frequency;
  final DateTime nextDate;
  final bool enabled;

  factory RecurringPayment.fromMap(Map<String, Object?> map) =>
      RecurringPayment(
        id: map['id'] as int,
        name: map['name'] as String,
        amount: (map['amount'] as num).toDouble(),
        type: TransactionTypeX.fromDb(map['type'] as String),
        accountId: map['account_id'] as int,
        categoryId: map['category_id'] as int?,
        frequency: map['frequency'] as String,
        nextDate: DateTime.fromMillisecondsSinceEpoch(map['next_date'] as int),
        enabled: (map['enabled'] as int) == 1,
      );
}

import '../core/money.dart';

enum AdvanceDirection { receivable, payable }

extension AdvanceDirectionX on AdvanceDirection {
  String get dbValue => name;

  String get label => switch (this) {
    AdvanceDirection.receivable => 'Da ricevere',
    AdvanceDirection.payable => 'Da restituire',
  };

  String get actionLabel => switch (this) {
    AdvanceDirection.receivable => 'Ho anticipato',
    AdvanceDirection.payable => 'Mi hanno anticipato',
  };

  String get actionSubtitle => switch (this) {
    AdvanceDirection.receivable => 'Devo ricevere dei soldi',
    AdvanceDirection.payable => 'Devo restituire dei soldi',
  };

  static AdvanceDirection fromDb(String value) =>
      AdvanceDirection.values.firstWhere(
        (item) => item.name == value,
        orElse: () => AdvanceDirection.receivable,
      );
}

enum AdvanceClosedKind { cancelled, writtenOff, forgiven }

extension AdvanceClosedKindX on AdvanceClosedKind {
  String get dbValue => name;

  static AdvanceClosedKind? fromDb(String? value) {
    if (value == null || value.isEmpty) return null;
    return AdvanceClosedKind.values
        .where((item) => item.name == value)
        .firstOrNull;
  }
}

enum AdvanceStatus {
  open,
  partial,
  overdue,
  settled,
  cancelled,
  writtenOff,
  forgiven,
}

class FinancePerson {
  const FinancePerson({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconKey,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
    this.note,
  });

  final int id;
  final String name;
  final int colorValue;
  final String iconKey;
  final bool archived;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FinancePerson.fromMap(Map<String, Object?> map) => FinancePerson(
    id: map['id'] as int,
    name: map['name'] as String,
    colorValue: (map['color'] as num?)?.toInt() ?? 0xFF8E8E93,
    iconKey: (map['icon_key'] as String?) ?? 'person',
    archived: (map['archived'] as int? ?? 0) == 1,
    note: map['note'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      map['created_at'] as int? ?? 0,
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      map['updated_at'] as int? ?? 0,
    ),
  );
}

class Advance {
  const Advance({
    required this.id,
    required this.direction,
    required this.personId,
    required this.originalAmountCents,
    required this.createdAt,
    required this.updatedAt,
    this.sourceAccountId,
    this.sourceTransactionId,
    this.dueDate,
    this.reminderDate,
    this.note,
    this.closedKind,
    this.closedAt,
  });

  final int id;
  final AdvanceDirection direction;
  final int personId;
  final int originalAmountCents;
  final int? sourceAccountId;
  final int? sourceTransactionId;
  final DateTime? dueDate;
  final DateTime? reminderDate;
  final String? note;
  final AdvanceClosedKind? closedKind;
  final DateTime? closedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get originalAmount => Money.fromCents(originalAmountCents);

  factory Advance.fromMap(Map<String, Object?> map) => Advance(
    id: map['id'] as int,
    direction: AdvanceDirectionX.fromDb(map['direction'] as String),
    personId: map['person_id'] as int,
    originalAmountCents: (map['original_amount_cents'] as num).toInt(),
    sourceAccountId: map['source_account_id'] as int?,
    sourceTransactionId: map['source_transaction_id'] as int?,
    dueDate: map['due_date'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(map['due_date'] as int),
    reminderDate: map['reminder_date'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(map['reminder_date'] as int),
    note: map['note'] as String?,
    closedKind: AdvanceClosedKindX.fromDb(map['closed_kind'] as String?),
    closedAt: map['closed_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(map['closed_at'] as int),
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
  );
}

class AdvanceSettlement {
  const AdvanceSettlement({
    required this.id,
    required this.advanceId,
    required this.amountCents,
    required this.transactionId,
    required this.accountId,
    required this.date,
    required this.createdAt,
    this.note,
  });

  final int id;
  final int advanceId;
  final int amountCents;
  final int transactionId;
  final int accountId;
  final DateTime date;
  final String? note;
  final DateTime createdAt;

  double get amount => Money.fromCents(amountCents);

  factory AdvanceSettlement.fromMap(Map<String, Object?> map) =>
      AdvanceSettlement(
        id: map['id'] as int,
        advanceId: map['advance_id'] as int,
        amountCents: (map['amount_cents'] as num).toInt(),
        transactionId: map['transaction_id'] as int,
        accountId: map['account_id'] as int,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        note: map['note'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          map['created_at'] as int,
        ),
      );
}

class AdvanceMatchSuggestion {
  const AdvanceMatchSuggestion({
    required this.advanceId,
    required this.personId,
    required this.confidence,
    required this.reason,
  });

  final int advanceId;
  final int personId;
  final double confidence;
  final String reason;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

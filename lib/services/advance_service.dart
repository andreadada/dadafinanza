import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

import '../core/money.dart';
import '../data/app_database.dart';
import '../models/advance_models.dart';
import '../models/models.dart';

/// Local-first ledger for informal advances between the user and other people.
///
/// Cash movements are real transactions so account balances stay correct, while
/// advance origin/settlement rows are excluded from ordinary income/expense
/// analytics. Remaining amounts are always derived from the settlement ledger.
class AdvanceService {
  AdvanceService(this.database);

  final AppDatabase database;

  Future<List<FinancePerson>> people({bool includeArchived = false}) async {
    final rows = await database.db.query(
      'finance_people',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'archived, name COLLATE NOCASE',
    );
    return rows.map(FinancePerson.fromMap).toList();
  }

  Future<List<Advance>> advances() async => (await database.db.query(
    'advances',
    orderBy: 'closed_at IS NOT NULL, created_at DESC, id DESC',
  )).map(Advance.fromMap).toList();

  Future<List<AdvanceSettlement>> settlements() async =>
      (await database.db.query(
        'advance_settlements',
        orderBy: 'date DESC, id DESC',
      )).map(AdvanceSettlement.fromMap).toList();

  Future<int> createPerson(
    String name, {
    int colorValue = 0xFF8E8E93,
    String iconKey = 'person',
    String? note,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty)
      throw StateError('Inserisci il nome della persona.');
    final now = DateTime.now().millisecondsSinceEpoch;
    return database.db.insert('finance_people', {
      'name': normalized,
      'color': colorValue,
      'icon_key': iconKey,
      'archived': 0,
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> archivePerson(int personId, bool archived) async {
    await database.db.update(
      'finance_people',
      {
        'archived': archived ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [personId],
    );
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
    final cents = _positiveCents(amount);
    return database.db.transaction((txn) async {
      await _validatePerson(txn, personId);
      await _validateAccount(txn, accountId);
      final transactionId = await _insertCashTransaction(
        txn,
        type: direction == AdvanceDirection.receivable
            ? TransactionType.expense
            : TransactionType.income,
        cents: cents,
        accountId: accountId,
        date: date,
        note: note,
        includeInAnalytics: false,
        kind: 'advance_origin',
      );
      await _applyCashDelta(
        txn,
        accountId,
        direction == AdvanceDirection.receivable ? -cents : cents,
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      return txn.insert('advances', {
        'direction': direction.dbValue,
        'person_id': personId,
        'original_amount_cents': cents,
        'source_account_id': accountId,
        'source_transaction_id': transactionId,
        'due_date': dueDate?.millisecondsSinceEpoch,
        'reminder_date': reminderDate?.millisecondsSinceEpoch,
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
        'closed_kind': null,
        'closed_at': null,
        'created_at': now,
        'updated_at': now,
      });
    });
  }

  /// Creates one real cash expense and one receivable allocation against it.
  /// [personalAmount] is what ordinary analytics/budgets should see.
  Future<int> createMixedExpense({
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
    DateTime? dueDate,
    DateTime? reminderDate,
  }) async {
    final totalCents = _positiveCents(totalAmount);
    final personalCents = Money.toCents(personalAmount);
    final advanceCents = _positiveCents(advanceAmount);
    if (personalCents < 0 || personalCents + advanceCents != totalCents) {
      throw StateError(
        'La tua parte e la quota anticipata devono coincidere con il totale.',
      );
    }
    return database.db.transaction((txn) async {
      await _validatePerson(txn, personId);
      await _validateAccount(txn, accountId);
      final category = await txn.query(
        'categories',
        columns: ['id', 'type'],
        where: 'id = ?',
        whereArgs: [categoryId],
        limit: 1,
      );
      if (category.isEmpty ||
          category.first['type'] != TransactionType.expense.name) {
        throw StateError('Scegli una categoria di spesa valida.');
      }
      final transactionId = await _insertCashTransaction(
        txn,
        type: TransactionType.expense,
        cents: totalCents,
        accountId: accountId,
        categoryId: categoryId,
        date: date,
        note: note,
        tags: tags,
        receiptPath: receiptPath,
        includeInAnalytics: includeInAnalytics,
        kind: 'mixed_advance',
      );
      await _applyCashDelta(txn, accountId, -totalCents);
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.insert('advances', {
        'direction': AdvanceDirection.receivable.dbValue,
        'person_id': personId,
        'original_amount_cents': advanceCents,
        'source_account_id': accountId,
        'source_transaction_id': transactionId,
        'due_date': dueDate?.millisecondsSinceEpoch,
        'reminder_date': reminderDate?.millisecondsSinceEpoch,
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
        'closed_kind': null,
        'closed_at': null,
        'created_at': now,
        'updated_at': now,
      });
      return transactionId;
    });
  }

  Future<int> remainingCents(int advanceId, {Transaction? txn}) async {
    final executor = txn ?? database.db;
    final rows = await executor.rawQuery(
      '''
      SELECT a.original_amount_cents - COALESCE(SUM(s.amount_cents), 0) AS remaining
      FROM advances a
      LEFT JOIN advance_settlements s ON s.advance_id = a.id
      WHERE a.id = ?
      GROUP BY a.id
    ''',
      [advanceId],
    );
    if (rows.isEmpty) throw StateError('Anticipo non trovato.');
    return math.max(0, (rows.first['remaining'] as num).toInt());
  }

  Future<int> settledCents(int advanceId) async {
    final value =
        Sqflite.firstIntValue(
          await database.db.rawQuery(
            'SELECT COALESCE(SUM(amount_cents), 0) FROM advance_settlements WHERE advance_id = ?',
            [advanceId],
          ),
        ) ??
        0;
    return value;
  }

  Future<int> recordSettlement({
    required int advanceId,
    required double amount,
    required int accountId,
    required DateTime date,
    String? note,
  }) async {
    final cents = _positiveCents(amount);
    return database.db.transaction((txn) async {
      final advance = await _advanceIn(txn, advanceId);
      if (advance.closedKind != null) {
        throw StateError('Questo anticipo è già chiuso.');
      }
      await _validateAccount(txn, accountId);
      final remaining = await remainingCents(advanceId, txn: txn);
      if (cents > remaining) {
        throw StateError(
          'L’importo supera il residuo di ${Money.fromCents(remaining).toStringAsFixed(2)} €.',
        );
      }
      final type = advance.direction == AdvanceDirection.receivable
          ? TransactionType.income
          : TransactionType.expense;
      final transactionId = await _insertCashTransaction(
        txn,
        type: type,
        cents: cents,
        accountId: accountId,
        date: date,
        note: note,
        includeInAnalytics: false,
        kind: 'advance_settlement',
      );
      await _applyCashDelta(
        txn,
        accountId,
        type == TransactionType.income ? cents : -cents,
      );
      final settlementId = await txn.insert('advance_settlements', {
        'advance_id': advanceId,
        'amount_cents': cents,
        'transaction_id': transactionId,
        'account_id': accountId,
        'date': date.millisecondsSinceEpoch,
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      await txn.update(
        'advances',
        {'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [advanceId],
      );
      return settlementId;
    });
  }

  Future<void> updateSettlement({
    required int settlementId,
    required double amount,
    required int accountId,
    required DateTime date,
    String? note,
  }) async {
    final cents = _positiveCents(amount);
    await database.db.transaction((txn) async {
      final rows = await txn.query(
        'advance_settlements',
        where: 'id = ?',
        whereArgs: [settlementId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Rimborso non trovato.');
      final old = AdvanceSettlement.fromMap(rows.first);
      final advance = await _advanceIn(txn, old.advanceId);
      if (advance.closedKind != null)
        throw StateError('Questo anticipo è già chiuso.');
      await _validateAccount(txn, accountId);
      final totalOther =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COALESCE(SUM(amount_cents),0) FROM advance_settlements WHERE advance_id = ? AND id <> ?',
              [old.advanceId, settlementId],
            ),
          ) ??
          0;
      if (totalOther + cents > advance.originalAmountCents) {
        throw StateError('L’importo supera il residuo disponibile.');
      }
      final transactionRows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [old.transactionId],
        limit: 1,
      );
      if (transactionRows.isEmpty)
        throw StateError('Movimento collegato non trovato.');
      final oldTransaction = FinanceTransaction.fromMap(transactionRows.first);
      await _applyCashDelta(
        txn,
        oldTransaction.accountId,
        oldTransaction.type == TransactionType.income
            ? -Money.toCents(oldTransaction.amount)
            : Money.toCents(oldTransaction.amount),
      );
      final type = advance.direction == AdvanceDirection.receivable
          ? TransactionType.income
          : TransactionType.expense;
      await txn.update(
        'transactions',
        {
          'type': type.name,
          'amount': Money.fromCents(cents),
          'amount_cents': cents,
          'account_id': accountId,
          'date': date.millisecondsSinceEpoch,
          'note': note?.trim().isEmpty == true ? null : note?.trim(),
          'include_in_analytics': 0,
          'kind': 'advance_settlement',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [old.transactionId],
      );
      await _applyCashDelta(
        txn,
        accountId,
        type == TransactionType.income ? cents : -cents,
      );
      await txn.update(
        'advance_settlements',
        {
          'amount_cents': cents,
          'account_id': accountId,
          'date': date.millisecondsSinceEpoch,
          'note': note?.trim().isEmpty == true ? null : note?.trim(),
        },
        where: 'id = ?',
        whereArgs: [settlementId],
      );
      await txn.update(
        'advances',
        {'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [old.advanceId],
      );
    });
  }

  Future<void> deleteSettlement(int settlementId) async {
    await database.db.transaction((txn) async {
      final rows = await txn.query(
        'advance_settlements',
        where: 'id = ?',
        whereArgs: [settlementId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final settlement = AdvanceSettlement.fromMap(rows.first);
      final txRows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [settlement.transactionId],
        limit: 1,
      );
      if (txRows.isNotEmpty) {
        final item = FinanceTransaction.fromMap(txRows.first);
        await _applyCashDelta(
          txn,
          item.accountId,
          item.type == TransactionType.income
              ? -Money.toCents(item.amount)
              : Money.toCents(item.amount),
        );
        await txn.delete('transactions', where: 'id = ?', whereArgs: [item.id]);
      } else {
        await txn.delete(
          'advance_settlements',
          where: 'id = ?',
          whereArgs: [settlementId],
        );
      }
      await txn.update(
        'advances',
        {'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [settlement.advanceId],
      );
    });
  }

  Future<void> linkExistingTransactionAsSettlement({
    required int advanceId,
    required int transactionId,
  }) async {
    await database.db.transaction((txn) async {
      final advance = await _advanceIn(txn, advanceId);
      if (advance.closedKind != null)
        throw StateError('Questo anticipo è già chiuso.');
      final rows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Movimento non trovato.');
      final item = FinanceTransaction.fromMap(rows.first);
      final expected = advance.direction == AdvanceDirection.receivable
          ? TransactionType.income
          : TransactionType.expense;
      if (item.type != expected)
        throw StateError('Il movimento ha una direzione incompatibile.');
      final cents = Money.toCents(item.amount);
      final remaining = await remainingCents(advanceId, txn: txn);
      if (cents > remaining)
        throw StateError('Il movimento supera il residuo dell’anticipo.');
      final existing =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM advance_settlements WHERE transaction_id = ?',
              [transactionId],
            ),
          ) ??
          0;
      if (existing > 0)
        throw StateError('Movimento già collegato a un anticipo.');
      await txn.update(
        'transactions',
        {
          'include_in_analytics': 0,
          'kind': 'advance_settlement',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [transactionId],
      );
      await txn.insert('advance_settlements', {
        'advance_id': advanceId,
        'amount_cents': cents,
        'transaction_id': transactionId,
        'account_id': item.accountId,
        'date': item.date.millisecondsSinceEpoch,
        'note': item.note,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  Future<void> closeWithoutRecovery({
    required int advanceId,
    required bool recognizeInAnalytics,
    int? categoryId,
    int? accountId,
    DateTime? date,
  }) async {
    await database.db.transaction((txn) async {
      final advance = await _advanceIn(txn, advanceId);
      if (advance.closedKind != null)
        throw StateError('Questo anticipo è già chiuso.');
      final remaining = await remainingCents(advanceId, txn: txn);
      if (remaining <= 0) return;
      final closedKind = advance.direction == AdvanceDirection.receivable
          ? AdvanceClosedKind.writtenOff
          : AdvanceClosedKind.forgiven;
      if (recognizeInAnalytics) {
        if (accountId == null)
          throw StateError('Scegli un conto per l’aggiustamento analitico.');
        await _validateAccount(txn, accountId);
        if (categoryId == null) throw StateError('Scegli una categoria.');
        final expectedType = advance.direction == AdvanceDirection.receivable
            ? TransactionType.expense
            : TransactionType.income;
        final categories = await txn.query(
          'categories',
          columns: ['type'],
          where: 'id = ?',
          whereArgs: [categoryId],
          limit: 1,
        );
        if (categories.isEmpty ||
            categories.first['type'] != expectedType.name) {
          throw StateError(
            'La categoria non è compatibile con l’aggiustamento.',
          );
        }
        await _insertCashTransaction(
          txn,
          type: expectedType,
          cents: remaining,
          accountId: accountId,
          categoryId: categoryId,
          date: date ?? DateTime.now(),
          note: advance.direction == AdvanceDirection.receivable
              ? 'Anticipo non recuperato'
              : 'Anticipo condonato',
          includeInAnalytics: true,
          kind: advance.direction == AdvanceDirection.receivable
              ? 'advance_writeoff'
              : 'advance_forgiven_income',
        );
        // Deliberately no account balance delta: cash moved at the origin.
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.update(
        'advances',
        {
          'closed_kind': closedKind.dbValue,
          'closed_at': now,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [advanceId],
      );
    });
  }

  Future<void> updateDates({
    required int advanceId,
    DateTime? dueDate,
    DateTime? reminderDate,
  }) async {
    await database.db.update(
      'advances',
      {
        'due_date': dueDate?.millisecondsSinceEpoch,
        'reminder_date': reminderDate?.millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [advanceId],
    );
  }

  Future<AdvanceMatchSuggestion?> suggestMatch({
    required TransactionType type,
    required double amount,
    String? note,
  }) async {
    if (type == TransactionType.transfer || amount <= 0) return null;
    final cents = Money.toCents(amount);
    final peopleById = {for (final person in await people()) person.id: person};
    final candidates = <(Advance, double, String)>[];
    for (final advance in await advances()) {
      if (advance.closedKind != null) continue;
      final expected = advance.direction == AdvanceDirection.receivable
          ? TransactionType.income
          : TransactionType.expense;
      if (type != expected) continue;
      final remaining = await remainingCents(advance.id);
      if (cents > remaining) continue;
      var score = 0.0;
      final reasons = <String>[];
      if (cents == remaining) {
        score += .58;
        reasons.add('importo uguale al residuo');
      } else if ((remaining - cents).abs() <= 100) {
        score += .28;
        reasons.add('importo vicino al residuo');
      } else {
        score += .12;
      }
      final person = peopleById[advance.personId];
      final normalizedNote = (note ?? '').toLowerCase();
      if (person != null &&
          normalizedNote.contains(person.name.toLowerCase())) {
        score += .34;
        reasons.add('nome ${person.name} nella descrizione');
      }
      final ageDays = DateTime.now().difference(advance.updatedAt).inDays.abs();
      if (ageDays <= 14) score += .08;
      if (score >= .66)
        candidates.add((advance, score.clamp(0, 1), reasons.join(' e ')));
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.$2.compareTo(a.$2));
    if (candidates.length > 1 && (candidates[0].$2 - candidates[1].$2) < .12) {
      return null;
    }
    final best = candidates.first;
    return AdvanceMatchSuggestion(
      advanceId: best.$1.id,
      personId: best.$1.personId,
      confidence: best.$2,
      reason: best.$3,
    );
  }

  int _positiveCents(double value) {
    final cents = Money.toCents(value);
    if (cents <= 0) throw StateError('L’importo deve essere maggiore di 0.');
    return cents;
  }

  Future<void> _validatePerson(Transaction txn, int id) async {
    final rows = await txn.query(
      'finance_people',
      where: 'id = ? AND archived = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Persona non disponibile.');
  }

  Future<void> _validateAccount(Transaction txn, int id) async {
    final rows = await txn.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Conto non trovato.');
    final row = rows.first;
    if ((row['is_system'] as int? ?? 0) == 1) {
      throw StateError('Gli anticipi richiedono un conto reale.');
    }
    if ((row['is_archived'] as int? ?? 0) == 1)
      throw StateError('Il conto è archiviato.');
    if ((row['is_locked'] as int? ?? 0) == 1)
      throw StateError('Il conto è bloccato.');
  }

  Future<Advance> _advanceIn(Transaction txn, int id) async {
    final rows = await txn.query(
      'advances',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Anticipo non trovato.');
    return Advance.fromMap(rows.first);
  }

  Future<int> _insertCashTransaction(
    Transaction txn, {
    required TransactionType type,
    required int cents,
    required int accountId,
    required DateTime date,
    required bool includeInAnalytics,
    required String kind,
    int? categoryId,
    String? note,
    List<String> tags = const [],
    String? receiptPath,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return txn.insert('transactions', {
      'type': type.name,
      'amount': Money.fromCents(cents),
      'amount_cents': cents,
      'account_id': accountId,
      'to_account_id': null,
      'category_id': categoryId,
      'date': date.millisecondsSinceEpoch,
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
      'tags': tags.join('|'),
      'receipt_path': receiptPath,
      'include_in_analytics': includeInAnalytics ? 1 : 0,
      'recurring_id': null,
      'refund_of_transaction_id': null,
      'kind': kind,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> _applyCashDelta(
    Transaction txn,
    int accountId,
    int deltaCents,
  ) async {
    await txn.rawUpdate(
      'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
      [
        Money.fromCents(deltaCents),
        DateTime.now().millisecondsSinceEpoch,
        accountId,
      ],
    );
  }
}

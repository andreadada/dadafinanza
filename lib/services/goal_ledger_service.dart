import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

import '../core/money.dart';
import '../data/app_database.dart';
import 'finance_schema_service.dart';

/// Explicit local ledger for goal progress.
///
/// The schema belongs to [FinanceSchemaService]. This service only performs
/// goal operations and never creates a second competing schema definition.
class GoalLedgerService {
  GoalLedgerService(this.database);

  final AppDatabase database;

  /// Kept for compatibility with older callers. Schema ownership is now
  /// centralized in FinanceSchemaService.
  Future<void> ensureSchema() => FinanceSchemaService(database).ensure();

  static double clampManualDelta({
    required double current,
    required double target,
    required double delta,
  }) {
    final currentCents = Money.toCents(current);
    final targetCents = Money.toCents(target);
    final deltaCents = Money.toCents(delta);
    final applied = deltaCents > 0
        ? math.min(deltaCents, math.max(0, targetCents - currentCents))
        : math.max(deltaCents, -math.max(0, currentCents));
    return Money.fromCents(applied.toInt());
  }

  Future<void> recordManual(int goalId, double delta) async {
    final db = database.db;
    final rows = await db.query(
      'goals',
      columns: [
        'current_amount',
        'target_amount',
        'current_amount_cents',
        'target_amount_cents',
      ],
      where: 'id = ?',
      whereArgs: [goalId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Obiettivo non trovato.');
    final currentCents =
        (rows.first['current_amount_cents'] as num?)?.toInt() ??
        Money.toCents((rows.first['current_amount'] as num).toDouble());
    final targetCents =
        (rows.first['target_amount_cents'] as num?)?.toInt() ??
        Money.toCents((rows.first['target_amount'] as num).toDouble());
    final requested = Money.toCents(delta);
    final applied = requested > 0
        ? math.min(requested, math.max(0, targetCents - currentCents))
        : math.max(requested, -math.max(0, currentCents));
    if (applied == 0) return;
    await db.insert('goal_entries', {
      'goal_id': goalId,
      'transaction_id': null,
      'amount': Money.fromCents(applied.toInt()),
      'amount_cents': applied,
      'kind': 'manual',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> linkTransfer({
    required int goalId,
    required int transactionId,
  }) async {
    final db = database.db;
    await db.transaction((txn) async {
      final goals = await txn.query(
        'goals',
        columns: ['linked_account_id'],
        where: 'id = ?',
        whereArgs: [goalId],
        limit: 1,
      );
      if (goals.isEmpty) throw StateError('Obiettivo non trovato.');
      final linkedAccountId = goals.first['linked_account_id'] as int?;
      if (linkedAccountId == null) {
        throw StateError('L’obiettivo non ha un conto collegato.');
      }

      final transactions = await txn.query(
        'transactions',
        columns: ['type', 'amount', 'amount_cents', 'to_account_id'],
        where: 'id = ?',
        whereArgs: [transactionId],
        limit: 1,
      );
      if (transactions.isEmpty) {
        throw StateError('Trasferimento non trovato.');
      }
      final item = transactions.first;
      if (item['type'] != 'transfer' ||
          item['to_account_id'] != linkedAccountId) {
        throw StateError(
          'Il trasferimento deve arrivare al conto collegato all’obiettivo.',
        );
      }
      final cents =
          (item['amount_cents'] as num?)?.toInt() ??
          Money.toCents((item['amount'] as num).toDouble());
      await txn.insert('goal_entries', {
        'goal_id': goalId,
        'transaction_id': transactionId,
        'amount': Money.fromCents(cents),
        'amount_cents': cents,
        'kind': 'transfer',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}

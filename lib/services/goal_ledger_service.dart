import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';

/// Explicit local ledger for goal progress.
///
/// Manual adjustments and goal-linked transfers are stored as ledger
/// entries. SQLite triggers keep the cached Goal.currentAmount in sync
/// when a linked transfer is edited or deleted.
class GoalLedgerService {
  GoalLedgerService(this.database);

  final AppDatabase database;

  Future<void> ensureSchema() async {
    final db = database.db;
    await db.transaction((txn) async {
      await txn.execute('''CREATE TABLE IF NOT EXISTS goal_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL,
        transaction_id INTEGER UNIQUE,
        amount REAL NOT NULL,
        kind TEXT NOT NULL DEFAULT 'manual',
        created_at INTEGER NOT NULL,
        FOREIGN KEY(goal_id) REFERENCES goals(id) ON DELETE CASCADE,
        FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
      )''');
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_goal_entries_goal ON goal_entries(goal_id)',
      );

      await txn.execute('''CREATE TRIGGER IF NOT EXISTS goal_entries_after_insert
        AFTER INSERT ON goal_entries
        BEGIN
          UPDATE goals
          SET current_amount = MIN(target_amount, MAX(0, COALESCE((
                SELECT SUM(amount) FROM goal_entries WHERE goal_id = NEW.goal_id
              ), 0))),
              completed = CASE WHEN COALESCE((
                SELECT SUM(amount) FROM goal_entries WHERE goal_id = NEW.goal_id
              ), 0) >= target_amount THEN 1 ELSE 0 END
          WHERE id = NEW.goal_id;
        END''');

      await txn.execute('''CREATE TRIGGER IF NOT EXISTS goal_entries_after_update
        AFTER UPDATE OF amount, goal_id ON goal_entries
        BEGIN
          UPDATE goals
          SET current_amount = MIN(target_amount, MAX(0, COALESCE((
                SELECT SUM(amount) FROM goal_entries WHERE goal_id = OLD.goal_id
              ), 0))),
              completed = CASE WHEN COALESCE((
                SELECT SUM(amount) FROM goal_entries WHERE goal_id = OLD.goal_id
              ), 0) >= target_amount THEN 1 ELSE 0 END
          WHERE id = OLD.goal_id;
          UPDATE goals
          SET current_amount = MIN(target_amount, MAX(0, COALESCE((
                SELECT SUM(amount) FROM goal_entries WHERE goal_id = NEW.goal_id
              ), 0))),
              completed = CASE WHEN COALESCE((
                SELECT SUM(amount) FROM goal_entries WHERE goal_id = NEW.goal_id
              ), 0) >= target_amount THEN 1 ELSE 0 END
          WHERE id = NEW.goal_id;
        END''');

      await txn.execute('''CREATE TRIGGER IF NOT EXISTS goal_entries_after_delete
        AFTER DELETE ON goal_entries
        BEGIN
          UPDATE goals
          SET current_amount = MIN(target_amount, MAX(0, COALESCE((
                SELECT SUM(amount) FROM goal_entries WHERE goal_id = OLD.goal_id
              ), 0))),
              completed = CASE WHEN COALESCE((
                SELECT SUM(amount) FROM goal_entries WHERE goal_id = OLD.goal_id
              ), 0) >= target_amount THEN 1 ELSE 0 END
          WHERE id = OLD.goal_id;
        END''');

      await txn.execute('''CREATE TRIGGER IF NOT EXISTS goal_transfer_before_delete
        BEFORE DELETE ON transactions
        BEGIN
          DELETE FROM goal_entries WHERE transaction_id = OLD.id;
        END''');

      await txn.execute('''CREATE TRIGGER IF NOT EXISTS goal_transfer_after_update
        AFTER UPDATE OF amount, type, to_account_id ON transactions
        WHEN EXISTS(
          SELECT 1 FROM goal_entries WHERE transaction_id = NEW.id
        )
        BEGIN
          UPDATE goal_entries
          SET amount = NEW.amount
          WHERE transaction_id = NEW.id
            AND NEW.type = 'transfer'
            AND EXISTS(
              SELECT 1
              FROM goals
              WHERE goals.id = goal_entries.goal_id
                AND goals.linked_account_id = NEW.to_account_id
            );
          DELETE FROM goal_entries
          WHERE transaction_id = NEW.id
            AND (
              NEW.type <> 'transfer'
              OR NOT EXISTS(
                SELECT 1
                FROM goals
                WHERE goals.id = goal_entries.goal_id
                  AND goals.linked_account_id = NEW.to_account_id
              )
            );
        END''');

      final migrated = await txn.query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['goal_ledger_migrated'],
        limit: 1,
      );
      if (migrated.isEmpty) {
        final goals = await txn.query('goals');
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final goal in goals) {
          final goalId = goal['id'] as int;
          final current = (goal['current_amount'] as num? ?? 0).toDouble();
          if (current <= 0) continue;
          final existing = Sqflite.firstIntValue(
                await txn.rawQuery(
                  'SELECT COUNT(*) FROM goal_entries WHERE goal_id = ?',
                  [goalId],
                ),
              ) ??
              0;
          if (existing == 0) {
            await txn.insert('goal_entries', {
              'goal_id': goalId,
              'transaction_id': null,
              'amount': current,
              'kind': 'opening',
              'created_at': now,
            });
          }
        }
        await txn.insert(
          'settings',
          {'key': 'goal_ledger_migrated', 'value': '1'},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static double clampManualDelta({
    required double current,
    required double target,
    required double delta,
  }) {
    if (delta > 0) {
      return math.min(delta, math.max(0, target - current)).toDouble();
    }
    return math.max(delta, -math.max(0, current)).toDouble();
  }

  Future<void> recordManual(int goalId, double delta) async {
    await ensureSchema();
    final db = database.db;
    final rows = await db.query(
      'goals',
      columns: ['current_amount', 'target_amount'],
      where: 'id = ?',
      whereArgs: [goalId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Obiettivo non trovato.');
    final current = (rows.first['current_amount'] as num).toDouble();
    final target = (rows.first['target_amount'] as num).toDouble();
    final applied = clampManualDelta(
      current: current,
      target: target,
      delta: delta,
    );
    if (applied.abs() < .005) return;
    await db.insert('goal_entries', {
      'goal_id': goalId,
      'transaction_id': null,
      'amount': applied,
      'kind': 'manual',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> linkTransfer({
    required int goalId,
    required int transactionId,
  }) async {
    await ensureSchema();
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
        columns: ['type', 'amount', 'to_account_id'],
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
      await txn.insert(
        'goal_entries',
        {
          'goal_id': goalId,
          'transaction_id': transactionId,
          'amount': (item['amount'] as num).toDouble(),
          'kind': 'transfer',
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }
}

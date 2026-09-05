import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';

/// Non-destructive schema evolution for the finance-hardening layer.
///
/// The legacy REAL columns are intentionally retained for compatibility with
/// older builds. Integer cent columns are the canonical read representation;
/// compatibility triggers quantize every legacy write to two decimals and
/// mirror it into the integer columns.
class FinanceSchemaService {
  FinanceSchemaService(this.database);

  final AppDatabase database;

  Future<void> ensure() async {
    final db = database.db;
    await db.transaction((txn) async {
      await _addColumn(txn, 'accounts', 'balance_cents', 'INTEGER');
      await _addColumn(txn, 'accounts', 'opening_balance_cents', 'INTEGER');
      await _addColumn(txn, 'accounts', 'opening_balance', 'REAL');
      await _addColumn(txn, 'accounts', 'last_reconciled_at', 'INTEGER');
      await _addColumn(txn, 'transactions', 'amount_cents', 'INTEGER');
      await _addColumn(
        txn,
        'transactions',
        'kind',
        "TEXT NOT NULL DEFAULT 'normal'",
      );
      await _addColumn(txn, 'transaction_splits', 'amount_cents', 'INTEGER');
      await _addColumn(txn, 'recurring', 'amount_cents', 'INTEGER');
      await _addColumn(txn, 'recurring', 'to_account_id', 'INTEGER');
      await _addColumn(txn, 'budgets', 'limit_cents', 'INTEGER');
      await _addColumn(txn, 'goals', 'target_amount_cents', 'INTEGER');
      await _addColumn(txn, 'goals', 'current_amount_cents', 'INTEGER');
      await _addColumn(txn, 'automation_rules', 'min_amount_cents', 'INTEGER');
      await _addColumn(txn, 'automation_rules', 'max_amount_cents', 'INTEGER');
      await _addColumn(
        txn,
        'automation_rules',
        'priority',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumn(
        txn,
        'categories',
        'is_favorite',
        'INTEGER NOT NULL DEFAULT 0',
      );

      await txn.rawUpdate(
        'UPDATE accounts SET balance_cents = CAST(ROUND(balance * 100) AS INTEGER) WHERE balance_cents IS NULL',
      );
      await txn.rawUpdate(
        'UPDATE accounts SET opening_balance_cents = CAST(ROUND(balance * 100) AS INTEGER), opening_balance = balance WHERE opening_balance_cents IS NULL',
      );
      await txn.rawUpdate(
        'UPDATE transactions SET amount_cents = CAST(ROUND(amount * 100) AS INTEGER) WHERE amount_cents IS NULL',
      );
      await txn.rawUpdate(
        'UPDATE transaction_splits SET amount_cents = CAST(ROUND(amount * 100) AS INTEGER) WHERE amount_cents IS NULL',
      );
      await txn.rawUpdate(
        'UPDATE recurring SET amount_cents = CAST(ROUND(amount * 100) AS INTEGER) WHERE amount_cents IS NULL',
      );
      await txn.rawUpdate(
        'UPDATE budgets SET limit_cents = CAST(ROUND(limit_amount * 100) AS INTEGER) WHERE limit_cents IS NULL',
      );
      await txn.rawUpdate(
        'UPDATE goals SET target_amount_cents = CAST(ROUND(target_amount * 100) AS INTEGER), current_amount_cents = CAST(ROUND(current_amount * 100) AS INTEGER) WHERE target_amount_cents IS NULL OR current_amount_cents IS NULL',
      );
      await txn.rawUpdate(
        'UPDATE automation_rules SET min_amount_cents = CASE WHEN min_amount IS NULL THEN NULL ELSE CAST(ROUND(min_amount * 100) AS INTEGER) END, max_amount_cents = CASE WHEN max_amount IS NULL THEN NULL ELSE CAST(ROUND(max_amount * 100) AS INTEGER) END',
      );

      await _ensureGoalLedger(txn);
      await _ensurePresets(txn);
      await _ensureCompatibilityTriggers(txn);
      await _ensureIndexes(txn);
    });
  }

  Future<void> _ensureGoalLedger(Transaction txn) async {
    await txn.execute('''CREATE TABLE IF NOT EXISTS goal_entries(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      goal_id INTEGER NOT NULL,
      transaction_id INTEGER UNIQUE,
      amount REAL NOT NULL DEFAULT 0,
      amount_cents INTEGER,
      kind TEXT NOT NULL DEFAULT 'manual',
      created_at INTEGER NOT NULL,
      FOREIGN KEY(goal_id) REFERENCES goals(id) ON DELETE CASCADE,
      FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
    )''');
    await _addColumn(txn, 'goal_entries', 'amount_cents', 'INTEGER');
    await txn.rawUpdate(
      'UPDATE goal_entries SET amount_cents = CAST(ROUND(amount * 100) AS INTEGER) WHERE amount_cents IS NULL',
    );

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
        final cents =
            (goal['current_amount_cents'] as num?)?.toInt() ??
            (((goal['current_amount'] as num?) ?? 0) * 100).round();
        if (cents <= 0) continue;
        final count =
            Sqflite.firstIntValue(
              await txn.rawQuery(
                'SELECT COUNT(*) FROM goal_entries WHERE goal_id = ?',
                [goalId],
              ),
            ) ??
            0;
        if (count == 0) {
          await txn.insert('goal_entries', {
            'goal_id': goalId,
            'transaction_id': null,
            'amount': cents / 100,
            'amount_cents': cents,
            'kind': 'opening',
            'created_at': now,
          });
        }
      }
      await txn.insert('settings', {
        'key': 'goal_ledger_migrated',
        'value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _ensurePresets(Transaction txn) async {
    await txn.execute('''CREATE TABLE IF NOT EXISTS quick_presets(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      account_id INTEGER,
      to_account_id INTEGER,
      category_id INTEGER,
      amount_cents INTEGER,
      note TEXT,
      tags TEXT,
      position INTEGER NOT NULL DEFAULT 0,
      enabled INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )''');
  }

  Future<void> _ensureCompatibilityTriggers(Transaction txn) async {
    const triggerNames = [
      'money_accounts_insert',
      'money_accounts_update',
      'money_transactions_insert',
      'money_transactions_update',
      'money_splits_insert',
      'money_splits_update',
      'money_recurring_insert',
      'money_recurring_update',
      'money_budgets_insert',
      'money_budgets_update',
      'money_goals_insert',
      'money_goals_update',
      'money_rules_insert',
      'money_rules_update',
      'money_goal_entries_insert',
      'money_goal_entries_update',
      'goal_entries_after_insert',
      'goal_entries_after_update',
      'goal_entries_after_delete',
      'goal_transfer_before_delete',
      'goal_transfer_after_update',
    ];
    for (final name in triggerNames) {
      await txn.execute('DROP TRIGGER IF EXISTS $name');
    }

    await txn.execute('''CREATE TRIGGER money_accounts_insert
      AFTER INSERT ON accounts BEGIN
        UPDATE accounts SET
          balance_cents = CAST(ROUND(NEW.balance * 100) AS INTEGER),
          balance = CAST(ROUND(NEW.balance * 100) AS INTEGER) / 100.0,
          opening_balance_cents = COALESCE(NEW.opening_balance_cents, CAST(ROUND(NEW.balance * 100) AS INTEGER)),
          opening_balance = COALESCE(NEW.opening_balance, CAST(ROUND(NEW.balance * 100) AS INTEGER) / 100.0)
        WHERE id = NEW.id;
      END''');
    await txn.execute('''CREATE TRIGGER money_accounts_update
      AFTER UPDATE OF balance ON accounts BEGIN
        UPDATE accounts SET
          balance_cents = CAST(ROUND(NEW.balance * 100) AS INTEGER),
          balance = CAST(ROUND(NEW.balance * 100) AS INTEGER) / 100.0
        WHERE id = NEW.id;
      END''');
    await txn.execute('''CREATE TRIGGER money_transactions_insert
      AFTER INSERT ON transactions BEGIN
        UPDATE transactions SET amount_cents = CAST(ROUND(NEW.amount * 100) AS INTEGER), amount = CAST(ROUND(NEW.amount * 100) AS INTEGER) / 100.0 WHERE id = NEW.id;
      END''');
    await txn.execute('''CREATE TRIGGER money_transactions_update
      AFTER UPDATE OF amount ON transactions BEGIN
        UPDATE transactions SET amount_cents = CAST(ROUND(NEW.amount * 100) AS INTEGER), amount = CAST(ROUND(NEW.amount * 100) AS INTEGER) / 100.0 WHERE id = NEW.id;
      END''');
    await txn.execute('''CREATE TRIGGER money_splits_insert
      AFTER INSERT ON transaction_splits BEGIN
        UPDATE transaction_splits SET amount_cents = CAST(ROUND(NEW.amount * 100) AS INTEGER), amount = CAST(ROUND(NEW.amount * 100) AS INTEGER) / 100.0 WHERE id = NEW.id;
      END''');
    await txn.execute('''CREATE TRIGGER money_splits_update
      AFTER UPDATE OF amount ON transaction_splits BEGIN
        UPDATE transaction_splits SET amount_cents = CAST(ROUND(NEW.amount * 100) AS INTEGER), amount = CAST(ROUND(NEW.amount * 100) AS INTEGER) / 100.0 WHERE id = NEW.id;
      END''');
    await txn.execute('''CREATE TRIGGER money_recurring_insert
      AFTER INSERT ON recurring BEGIN
        UPDATE recurring SET amount_cents = CAST(ROUND(NEW.amount * 100) AS INTEGER), amount = CAST(ROUND(NEW.amount * 100) AS INTEGER) / 100.0 WHERE id = NEW.id;
      END''');
    await txn.execute('''CREATE TRIGGER money_recurring_update
      AFTER UPDATE OF amount ON recurring BEGIN
        UPDATE recurring SET amount_cents = CAST(ROUND(NEW.amount * 100) AS INTEGER), amount = CAST(ROUND(NEW.amount * 100) AS INTEGER) / 100.0 WHERE id = NEW.id;
      END''');
    await txn.execute('''CREATE TRIGGER money_budgets_insert
      AFTER INSERT ON budgets BEGIN
        UPDATE budgets SET limit_cents = CAST(ROUND(NEW.limit_amount * 100) AS INTEGER), limit_amount = CAST(ROUND(NEW.limit_amount * 100) AS INTEGER) / 100.0 WHERE id = NEW.id;
      END''');
    await txn.execute('''CREATE TRIGGER money_budgets_update
      AFTER UPDATE OF limit_amount ON budgets BEGIN
        UPDATE budgets SET limit_cents = CAST(ROUND(NEW.limit_amount * 100) AS INTEGER), limit_amount = CAST(ROUND(NEW.limit_amount * 100) AS INTEGER) / 100.0 WHERE id = NEW.id;
      END''');
    await txn.execute('''CREATE TRIGGER money_goals_insert
      AFTER INSERT ON goals BEGIN
        UPDATE goals SET target_amount_cents = CAST(ROUND(NEW.target_amount * 100) AS INTEGER), current_amount_cents = CAST(ROUND(NEW.current_amount * 100) AS INTEGER), target_amount = CAST(ROUND(NEW.target_amount * 100) AS INTEGER) / 100.0, current_amount = CAST(ROUND(NEW.current_amount * 100) AS INTEGER) / 100.0 WHERE id = NEW.id;
      END''');
    await txn.execute('''CREATE TRIGGER money_goals_update
      AFTER UPDATE OF target_amount, current_amount ON goals BEGIN
        UPDATE goals SET target_amount_cents = CAST(ROUND(NEW.target_amount * 100) AS INTEGER), current_amount_cents = CAST(ROUND(NEW.current_amount * 100) AS INTEGER), target_amount = CAST(ROUND(NEW.target_amount * 100) AS INTEGER) / 100.0, current_amount = CAST(ROUND(NEW.current_amount * 100) AS INTEGER) / 100.0 WHERE id = NEW.id;
      END''');
    await txn.execute('''CREATE TRIGGER money_rules_insert
      AFTER INSERT ON automation_rules BEGIN
        UPDATE automation_rules SET min_amount_cents = CASE WHEN NEW.min_amount IS NULL THEN NULL ELSE CAST(ROUND(NEW.min_amount * 100) AS INTEGER) END, max_amount_cents = CASE WHEN NEW.max_amount IS NULL THEN NULL ELSE CAST(ROUND(NEW.max_amount * 100) AS INTEGER) END WHERE id = NEW.id;
      END''');
    await txn.execute('''CREATE TRIGGER money_rules_update
      AFTER UPDATE OF min_amount, max_amount ON automation_rules BEGIN
        UPDATE automation_rules SET min_amount_cents = CASE WHEN NEW.min_amount IS NULL THEN NULL ELSE CAST(ROUND(NEW.min_amount * 100) AS INTEGER) END, max_amount_cents = CASE WHEN NEW.max_amount IS NULL THEN NULL ELSE CAST(ROUND(NEW.max_amount * 100) AS INTEGER) END WHERE id = NEW.id;
      END''');
    await txn.execute('''CREATE TRIGGER money_goal_entries_insert
      AFTER INSERT ON goal_entries BEGIN
        UPDATE goal_entries SET amount_cents = CAST(ROUND(NEW.amount * 100) AS INTEGER), amount = CAST(ROUND(NEW.amount * 100) AS INTEGER) / 100.0 WHERE id = NEW.id;
      END''');
    await txn.execute('''CREATE TRIGGER money_goal_entries_update
      AFTER UPDATE OF amount ON goal_entries BEGIN
        UPDATE goal_entries SET amount_cents = CAST(ROUND(NEW.amount * 100) AS INTEGER), amount = CAST(ROUND(NEW.amount * 100) AS INTEGER) / 100.0 WHERE id = NEW.id;
      END''');

    await txn.execute('''CREATE TRIGGER goal_entries_after_insert
      AFTER INSERT ON goal_entries BEGIN
        UPDATE goals SET
          current_amount_cents = MIN(target_amount_cents, MAX(0, COALESCE((SELECT SUM(amount_cents) FROM goal_entries WHERE goal_id = NEW.goal_id), 0))),
          current_amount = MIN(target_amount_cents, MAX(0, COALESCE((SELECT SUM(amount_cents) FROM goal_entries WHERE goal_id = NEW.goal_id), 0))) / 100.0,
          completed = CASE WHEN COALESCE((SELECT SUM(amount_cents) FROM goal_entries WHERE goal_id = NEW.goal_id), 0) >= target_amount_cents THEN 1 ELSE 0 END
        WHERE id = NEW.goal_id;
      END''');
    await txn.execute('''CREATE TRIGGER goal_entries_after_update
      AFTER UPDATE OF amount_cents, goal_id ON goal_entries BEGIN
        UPDATE goals SET current_amount_cents = MIN(target_amount_cents, MAX(0, COALESCE((SELECT SUM(amount_cents) FROM goal_entries WHERE goal_id = OLD.goal_id), 0))), current_amount = MIN(target_amount_cents, MAX(0, COALESCE((SELECT SUM(amount_cents) FROM goal_entries WHERE goal_id = OLD.goal_id), 0))) / 100.0, completed = CASE WHEN COALESCE((SELECT SUM(amount_cents) FROM goal_entries WHERE goal_id = OLD.goal_id), 0) >= target_amount_cents THEN 1 ELSE 0 END WHERE id = OLD.goal_id;
        UPDATE goals SET current_amount_cents = MIN(target_amount_cents, MAX(0, COALESCE((SELECT SUM(amount_cents) FROM goal_entries WHERE goal_id = NEW.goal_id), 0))), current_amount = MIN(target_amount_cents, MAX(0, COALESCE((SELECT SUM(amount_cents) FROM goal_entries WHERE goal_id = NEW.goal_id), 0))) / 100.0, completed = CASE WHEN COALESCE((SELECT SUM(amount_cents) FROM goal_entries WHERE goal_id = NEW.goal_id), 0) >= target_amount_cents THEN 1 ELSE 0 END WHERE id = NEW.goal_id;
      END''');
    await txn.execute('''CREATE TRIGGER goal_entries_after_delete
      AFTER DELETE ON goal_entries BEGIN
        UPDATE goals SET current_amount_cents = MIN(target_amount_cents, MAX(0, COALESCE((SELECT SUM(amount_cents) FROM goal_entries WHERE goal_id = OLD.goal_id), 0))), current_amount = MIN(target_amount_cents, MAX(0, COALESCE((SELECT SUM(amount_cents) FROM goal_entries WHERE goal_id = OLD.goal_id), 0))) / 100.0, completed = CASE WHEN COALESCE((SELECT SUM(amount_cents) FROM goal_entries WHERE goal_id = OLD.goal_id), 0) >= target_amount_cents THEN 1 ELSE 0 END WHERE id = OLD.goal_id;
      END''');
    await txn.execute('''CREATE TRIGGER goal_transfer_before_delete
      BEFORE DELETE ON transactions BEGIN
        DELETE FROM goal_entries WHERE transaction_id = OLD.id;
      END''');
    await txn.execute('''CREATE TRIGGER goal_transfer_after_update
      AFTER UPDATE OF amount, type, to_account_id ON transactions
      WHEN EXISTS(SELECT 1 FROM goal_entries WHERE transaction_id = NEW.id)
      BEGIN
        UPDATE goal_entries SET amount = NEW.amount WHERE transaction_id = NEW.id AND NEW.type = 'transfer' AND EXISTS(SELECT 1 FROM goals WHERE goals.id = goal_entries.goal_id AND goals.linked_account_id = NEW.to_account_id);
        DELETE FROM goal_entries WHERE transaction_id = NEW.id AND (NEW.type <> 'transfer' OR NOT EXISTS(SELECT 1 FROM goals WHERE goals.id = goal_entries.goal_id AND goals.linked_account_id = NEW.to_account_id));
      END''');
  }

  Future<void> _ensureIndexes(Transaction txn) async {
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_goal_entries_goal ON goal_entries(goal_id)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_recurring_destination ON recurring(to_account_id)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_rules_priority ON automation_rules(priority DESC, id ASC)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_presets_position ON quick_presets(enabled, position)',
    );
  }

  Future<void> _addColumn(
    Transaction txn,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await txn.rawQuery('PRAGMA table_info($table)');
    if (!columns.any((row) => row['name'] == column)) {
      await txn.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }
}

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
      await _ensureAdvances(txn);
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

  Future<void> _ensureAdvances(Transaction txn) async {
    await txn.execute('''CREATE TABLE IF NOT EXISTS finance_people(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL COLLATE NOCASE,
      color INTEGER NOT NULL DEFAULT 4287532691,
      icon_key TEXT NOT NULL DEFAULT 'person',
      archived INTEGER NOT NULL DEFAULT 0 CHECK(archived IN (0,1)),
      note TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )''');
    await txn.execute('''CREATE TABLE IF NOT EXISTS advances(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      direction TEXT NOT NULL CHECK(direction IN ('receivable','payable')),
      person_id INTEGER NOT NULL,
      original_amount_cents INTEGER NOT NULL CHECK(original_amount_cents > 0),
      source_account_id INTEGER,
      source_transaction_id INTEGER,
      due_date INTEGER,
      reminder_date INTEGER,
      note TEXT,
      closed_kind TEXT CHECK(closed_kind IS NULL OR closed_kind IN ('cancelled','writtenOff','forgiven')),
      closed_at INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY(person_id) REFERENCES finance_people(id) ON DELETE RESTRICT,
      FOREIGN KEY(source_account_id) REFERENCES accounts(id) ON DELETE SET NULL,
      FOREIGN KEY(source_transaction_id) REFERENCES transactions(id) ON DELETE RESTRICT
    )''');
    await txn.execute('''CREATE TABLE IF NOT EXISTS advance_settlements(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      advance_id INTEGER NOT NULL,
      amount_cents INTEGER NOT NULL CHECK(amount_cents > 0),
      transaction_id INTEGER NOT NULL UNIQUE,
      account_id INTEGER NOT NULL,
      date INTEGER NOT NULL,
      note TEXT,
      created_at INTEGER NOT NULL,
      FOREIGN KEY(advance_id) REFERENCES advances(id) ON DELETE CASCADE,
      FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
      FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT
    )''');

    await txn.insert('settings', {
      'key': 'notifications_advances',
      'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await txn.insert('settings', {
      'key': 'advances_default_reminder_days',
      'value': '7',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    for (final name in const [
      'advance_settlement_validate_insert',
      'advance_settlement_validate_update',
      'advance_settlement_sync_transaction',
    ]) {
      await txn.execute('DROP TRIGGER IF EXISTS $name');
    }
    await txn.execute('''CREATE TRIGGER advance_settlement_validate_insert
      BEFORE INSERT ON advance_settlements
      BEGIN
        SELECT CASE
          WHEN NEW.amount_cents <= 0 THEN RAISE(ABORT, 'advance settlement must be positive')
          WHEN NOT EXISTS(SELECT 1 FROM advances WHERE id = NEW.advance_id AND closed_kind IS NULL)
            THEN RAISE(ABORT, 'advance is closed or missing')
          WHEN NEW.amount_cents + COALESCE((SELECT SUM(amount_cents) FROM advance_settlements WHERE advance_id = NEW.advance_id), 0)
               > (SELECT original_amount_cents FROM advances WHERE id = NEW.advance_id)
            THEN RAISE(ABORT, 'advance settlement exceeds remaining amount')
        END;
      END''');
    await txn.execute('''CREATE TRIGGER advance_settlement_validate_update
      BEFORE UPDATE OF amount_cents, advance_id ON advance_settlements
      BEGIN
        SELECT CASE
          WHEN NEW.amount_cents <= 0 THEN RAISE(ABORT, 'advance settlement must be positive')
          WHEN NOT EXISTS(SELECT 1 FROM advances WHERE id = NEW.advance_id AND closed_kind IS NULL)
            THEN RAISE(ABORT, 'advance is closed or missing')
          WHEN NEW.amount_cents + COALESCE((SELECT SUM(amount_cents) FROM advance_settlements WHERE advance_id = NEW.advance_id AND id <> OLD.id), 0)
               > (SELECT original_amount_cents FROM advances WHERE id = NEW.advance_id)
            THEN RAISE(ABORT, 'advance settlement exceeds remaining amount')
        END;
      END''');
    await txn.execute('''CREATE TRIGGER advance_settlement_sync_transaction
      AFTER UPDATE OF amount, account_id, date, note ON transactions
      WHEN NEW.kind = 'advance_settlement' AND EXISTS(SELECT 1 FROM advance_settlements WHERE transaction_id = NEW.id)
      BEGIN
        UPDATE advance_settlements SET
          amount_cents = CAST(ROUND(NEW.amount * 100) AS INTEGER),
          account_id = NEW.account_id,
          date = NEW.date,
          note = NEW.note
        WHERE transaction_id = NEW.id;
      END''');
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
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_advances_person ON advances(person_id, closed_at)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_advances_source_transaction ON advances(source_transaction_id)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_advances_due ON advances(due_date, reminder_date)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_advance_settlements_advance ON advance_settlements(advance_id, date)',
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

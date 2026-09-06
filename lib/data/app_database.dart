import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../models/smart_models.dart';

class AppDatabase {
  static const databaseVersion = 4;
  static const _unassignedName = '__UNASSIGNED__';

  Database? _db;
  Database get db => _db!;

  Future<void> init() async {
    final root = await getDatabasesPath();
    _db = await openDatabase(
      join(root, 'dadafinanza.db'),
      version: databaseVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    await _ensureSystemRows();
  }

  Future<void> _create(Database db, int version) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.execute('''CREATE TABLE accounts(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      balance REAL NOT NULL DEFAULT 0,
      color INTEGER NOT NULL,
      icon_key TEXT NOT NULL DEFAULT 'wallet',
      account_type TEXT NOT NULL DEFAULT 'other',
      include_in_total INTEGER NOT NULL DEFAULT 1,
      include_in_analytics INTEGER NOT NULL DEFAULT 1,
      is_locked INTEGER NOT NULL DEFAULT 0,
      is_archived INTEGER NOT NULL DEFAULT 0,
      hide_balance INTEGER NOT NULL DEFAULT 0,
      is_system INTEGER NOT NULL DEFAULT 0,
      note TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )''');
    await db.execute('''CREATE TABLE categories(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      icon_key TEXT NOT NULL,
      color INTEGER NOT NULL,
      type TEXT NOT NULL,
      quick_order INTEGER
    )''');
    await db.execute('''CREATE TABLE transactions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      account_id INTEGER NOT NULL,
      to_account_id INTEGER,
      category_id INTEGER,
      date INTEGER NOT NULL,
      note TEXT,
      tags TEXT,
      receipt_path TEXT,
      include_in_analytics INTEGER NOT NULL DEFAULT 1,
      recurring_id INTEGER,
      refund_of_transaction_id INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY(account_id) REFERENCES accounts(id),
      FOREIGN KEY(to_account_id) REFERENCES accounts(id),
      FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE SET NULL,
      FOREIGN KEY(refund_of_transaction_id) REFERENCES transactions(id) ON DELETE SET NULL
    )''');
    await db.execute('''CREATE TABLE transaction_splits(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_id INTEGER NOT NULL,
      amount REAL NOT NULL,
      category_id INTEGER NOT NULL,
      note TEXT,
      FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
      FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE RESTRICT
    )''');
    await db.execute('''CREATE TABLE recurring(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      amount REAL NOT NULL,
      type TEXT NOT NULL,
      account_id INTEGER NOT NULL,
      category_id INTEGER,
      frequency TEXT NOT NULL,
      next_date INTEGER NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1,
      note TEXT,
      end_date INTEGER,
      auto_create INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY(account_id) REFERENCES accounts(id),
      FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE SET NULL
    )''');
    await db.execute('''CREATE TABLE budgets(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      category_id INTEGER,
      limit_amount REAL NOT NULL,
      period TEXT NOT NULL,
      start_date INTEGER NOT NULL,
      end_date INTEGER,
      enabled INTEGER NOT NULL DEFAULT 1,
      FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE SET NULL
    )''');
    await db.execute('''CREATE TABLE goals(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      icon_key TEXT NOT NULL,
      color INTEGER NOT NULL,
      target_amount REAL NOT NULL,
      current_amount REAL NOT NULL DEFAULT 0,
      target_date INTEGER,
      linked_account_id INTEGER,
      archived INTEGER NOT NULL DEFAULT 0,
      completed INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY(linked_account_id) REFERENCES accounts(id) ON DELETE SET NULL
    )''');
    await db.execute('''CREATE TABLE dashboard_widgets(
      type TEXT PRIMARY KEY,
      enabled INTEGER NOT NULL,
      order_index INTEGER NOT NULL,
      size TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE automation_rules(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1,
      contains_text TEXT,
      type TEXT,
      min_amount REAL,
      max_amount REAL,
      category_id INTEGER,
      account_id INTEGER,
      add_tag TEXT,
      include_in_analytics INTEGER,
      FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE SET NULL,
      FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE SET NULL
    )''');
    await db.execute('''CREATE TABLE net_worth_snapshots(
      date INTEGER PRIMARY KEY,
      amount REAL NOT NULL
    )''');
    await db.execute(
      'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    await _createSmartTables(db);

    final defaults = <String, String>{
      'monthly_budget': '0',
      'hide_balance': '0',
      'theme_mode': 'system',
      'currency': 'EUR',
      'show_cents': '1',
      'allow_unassigned': '1',
      'show_transfers_analytics': '0',
      'confirm_delete': '1',
      'haptics': '1',
      'week_start': '1',
      'financial_month_start': '1',
    };
    for (final entry in defaults.entries) {
      await db.insert('settings', {'key': entry.key, 'value': entry.value});
    }
    await _seedSmartSettings(db);

    await db.insert('accounts', {
      'name': _unassignedName,
      'balance': 0.0,
      'color': 0xFF8E8E93,
      'icon_key': 'help',
      'account_type': 'other',
      'include_in_total': 0,
      'include_in_analytics': 0,
      'is_system': 1,
      'created_at': now,
      'updated_at': now,
    });
    await _seedDashboard(db);
    await _createIndexes(db);
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _addColumnIfMissing(
        db,
        'accounts',
        'icon_key',
        "TEXT NOT NULL DEFAULT 'wallet'",
      );
      await _addColumnIfMissing(
        db,
        'accounts',
        'account_type',
        "TEXT NOT NULL DEFAULT 'other'",
      );
      await _addColumnIfMissing(
        db,
        'accounts',
        'include_in_analytics',
        'INTEGER NOT NULL DEFAULT 1',
      );
      await _addColumnIfMissing(
        db,
        'accounts',
        'is_locked',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        'accounts',
        'is_archived',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        'accounts',
        'hide_balance',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        'accounts',
        'is_system',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(db, 'accounts', 'note', 'TEXT');
      await _addColumnIfMissing(
        db,
        'accounts',
        'created_at',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        'accounts',
        'updated_at',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await db.update('accounts', {
        'created_at': now,
        'updated_at': now,
      }, where: 'created_at = 0 OR updated_at = 0');

      await _addColumnIfMissing(
        db,
        'transactions',
        'include_in_analytics',
        'INTEGER NOT NULL DEFAULT 1',
      );
      await _addColumnIfMissing(db, 'transactions', 'recurring_id', 'INTEGER');
      await _addColumnIfMissing(
        db,
        'transactions',
        'refund_of_transaction_id',
        'INTEGER',
      );
      await _addColumnIfMissing(
        db,
        'transactions',
        'created_at',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        'transactions',
        'updated_at',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await db.rawUpdate(
        'UPDATE transactions SET created_at = date WHERE created_at = 0',
      );
      await db.rawUpdate(
        'UPDATE transactions SET updated_at = date WHERE updated_at = 0',
      );

      await _addColumnIfMissing(db, 'recurring', 'note', 'TEXT');
      await _addColumnIfMissing(db, 'recurring', 'end_date', 'INTEGER');
      await _addColumnIfMissing(
        db,
        'recurring',
        'auto_create',
        'INTEGER NOT NULL DEFAULT 0',
      );

      await db.execute('''CREATE TABLE IF NOT EXISTS transaction_splits(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        category_id INTEGER NOT NULL,
        note TEXT
      )''');
      await db.execute('''CREATE TABLE IF NOT EXISTS budgets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category_id INTEGER,
        limit_amount REAL NOT NULL,
        period TEXT NOT NULL,
        start_date INTEGER NOT NULL,
        end_date INTEGER,
        enabled INTEGER NOT NULL DEFAULT 1
      )''');
      await db.execute('''CREATE TABLE IF NOT EXISTS goals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon_key TEXT NOT NULL,
        color INTEGER NOT NULL,
        target_amount REAL NOT NULL,
        current_amount REAL NOT NULL DEFAULT 0,
        target_date INTEGER,
        linked_account_id INTEGER,
        archived INTEGER NOT NULL DEFAULT 0,
        completed INTEGER NOT NULL DEFAULT 0
      )''');
      await db.execute('''CREATE TABLE IF NOT EXISTS dashboard_widgets(
        type TEXT PRIMARY KEY,
        enabled INTEGER NOT NULL,
        order_index INTEGER NOT NULL,
        size TEXT NOT NULL
      )''');
      await db.execute('''CREATE TABLE IF NOT EXISTS automation_rules(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        contains_text TEXT,
        type TEXT,
        min_amount REAL,
        max_amount REAL,
        category_id INTEGER,
        account_id INTEGER,
        add_tag TEXT,
        include_in_analytics INTEGER
      )''');
      await db.execute(
        'CREATE TABLE IF NOT EXISTS net_worth_snapshots(date INTEGER PRIMARY KEY, amount REAL NOT NULL)',
      );
      final legacyBudget = await db.query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['monthly_budget'],
        limit: 1,
      );
      final legacyValue = legacyBudget.isEmpty
          ? 0.0
          : double.tryParse(legacyBudget.first['value'] as String? ?? '') ??
                0.0;
      final budgetCount =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM budgets'),
          ) ??
          0;
      if (legacyValue > 0 && budgetCount == 0) {
        await db.insert('budgets', {
          'name': 'Budget mensile',
          'category_id': null,
          'limit_amount': legacyValue,
          'period': BudgetPeriod.monthly.name,
          'start_date': DateTime(
            DateTime.now().year,
            DateTime.now().month,
          ).millisecondsSinceEpoch,
          'end_date': null,
          'enabled': 1,
        });
      }
      await _seedDashboard(db);
    }
    if (oldVersion < 4) {
      await _createSmartTables(db);
      await _seedSmartSettings(db);
    }
    await _createIndexes(db);
  }

  Future<void> _createSmartTables(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS learned_patterns(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      signature TEXT NOT NULL UNIQUE,
      normalized_text TEXT NOT NULL,
      type TEXT NOT NULL,
      category_id INTEGER,
      account_id INTEGER,
      to_account_id INTEGER,
      tags TEXT,
      sample_count INTEGER NOT NULL DEFAULT 0,
      accepted_count INTEGER NOT NULL DEFAULT 0,
      rejected_count INTEGER NOT NULL DEFAULT 0,
      amount_median REAL NOT NULL DEFAULT 0,
      amount_min REAL NOT NULL DEFAULT 0,
      amount_max REAL NOT NULL DEFAULT 0,
      weekday_mask INTEGER NOT NULL DEFAULT 0,
      hour_bucket INTEGER NOT NULL DEFAULT -1,
      first_seen INTEGER NOT NULL,
      last_seen INTEGER NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS pattern_feedback(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      pattern_id INTEGER,
      kind TEXT NOT NULL,
      query_text TEXT,
      created_at INTEGER NOT NULL,
      FOREIGN KEY(pattern_id) REFERENCES learned_patterns(id) ON DELETE SET NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS suggestion_suppressions(
      normalized_text TEXT PRIMARY KEY,
      created_at INTEGER NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS detected_recurring_patterns(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      signature TEXT NOT NULL UNIQUE,
      normalized_text TEXT NOT NULL,
      type TEXT NOT NULL,
      category_id INTEGER,
      account_id INTEGER,
      frequency TEXT NOT NULL,
      amount_median REAL NOT NULL,
      confidence REAL NOT NULL,
      sample_count INTEGER NOT NULL,
      last_seen INTEGER NOT NULL,
      next_expected INTEGER NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )''');
  }

  Future<void> _seedSmartSettings(Database db) async {
    const defaults = <String, String>{
      'smart_suggestions_enabled': '1',
      'smart_use_description': '1',
      'smart_use_amount': '1',
      'smart_use_time': '1',
      'smart_detect_recurring': '1',
      'smart_goal_suggestions': '1',
      'smart_sensitivity': 'balanced',
    };
    for (final entry in defaults.entries) {
      await db.insert('settings', {
        'key': entry.key,
        'value': entry.value,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (!columns.any((row) => row['name'] == column)) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_account ON transactions(account_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_to_account ON transactions(to_account_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_splits_transaction ON transaction_splits(transaction_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_patterns_text_type ON learned_patterns(normalized_text, type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_patterns_last_seen ON learned_patterns(last_seen)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_feedback_pattern ON pattern_feedback(pattern_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_detected_next ON detected_recurring_patterns(next_expected)',
    );
  }

  Future<void> _seedDashboard(Database db) async {
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM dashboard_widgets'),
        ) ??
        0;
    if (count > 0) return;
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
    for (var i = 0; i < DashboardWidgetType.values.length; i++) {
      final type = DashboardWidgetType.values[i];
      final order = defaults.indexOf(type);
      await db.insert('dashboard_widgets', {
        'type': type.name,
        'enabled': order >= 0 ? 1 : 0,
        'order_index': order >= 0 ? order : defaults.length + i,
        'size': DashboardWidgetSize.medium.name,
      });
    }
  }

  Future<void> _ensureSystemRows() async {
    final rows = await db.query(
      'accounts',
      where: 'name = ? AND is_system = 1',
      whereArgs: [_unassignedName],
    );
    if (rows.isEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('accounts', {
        'name': _unassignedName,
        'balance': 0.0,
        'color': 0xFF8E8E93,
        'icon_key': 'help',
        'account_type': 'other',
        'include_in_total': 0,
        'include_in_analytics': 0,
        'is_system': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
    await _seedDashboard(db);
    await _createSmartTables(db);
    await _seedSmartSettings(db);
    await _createIndexes(db);
  }

  Future<List<Account>> accounts() async => (await db.query(
    'accounts',
    orderBy: 'is_system, is_archived, id',
  )).map(Account.fromMap).toList();
  Future<List<Category>> categories() async => (await db.query(
    'categories',
    orderBy: 'type, CASE WHEN quick_order IS NULL THEN 999 ELSE quick_order END, name',
  )).map(Category.fromMap).toList();
  Future<List<FinanceTransaction>> transactions() async => (await db.query(
    'transactions',
    orderBy: 'date DESC, id DESC',
  )).map(FinanceTransaction.fromMap).toList();
  Future<List<TransactionSplit>> splits() async => (await db.query(
    'transaction_splits',
    orderBy: 'id',
  )).map(TransactionSplit.fromMap).toList();
  Future<List<RecurringPayment>> recurring() async => (await db.query(
    'recurring',
    orderBy: 'next_date ASC',
  )).map(RecurringPayment.fromMap).toList();
  Future<List<Budget>> budgets() async => (await db.query(
    'budgets',
    orderBy: 'enabled DESC, id DESC',
  )).map(Budget.fromMap).toList();
  Future<List<Goal>> goals() async => (await db.query(
    'goals',
    orderBy: 'completed, archived, id DESC',
  )).map(Goal.fromMap).toList();
  Future<List<DashboardWidgetConfig>> dashboardWidgets() async =>
      (await db.query(
        'dashboard_widgets',
        orderBy: 'order_index',
      )).map(DashboardWidgetConfig.fromMap).toList();
  Future<List<AutomationRule>> rules() async => (await db.query(
    'automation_rules',
    orderBy: 'id DESC',
  )).map(AutomationRule.fromMap).toList();
  Future<List<LearnedPattern>> learnedPatterns() async => (await db.query(
    'learned_patterns',
    orderBy: 'last_seen DESC, sample_count DESC',
  )).map(LearnedPattern.fromMap).toList();
  Future<List<DetectedRecurringPattern>> detectedRecurringPatterns() async =>
      (await db.query(
        'detected_recurring_patterns',
        orderBy: 'confidence DESC, next_expected ASC',
      )).map(DetectedRecurringPattern.fromMap).toList();
  Future<Set<String>> suppressedSuggestionTexts() async => (await db.query(
    'suggestion_suppressions',
    columns: ['normalized_text'],
  )).map((row) => row['normalized_text'] as String).toSet();

  Future<int> unassignedAccountId() async {
    final rows = await db.query(
      'accounts',
      columns: ['id'],
      where: 'name = ? AND is_system = 1',
      whereArgs: [_unassignedName],
      limit: 1,
    );
    return rows.first['id'] as int;
  }

  Future<int> addAccount({
    required String name,
    required double balance,
    required int colorValue,
    required String iconKey,
    required AccountType type,
    required bool includeInTotal,
    required bool includeInAnalytics,
    required bool hideBalance,
    String? note,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.insert('accounts', {
      'name': name,
      'balance': balance,
      'color': colorValue,
      'icon_key': iconKey,
      'account_type': type.name,
      'include_in_total': includeInTotal ? 1 : 0,
      'include_in_analytics': includeInAnalytics ? 1 : 0,
      'hide_balance': hideBalance ? 1 : 0,
      'note': note,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> updateAccount(Account account) async {
    await db.update(
      'accounts',
      {
        'name': account.name,
        'balance': account.balance,
        'color': account.colorValue,
        'icon_key': account.iconKey,
        'account_type': account.accountType.name,
        'include_in_total': account.includeInTotal ? 1 : 0,
        'include_in_analytics': account.includeInAnalytics ? 1 : 0,
        'is_locked': account.isLocked ? 1 : 0,
        'is_archived': account.isArchived ? 1 : 0,
        'hide_balance': account.hideBalance ? 1 : 0,
        'note': account.note,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND is_system = 0',
      whereArgs: [account.id],
    );
  }

  Future<void> deleteAccount(int id) async {
    await db.transaction((txn) async {
      final accountRows = await txn.query(
        'accounts',
        where: 'id = ? AND is_system = 0',
        whereArgs: [id],
      );
      if (accountRows.isEmpty) return;
      final linkedRows = await txn.query(
        'transactions',
        where: 'account_id = ? OR to_account_id = ?',
        whereArgs: [id, id],
        orderBy: 'date DESC, id DESC',
      );
      final hasAdvanceHistory = linkedRows.any((row) {
        final kind = (row['kind'] as String?) ?? 'normal';
        return kind == 'advance_origin' ||
            kind == 'mixed_advance' ||
            kind == 'advance_settlement' ||
            kind == 'advance_writeoff' ||
            kind == 'advance_forgiven_income';
      });
      if (hasAdvanceHistory) {
        throw StateError(
          'Questo conto contiene movimenti collegati ad Anticipi. Archivialo invece di eliminarlo per conservare lo storico.',
        );
      }
      for (final row in linkedRows) {
        await _applyBalance(
          txn,
          FinanceTransaction.fromMap(row),
          -1,
          validateAccounts: false,
        );
      }
      await txn.delete(
        'transaction_splits',
        where: 'transaction_id IN (SELECT id FROM transactions WHERE account_id = ? OR to_account_id = ?)',
        whereArgs: [id, id],
      );
      await txn.delete(
        'transactions',
        where: 'account_id = ? OR to_account_id = ?',
        whereArgs: [id, id],
      );
      await txn.delete('recurring', where: 'account_id = ?', whereArgs: [id]);
      await txn.update(
        'goals',
        {'linked_account_id': null},
        where: 'linked_account_id = ?',
        whereArgs: [id],
      );
      await txn.delete('accounts', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> addCategory({
    required String name,
    required TransactionType type,
    required String iconKey,
    required int colorValue,
  }) async {
    final quickCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM categories WHERE type = ? AND quick_order IS NOT NULL',
            [type.dbValue],
          ),
        ) ??
        0;
    return db.insert('categories', {
      'name': name,
      'type': type.dbValue,
      'icon_key': iconKey,
      'color': colorValue,
      'quick_order': type == TransactionType.expense && quickCount < 4
          ? quickCount
          : null,
    });
  }

  Future<void> updateCategory(Category category) async => db.update(
    'categories',
    {
      'name': category.name,
      'icon_key': category.iconKey,
      'color': category.colorValue,
      'type': category.type.dbValue,
      'quick_order': category.quickOrder,
    },
    where: 'id = ?',
    whereArgs: [category.id],
  );

  Future<void> deleteCategory(int id) async {
    await db.transaction((txn) async {
      await txn.update(
        'transactions',
        {'category_id': null},
        where: 'category_id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'recurring',
        {'category_id': null},
        where: 'category_id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'budgets',
        {'category_id': null},
        where: 'category_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'transaction_splits',
        where: 'category_id = ?',
        whereArgs: [id],
      );
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
  }

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
    int? recurringId,
    int? refundOfTransactionId,
  }) async {
    final item = await _applyRules(
      FinanceTransaction(
        id: 0,
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
        recurringId: recurringId,
        refundOfTransactionId: refundOfTransactionId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return db.transaction((txn) async {
      await _validateAccount(txn, item.accountId);
      if (item.type == TransactionType.transfer) {
        if (item.toAccountId == null || item.toAccountId == item.accountId)
          throw StateError('Il trasferimento richiede due conti diversi.');
        await _validateAccount(txn, item.toAccountId!);
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = await txn.insert('transactions', _transactionMap(item, now));
      await _applyBalance(txn, item, 1);
      return id;
    });
  }

  Future<void> updateTransaction(
    FinanceTransaction oldItem,
    FinanceTransaction newItem,
  ) async {
    await db.transaction((txn) async {
      await _validateAccount(txn, newItem.accountId);
      if (newItem.type == TransactionType.transfer) {
        if (newItem.toAccountId == null ||
            newItem.toAccountId == newItem.accountId)
          throw StateError('Il trasferimento richiede due conti diversi.');
        await _validateAccount(txn, newItem.toAccountId!);
      }
      await _applyBalance(txn, oldItem, -1, validateAccounts: false);
      await txn.update(
        'transactions',
        _transactionMap(
          newItem,
          DateTime.now().millisecondsSinceEpoch,
          preserveCreatedAt: true,
        ),
        where: 'id = ?',
        whereArgs: [oldItem.id],
      );
      await _applyBalance(txn, newItem, 1);
    });
  }

  Future<int> duplicateTransaction(FinanceTransaction item) => addTransaction(
    type: item.type,
    amount: item.amount,
    accountId: item.accountId,
    toAccountId: item.toAccountId,
    categoryId: item.categoryId,
    date: DateTime.now(),
    note: item.note,
    tags: item.tags,
    receiptPath: item.receiptPath,
    includeInAnalytics: item.includeInAnalytics,
    refundOfTransactionId: item.refundOfTransactionId,
  );

  Future<void> deleteTransaction(FinanceTransaction item) async {
    await db.transaction((txn) async {
      await _applyBalance(txn, item, -1, validateAccounts: false);
      await txn.delete(
        'transaction_splits',
        where: 'transaction_id = ?',
        whereArgs: [item.id],
      );
      await txn.update(
        'transactions',
        {'refund_of_transaction_id': null},
        where: 'refund_of_transaction_id = ?',
        whereArgs: [item.id],
      );
      await txn.delete('transactions', where: 'id = ?', whereArgs: [item.id]);
    });
  }

  Map<String, Object?> _transactionMap(
    FinanceTransaction item,
    int now, {
    bool preserveCreatedAt = false,
  }) => {
    'type': item.type.dbValue,
    'amount': item.amount,
    'account_id': item.accountId,
    'to_account_id': item.type == TransactionType.transfer
        ? item.toAccountId
        : null,
    'category_id': item.type == TransactionType.transfer
        ? null
        : item.categoryId,
    'date': item.date.millisecondsSinceEpoch,
    'note': item.note,
    'tags': item.tags.join('|'),
    'receipt_path': item.receiptPath,
    'include_in_analytics': item.includeInAnalytics ? 1 : 0,
    'recurring_id': item.recurringId,
    'refund_of_transaction_id': item.refundOfTransactionId,
    'kind': item.kind,
    'created_at': preserveCreatedAt
        ? item.createdAt.millisecondsSinceEpoch
        : now,
    'updated_at': now,
  };

  Future<void> _validateAccount(Transaction txn, int id) async {
    final rows = await txn.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Conto non trovato.');
    final account = Account.fromMap(rows.first);
    if (!account.isSystem && account.isLocked)
      throw StateError('Il conto “${account.name}” è bloccato.');
    if (!account.isSystem && account.isArchived)
      throw StateError('Il conto “${account.name}” è archiviato.');
  }

  Future<void> _applyBalance(
    Transaction txn,
    FinanceTransaction item,
    int direction, {
    bool validateAccounts = true,
  }) async {
    if (item.kind == 'advance_writeoff' ||
        item.kind == 'advance_forgiven_income') {
      return;
    }
    if (validateAccounts) await _validateAccount(txn, item.accountId);
    switch (item.type) {
      case TransactionType.expense:
        await _increment(txn, item.accountId, -item.amount * direction);
        break;
      case TransactionType.income:
        await _increment(txn, item.accountId, item.amount * direction);
        break;
      case TransactionType.transfer:
        await _increment(txn, item.accountId, -item.amount * direction);
        if (item.toAccountId != null)
          await _increment(txn, item.toAccountId!, item.amount * direction);
        break;
    }
  }

  Future<void> _increment(Transaction txn, int id, double delta) async {
    await txn.rawUpdate(
      'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
      [delta, DateTime.now().millisecondsSinceEpoch, id],
    );
  }

  Future<FinanceTransaction> _applyRules(FinanceTransaction item) async {
    var result = item;
    for (final rule in await rules()) {
      if (!rule.enabled) continue;
      if (rule.type != null && rule.type != result.type) continue;
      if (rule.minAmount != null && result.amount < rule.minAmount!) continue;
      if (rule.maxAmount != null && result.amount > rule.maxAmount!) continue;
      final haystack = (result.note ?? '').toLowerCase();
      if (rule.containsText?.isNotEmpty == true &&
          !haystack.contains(rule.containsText!.toLowerCase()))
        continue;
      result = result.copyWith(
        categoryId: rule.categoryId ?? result.categoryId,
        accountId: rule.accountId ?? result.accountId,
        tags: rule.addTag == null || result.tags.contains(rule.addTag)
            ? result.tags
            : [...result.tags, rule.addTag!],
        includeInAnalytics:
            rule.includeInAnalytics ?? result.includeInAnalytics,
      );
    }
    return result;
  }

  Future<void> replaceSplits(
    int transactionId,
    List<TransactionSplit> items,
    double transactionAmount,
  ) async {
    final total = items.fold<double>(0, (sum, item) => sum + item.amount);
    if (items.isNotEmpty && (total - transactionAmount).abs() > .005)
      throw StateError(
        'La somma delle divisioni deve coincidere con il totale.',
      );
    await db.transaction((txn) async {
      await txn.delete(
        'transaction_splits',
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );
      for (final item in items) {
        await txn.insert('transaction_splits', {
          'transaction_id': transactionId,
          'amount': item.amount,
          'category_id': item.categoryId,
          'note': item.note,
        });
      }
    });
  }

  Future<int> addRecurring({
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
  }) => db.insert('recurring', {
    'name': name,
    'amount': amount,
    'type': type.dbValue,
    'account_id': accountId,
    'category_id': categoryId,
    'frequency': frequency,
    'next_date': nextDate.millisecondsSinceEpoch,
    'enabled': 1,
    'note': note,
    'end_date': endDate?.millisecondsSinceEpoch,
    'auto_create': autoCreate ? 1 : 0,
  });

  Future<void> updateRecurring(RecurringPayment item) => db.update(
    'recurring',
    {
      'name': item.name,
      'amount': item.amount,
      'type': item.type.dbValue,
      'account_id': item.accountId,
      'category_id': item.categoryId,
      'frequency': item.frequency,
      'next_date': item.nextDate.millisecondsSinceEpoch,
      'enabled': item.enabled ? 1 : 0,
      'note': item.note,
      'end_date': item.endDate?.millisecondsSinceEpoch,
      'auto_create': item.autoCreate ? 1 : 0,
    },
    where: 'id = ?',
    whereArgs: [item.id],
  );
  Future<void> deleteRecurring(int id) =>
      db.delete('recurring', where: 'id = ?', whereArgs: [id]);

  Future<int> addBudget({
    required String name,
    int? categoryId,
    required double limit,
    required BudgetPeriod period,
    required DateTime startDate,
    DateTime? endDate,
  }) => db.insert('budgets', {
    'name': name,
    'category_id': categoryId,
    'limit_amount': limit,
    'period': period.name,
    'start_date': startDate.millisecondsSinceEpoch,
    'end_date': endDate?.millisecondsSinceEpoch,
    'enabled': 1,
  });
  Future<void> updateBudget(Budget item) => db.update(
    'budgets',
    {
      'name': item.name,
      'category_id': item.categoryId,
      'limit_amount': item.limit,
      'period': item.period.name,
      'start_date': item.startDate.millisecondsSinceEpoch,
      'end_date': item.endDate?.millisecondsSinceEpoch,
      'enabled': item.enabled ? 1 : 0,
    },
    where: 'id = ?',
    whereArgs: [item.id],
  );
  Future<void> deleteBudget(int id) =>
      db.delete('budgets', where: 'id = ?', whereArgs: [id]);

  Future<int> addGoal({
    required String name,
    required String iconKey,
    required int colorValue,
    required double targetAmount,
    DateTime? targetDate,
    int? linkedAccountId,
  }) => db.insert('goals', {
    'name': name,
    'icon_key': iconKey,
    'color': colorValue,
    'target_amount': targetAmount,
    'current_amount': 0.0,
    'target_date': targetDate?.millisecondsSinceEpoch,
    'linked_account_id': linkedAccountId,
    'archived': 0,
    'completed': 0,
  });
  Future<void> updateGoal(Goal item) => db.update(
    'goals',
    {
      'name': item.name,
      'icon_key': item.iconKey,
      'color': item.colorValue,
      'target_amount': item.targetAmount,
      'current_amount': item.currentAmount,
      'target_date': item.targetDate?.millisecondsSinceEpoch,
      'linked_account_id': item.linkedAccountId,
      'archived': item.archived ? 1 : 0,
      'completed': item.completed ? 1 : 0,
    },
    where: 'id = ?',
    whereArgs: [item.id],
  );
  Future<void> deleteGoal(int id) =>
      db.delete('goals', where: 'id = ?', whereArgs: [id]);

  Future<void> saveDashboardWidgets(List<DashboardWidgetConfig> items) async {
    await db.transaction((txn) async {
      for (final item in items) {
        await txn.insert('dashboard_widgets', {
          'type': item.type.name,
          'enabled': item.enabled ? 1 : 0,
          'order_index': item.orderIndex,
          'size': item.size.name,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<int> addRule(AutomationRule rule) => db.insert('automation_rules', {
    'name': rule.name,
    'enabled': rule.enabled ? 1 : 0,
    'contains_text': rule.containsText,
    'type': rule.type?.dbValue,
    'min_amount': rule.minAmount,
    'max_amount': rule.maxAmount,
    'category_id': rule.categoryId,
    'account_id': rule.accountId,
    'add_tag': rule.addTag,
    'include_in_analytics': rule.includeInAnalytics == null
        ? null
        : (rule.includeInAnalytics! ? 1 : 0),
  });
  Future<void> deleteRule(int id) =>
      db.delete('automation_rules', where: 'id = ?', whereArgs: [id]);

  Future<void> replaceLearnedPatterns(List<LearnedPattern> patterns) async {
    await db.transaction((txn) async {
      final signatures = patterns.map((item) => item.signature).toSet();
      final existingRows = await txn.query('learned_patterns');
      final existing = <String, Map<String, Object?>>{
        for (final row in existingRows) row['signature'] as String: row,
      };
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final pattern in patterns) {
        final old = existing[pattern.signature];
        final values = <String, Object?>{
          'signature': pattern.signature,
          'normalized_text': pattern.normalizedText,
          'type': pattern.type.name,
          'category_id': pattern.categoryId,
          'account_id': pattern.accountId,
          'to_account_id': pattern.toAccountId,
          'tags': pattern.tags.join('|'),
          'sample_count': pattern.sampleCount,
          'accepted_count': old?['accepted_count'] ?? pattern.acceptedCount,
          'rejected_count': old?['rejected_count'] ?? pattern.rejectedCount,
          'amount_median': pattern.amountMedian,
          'amount_min': pattern.amountMin,
          'amount_max': pattern.amountMax,
          'weekday_mask': pattern.weekdayMask,
          'hour_bucket': pattern.hourBucket,
          'first_seen': pattern.firstSeen.millisecondsSinceEpoch,
          'last_seen': pattern.lastSeen.millisecondsSinceEpoch,
          'enabled': old?['enabled'] ?? (pattern.enabled ? 1 : 0),
          'updated_at': now,
        };
        if (old == null) {
          values['created_at'] = now;
          await txn.insert('learned_patterns', values);
        } else {
          await txn.update(
            'learned_patterns',
            values,
            where: 'signature = ?',
            whereArgs: [pattern.signature],
          );
        }
      }
      for (final row in existingRows) {
        final signature = row['signature'] as String;
        if (!signatures.contains(signature)) {
          await txn.delete(
            'learned_patterns',
            where: 'signature = ?',
            whereArgs: [signature],
          );
        }
      }
    });
  }

  Future<void> replaceDetectedRecurringPatterns(
    List<DetectedRecurringPattern> patterns,
  ) async {
    await db.transaction((txn) async {
      final oldRows = await txn.query('detected_recurring_patterns');
      final old = <String, Map<String, Object?>>{
        for (final row in oldRows) row['signature'] as String: row,
      };
      final signatures = patterns.map((item) => item.signature).toSet();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final pattern in patterns) {
        final previous = old[pattern.signature];
        final values = <String, Object?>{
          'signature': pattern.signature,
          'normalized_text': pattern.normalizedText,
          'type': pattern.type.name,
          'category_id': pattern.categoryId,
          'account_id': pattern.accountId,
          'frequency': pattern.frequency,
          'amount_median': pattern.amountMedian,
          'confidence': pattern.confidence,
          'sample_count': pattern.sampleCount,
          'last_seen': pattern.lastSeen.millisecondsSinceEpoch,
          'next_expected': pattern.nextExpected.millisecondsSinceEpoch,
          'enabled': previous?['enabled'] ?? (pattern.enabled ? 1 : 0),
          'updated_at': now,
        };
        if (previous == null) {
          values['created_at'] = now;
          await txn.insert('detected_recurring_patterns', values);
        } else {
          await txn.update(
            'detected_recurring_patterns',
            values,
            where: 'signature = ?',
            whereArgs: [pattern.signature],
          );
        }
      }
      for (final row in oldRows) {
        final signature = row['signature'] as String;
        if (!signatures.contains(signature)) {
          await txn.delete(
            'detected_recurring_patterns',
            where: 'signature = ?',
            whereArgs: [signature],
          );
        }
      }
    });
  }

  Future<void> recordPatternFeedback(
    int? patternId,
    String kind,
    String queryText,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.insert('pattern_feedback', {
        'pattern_id': patternId,
        'kind': kind,
        'query_text': queryText,
        'created_at': now,
      });
      if (patternId != null) {
        if (kind == 'accepted') {
          await txn.rawUpdate(
            'UPDATE learned_patterns SET accepted_count = accepted_count + 1, updated_at = ? WHERE id = ?',
            [now, patternId],
          );
        } else if (kind == 'rejected' || kind == 'modified') {
          await txn.rawUpdate(
            'UPDATE learned_patterns SET rejected_count = rejected_count + 1, updated_at = ? WHERE id = ?',
            [now, patternId],
          );
        }
      }
    });
  }

  Future<void> suppressSuggestion(String normalizedText) =>
      db.insert('suggestion_suppressions', {
        'normalized_text': normalizedText,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> setPatternEnabled(int id, bool enabled) => db.update(
    'learned_patterns',
    {
      'enabled': enabled ? 1 : 0,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    },
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> deletePattern(int id) =>
      db.delete('learned_patterns', where: 'id = ?', whereArgs: [id]);

  Future<void> clearLearning() async {
    await db.transaction((txn) async {
      await txn.delete('pattern_feedback');
      await txn.delete('suggestion_suppressions');
      await txn.delete('detected_recurring_patterns');
      await txn.delete('learned_patterns');
    });
  }

  Future<String?> getSetting(String key) async {
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) => db.insert('settings', {
    'key': key,
    'value': value,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> snapshotNetWorth(double amount) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    await db.insert('net_worth_snapshots', {
      'date': day,
      'amount': amount,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> netWorthSnapshots() =>
      db.query('net_worth_snapshots', orderBy: 'date ASC');

  Future<void> clearAllUserData() async {
    await db.transaction((txn) async {
      await txn.delete('pattern_feedback');
      await txn.delete('suggestion_suppressions');
      await txn.delete('detected_recurring_patterns');
      await txn.delete('learned_patterns');
      await txn.delete('transaction_splits');
      await txn.delete('advance_settlements');
      await txn.delete('advances');
      await txn.delete('finance_people');
      await txn.delete('transactions');
      await txn.delete('recurring');
      await txn.delete('budgets');
      await txn.delete('goals');
      await txn.delete('automation_rules');
      await txn.delete('categories');
      await txn.delete('net_worth_snapshots');
      await txn.delete('accounts', where: 'is_system = 0');
      await txn.update('accounts', {'balance': 0.0}, where: 'is_system = 1');
    });
  }

  Future<String> databaseFilePath() async =>
      join(await getDatabasesPath(), 'dadafinanza.db');

  Future<void> restoreDatabaseFrom(String sourcePath) async {
    await _db?.close();
    _db = null;
    final destination = await databaseFilePath();
    await File(sourcePath).copy(destination);
    await init();
  }

  Future<String> exportTransactionsCsv() async {
    final buffer = StringBuffer(
      'id,type,amount,account_id,to_account_id,category_id,date,note,tags,include_in_analytics\n',
    );
    for (final t in await transactions()) {
      String q(String? value) => '"${(value ?? '').replaceAll('"', '""')}"';
      buffer.writeln(
        '${t.id},${t.type.name},${t.amount},${t.accountId},${t.toAccountId ?? ''},${t.categoryId ?? ''},${t.date.toIso8601String()},${q(t.note)},${q(t.tags.join('|'))},${t.includeInAnalytics ? 1 : 0}',
      );
    }
    return buffer.toString();
  }
}

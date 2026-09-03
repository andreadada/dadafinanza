import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

class AppDatabase {
  Database? _db;

  Database get db => _db!;

  Future<void> init() async {
    final root = await getDatabasesPath();
    _db = await openDatabase(
      join(root, 'dadafinanza.db'),
      version: 2,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        balance REAL NOT NULL,
        color INTEGER NOT NULL,
        include_in_total INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon_key TEXT NOT NULL,
        color INTEGER NOT NULL,
        type TEXT NOT NULL,
        quick_order INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        account_id INTEGER NOT NULL,
        to_account_id INTEGER,
        category_id INTEGER,
        date INTEGER NOT NULL,
        note TEXT,
        tags TEXT,
        receipt_path TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE recurring(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        category_id INTEGER,
        frequency TEXT NOT NULL,
        next_date INTEGER NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.insert('settings', {'key': 'monthly_budget', 'value': '0'});
    await db.insert('settings', {'key': 'hide_balance', 'value': '0'});
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.transaction((txn) async {
        await txn.delete('recurring');
        await txn.delete('transactions');
        await txn.delete('categories');
        await txn.delete('accounts');
        await txn.insert(
          'settings',
          {'key': 'monthly_budget', 'value': '0'},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert(
          'settings',
          {'key': 'hide_balance', 'value': '0'},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
    }
  }

  Future<List<Account>> accounts() async =>
      (await db.query('accounts', orderBy: 'id')).map(Account.fromMap).toList();

  Future<List<Category>> categories() async => (await db.query(
        'categories',
        orderBy:
            'type, CASE WHEN quick_order IS NULL THEN 999 ELSE quick_order END, name',
      ))
          .map(Category.fromMap)
          .toList();

  Future<List<FinanceTransaction>> transactions() async => (await db.query(
        'transactions',
        orderBy: 'date DESC, id DESC',
      ))
          .map(FinanceTransaction.fromMap)
          .toList();

  Future<List<RecurringPayment>> recurring() async => (await db.query(
        'recurring',
        orderBy: 'next_date ASC',
      ))
          .map(RecurringPayment.fromMap)
          .toList();

  Future<int> addAccount(String name, double balance, int colorValue) async =>
      db.insert('accounts', {
        'name': name,
        'balance': balance,
        'color': colorValue,
        'include_in_total': 1,
      });

  Future<void> setAccountIncluded(int id, bool include) async {
    await db.update(
      'accounts',
      {'include_in_total': include ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> addCategory({
    required String name,
    required TransactionType type,
    required String iconKey,
    required int colorValue,
  }) async =>
      db.insert('categories', {
        'name': name,
        'type': type.dbValue,
        'icon_key': iconKey,
        'color': colorValue,
      });

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
  }) async {
    return db.transaction((txn) async {
      final id = await txn.insert('transactions', {
        'type': type.dbValue,
        'amount': amount,
        'account_id': accountId,
        'to_account_id': toAccountId,
        'category_id': categoryId,
        'date': date.millisecondsSinceEpoch,
        'note': note,
        'tags': tags.join('|'),
        'receipt_path': receiptPath,
      });
      await _applyBalance(txn, type, amount, accountId, toAccountId, 1);
      return id;
    });
  }

  Future<void> deleteTransaction(FinanceTransaction item) async {
    await db.transaction((txn) async {
      await _applyBalance(
        txn,
        item.type,
        item.amount,
        item.accountId,
        item.toAccountId,
        -1,
      );
      await txn.delete('transactions', where: 'id = ?', whereArgs: [item.id]);
    });
  }

  Future<void> _applyBalance(
    Transaction txn,
    TransactionType type,
    double amount,
    int accountId,
    int? toAccountId,
    int direction,
  ) async {
    switch (type) {
      case TransactionType.expense:
        await _increment(txn, accountId, -amount * direction);
        break;
      case TransactionType.income:
        await _increment(txn, accountId, amount * direction);
        break;
      case TransactionType.transfer:
        await _increment(txn, accountId, -amount * direction);
        if (toAccountId != null) {
          await _increment(txn, toAccountId, amount * direction);
        }
        break;
    }
  }

  Future<void> _increment(Transaction txn, int id, double delta) async {
    await txn.rawUpdate(
      'UPDATE accounts SET balance = balance + ? WHERE id = ?',
      [delta, id],
    );
  }

  Future<int> addRecurring({
    required String name,
    required double amount,
    required TransactionType type,
    required int accountId,
    int? categoryId,
    required String frequency,
    required DateTime nextDate,
  }) async =>
      db.insert('recurring', {
        'name': name,
        'amount': amount,
        'type': type.dbValue,
        'account_id': accountId,
        'category_id': categoryId,
        'frequency': frequency,
        'next_date': nextDate.millisecondsSinceEpoch,
        'enabled': 1,
      });

  Future<void> setRecurringEnabled(int id, bool enabled) async {
    await db.update(
      'recurring',
      {'enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<double> getMonthlyBudget() async {
    final rows =
        await db.query('settings', where: 'key = ?', whereArgs: ['monthly_budget']);
    return double.tryParse(rows.firstOrNull?['value'] as String? ?? '') ?? 0;
  }

  Future<bool> getHideBalance() async {
    final rows =
        await db.query('settings', where: 'key = ?', whereArgs: ['hide_balance']);
    return (rows.firstOrNull?['value'] as String? ?? '0') == '1';
  }

  Future<void> setSetting(String key, String value) async {
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

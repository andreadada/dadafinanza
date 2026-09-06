import 'dart:io';

import 'package:dadafinanza/data/app_database.dart';
import 'package:dadafinanza/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

void main() {
  late Directory databaseRoot;

  setUpAll(() async {
    ffi.sqfliteFfiInit();
    databaseFactory = ffi.databaseFactoryFfi;
    databaseRoot = await Directory.systemTemp.createTemp(
      'dadafinanza-schema-db-',
    );
    await databaseFactory.setDatabasesPath(databaseRoot.path);
  });

  tearDownAll(() async {
    if (await databaseRoot.exists()) {
      await databaseRoot.delete(recursive: true);
    }
  });

  Future<void> resetDatabase() async {
    final root = await getDatabasesPath();
    await databaseFactory.deleteDatabase(p.join(root, 'dadafinanza.db'));
  }

  test('fresh database includes transaction kind', () async {
    await resetDatabase();
    final database = AppDatabase();
    await database.init();
    addTearDown(() async {
      if (database.db.isOpen) await database.db.close();
    });

    expect(AppDatabase.databaseVersion, 5);
    final columns = await database.db.rawQuery(
      'PRAGMA table_info(transactions)',
    );
    expect(columns.map((row) => row['name']), contains('kind'));

    final accountId = await database.addAccount(
      name: 'Test',
      balance: 20,
      colorValue: 0xFF8E8E93,
      iconKey: 'wallet',
      type: AccountType.cash,
      includeInTotal: true,
      includeInAnalytics: true,
      hideBalance: false,
    );
    await database.addTransaction(
      type: TransactionType.expense,
      amount: 2,
      accountId: accountId,
      date: DateTime.utc(2026, 9, 6),
    );
    final rows = await database.db.query('transactions', columns: ['kind']);
    expect(rows.single['kind'], 'normal');
  });

  test('version 4 database upgrades kind without losing movements', () async {
    await resetDatabase();
    final original = AppDatabase();
    await original.init();
    final accountId = await original.addAccount(
      name: 'Legacy',
      balance: 50,
      colorValue: 0xFF8E8E93,
      iconKey: 'wallet',
      type: AccountType.cash,
      includeInTotal: true,
      includeInAnalytics: true,
      hideBalance: false,
    );
    await original.addTransaction(
      type: TransactionType.expense,
      amount: 7.5,
      accountId: accountId,
      date: DateTime.utc(2026, 9, 5),
      note: 'legacy movement',
    );
    final path = await original.databaseFilePath();
    await original.db.close();

    final legacy = await databaseFactory.openDatabase(path);
    await legacy.execute('ALTER TABLE transactions DROP COLUMN kind');
    await legacy.execute('PRAGMA user_version = 4');
    await legacy.close();

    final upgraded = AppDatabase();
    await upgraded.init();
    addTearDown(() async {
      if (upgraded.db.isOpen) await upgraded.db.close();
    });

    final columns = await upgraded.db.rawQuery(
      'PRAGMA table_info(transactions)',
    );
    expect(columns.map((row) => row['name']), contains('kind'));
    final movements = await upgraded.transactions();
    expect(movements, hasLength(1));
    expect(movements.single.note, 'legacy movement');
    expect(movements.single.kind, 'normal');
  });
}

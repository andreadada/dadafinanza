import 'dart:io';

import 'package:dadafinanza/app_state.dart';
import 'package:dadafinanza/data/app_database.dart';
import 'package:dadafinanza/models/models.dart';
import 'package:dadafinanza/services/csv_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

void main() {
  late Directory databaseRoot;
  late AppDatabase database;

  setUpAll(() async {
    ffi.sqfliteFfiInit();
    databaseFactory = ffi.databaseFactoryFfi;
    databaseRoot = await Directory.systemTemp.createTemp('dadafinanza-csv-db-');
    await databaseFactory.setDatabasesPath(databaseRoot.path);
  });

  tearDownAll(() async {
    if (await databaseRoot.exists()) await databaseRoot.delete(recursive: true);
  });

  setUp(() async {
    final root = await getDatabasesPath();
    await databaseFactory.deleteDatabase(p.join(root, 'dadafinanza.db'));
    database = AppDatabase();
    await database.init();
  });

  tearDown(() async {
    if (database.db.isOpen) await database.db.close();
  });

  test('export is valid CSV and preserves portable transaction data', () async {
    final accountId = await database.addAccount(
      name: 'Carta, principale',
      balance: 100,
      colorValue: 0xFF8E8E93,
      iconKey: 'card',
      type: AccountType.card,
      includeInTotal: true,
      includeInAnalytics: true,
      hideBalance: false,
    );
    final categoryId = await database.addCategory(
      name: 'Cibo "fuori"',
      type: TransactionType.expense,
      iconKey: 'restaurant',
      colorValue: 0xFF8E8E93,
    );
    final date = DateTime.utc(2026, 9, 6, 10, 30);
    await database.addTransaction(
      type: TransactionType.expense,
      amount: 12.34,
      accountId: accountId,
      categoryId: categoryId,
      date: date,
      note: 'Pizza, "sera"\ncon amici',
      tags: const ['amici', 'cena'],
      includeInAnalytics: true,
    );

    final state = AppState(database)
      ..accounts = await database.accounts()
      ..categories = await database.categories()
      ..transactions = await database.transactions();

    const service = CsvService();
    final csv = service.export(state);
    final preview = service.preview(state, csv);

    expect(
      csv.split('\n').first,
      'type,amount,date,account,to_account,category,description,tags,include_in_analytics,stable_key',
    );
    expect(csv, contains('"Carta, principale"'));
    expect(csv, contains('"Cibo ""fuori"""'));
    expect(csv, contains('"Pizza, ""sera"" con amici"'));
    expect(preview.invalidRows, 0);
    expect(preview.rows, hasLength(1));

    final row = preview.rows.single;
    expect(row.type, TransactionType.expense);
    expect(row.amount, 12.34);
    expect(row.date.toUtc(), date);
    expect(row.account, 'Carta, principale');
    expect(row.category, 'Cibo "fuori"');
    expect(row.note, 'Pizza, "sera" con amici');
    expect(row.tags, ['amici', 'cena']);
    expect(row.includeInAnalytics, isTrue);
    expect(row.duplicate, isTrue);
  });
}

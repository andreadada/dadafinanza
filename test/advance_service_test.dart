import 'dart:io';

import 'package:dadafinanza/app_state.dart';
import 'package:dadafinanza/data/app_database.dart';
import 'package:dadafinanza/models/advance_models.dart';
import 'package:dadafinanza/models/models.dart';
import 'package:dadafinanza/services/advance_service.dart';
import 'package:dadafinanza/services/finance_schema_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

void main() {
  late AppDatabase database;
  late AdvanceService service;
  late int accountId;
  late int secondAccountId;
  late int expenseCategoryId;
  late int incomeCategoryId;
  late int personId;
  final now = DateTime(2026, 9, 5, 12);

  late Directory databaseRoot;

  setUpAll(() async {
    ffi.sqfliteFfiInit();
    databaseFactory = ffi.databaseFactoryFfi;
    databaseRoot = await Directory.systemTemp.createTemp(
      'dadafinanza-advance-db-',
    );
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
    await FinanceSchemaService(database).ensure();
    service = AdvanceService(database);

    accountId = await database.addAccount(
      name: 'Carta',
      balance: 1000,
      colorValue: 0xFF8E8E93,
      iconKey: 'wallet',
      type: AccountType.card,
      includeInTotal: true,
      includeInAnalytics: true,
      hideBalance: false,
    );
    secondAccountId = await database.addAccount(
      name: 'Conto',
      balance: 500,
      colorValue: 0xFF8E8E93,
      iconKey: 'bank',
      type: AccountType.checking,
      includeInTotal: true,
      includeInAnalytics: true,
      hideBalance: false,
    );
    expenseCategoryId = await database.addCategory(
      name: 'Spesa',
      type: TransactionType.expense,
      iconKey: 'shopping',
      colorValue: 0xFF8E8E93,
    );
    incomeCategoryId = await database.addCategory(
      name: 'Entrata',
      type: TransactionType.income,
      iconKey: 'money',
      colorValue: 0xFF8E8E93,
    );
    personId = await service.createPerson('Andrea');
  });

  tearDown(() async {
    if (database.db.isOpen) await database.db.close();
  });

  Future<double> balance(int id) async {
    final rows = await database.db.query(
      'accounts',
      columns: ['balance'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return (rows.single['balance'] as num).toDouble();
  }

  Future<FinanceTransaction> transaction(int id) async {
    final rows = await database.db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return FinanceTransaction.fromMap(rows.single);
  }

  test('creates and trims a finance person', () async {
    final id = await service.createPerson('  Luca  ');
    final people = await service.people();
    expect(people.singleWhere((item) => item.id == id).name, 'Luca');
  });

  test('rejects an empty finance person name', () async {
    expect(() => service.createPerson('   '), throwsA(isA<StateError>()));
  });

  test('renames a finance person', () async {
    await service.renamePerson(personId, '  Andrea D.  ');
    final person = (await service.people()).singleWhere(
      (item) => item.id == personId,
    );
    expect(person.name, 'Andrea D.');
  });

  test('pure receivable changes cash but not ordinary analytics', () async {
    final advanceId = await service.createPureAdvance(
      direction: AdvanceDirection.receivable,
      personId: personId,
      amount: 120,
      accountId: accountId,
      date: now,
    );
    final advance = (await service.advances()).singleWhere(
      (item) => item.id == advanceId,
    );
    final item = await transaction(advance.sourceTransactionId!);

    expect(await balance(accountId), 880);
    expect(item.type, TransactionType.expense);
    expect(item.kind, 'advance_origin');
    expect(item.includeInAnalytics, isFalse);
    expect(await service.remainingCents(advanceId), 12000);
  });

  test('pure payable increases cash and stays outside analytics', () async {
    final advanceId = await service.createPureAdvance(
      direction: AdvanceDirection.payable,
      personId: personId,
      amount: 80,
      accountId: accountId,
      date: now,
    );
    final advance = (await service.advances()).singleWhere(
      (item) => item.id == advanceId,
    );
    final item = await transaction(advance.sourceTransactionId!);

    expect(await balance(accountId), 1080);
    expect(item.type, TransactionType.income);
    expect(item.kind, 'advance_origin');
    expect(item.includeInAnalytics, isFalse);
  });

  test(
    'mixed expense keeps real cash amount and tracks only advanced share',
    () async {
      final transactionId = await service.createMixedExpense(
        personId: personId,
        totalAmount: 40,
        personalAmount: 10,
        advanceAmount: 30,
        accountId: accountId,
        categoryId: expenseCategoryId,
        date: now,
      );
      final item = await transaction(transactionId);
      final advance = (await service.advances()).single;

      expect(await balance(accountId), 960);
      expect(item.amount, 40);
      expect(item.kind, 'mixed_advance');
      expect(item.includeInAnalytics, isTrue);
      expect(advance.originalAmountCents, 3000);
      expect(await service.remainingCents(advance.id), 3000);
    },
  );

  test('mixed expense rejects inconsistent split amounts', () async {
    expect(
      () => service.createMixedExpense(
        personId: personId,
        totalAmount: 40,
        personalAmount: 15,
        advanceAmount: 30,
        accountId: accountId,
        categoryId: expenseCategoryId,
        date: now,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'partial receivable settlement increases cash and reduces remaining',
    () async {
      final advanceId = await service.createPureAdvance(
        direction: AdvanceDirection.receivable,
        personId: personId,
        amount: 100,
        accountId: accountId,
        date: now,
      );
      await service.recordSettlement(
        advanceId: advanceId,
        amount: 35,
        accountId: accountId,
        date: now.add(const Duration(days: 1)),
      );

      expect(await balance(accountId), 935);
      expect(await service.remainingCents(advanceId), 6500);
      final settlement = (await service.settlements()).single;
      final item = await transaction(settlement.transactionId);
      expect(item.type, TransactionType.income);
      expect(item.kind, 'advance_settlement');
      expect(item.includeInAnalytics, isFalse);
    },
  );

  test('full settlement closes the remaining amount to zero', () async {
    final advanceId = await service.createPureAdvance(
      direction: AdvanceDirection.receivable,
      personId: personId,
      amount: 100,
      accountId: accountId,
      date: now,
    );
    await service.recordSettlement(
      advanceId: advanceId,
      amount: 100,
      accountId: accountId,
      date: now,
    );
    expect(await service.remainingCents(advanceId), 0);
    expect(await balance(accountId), 1000);
  });

  test('over-settlement is rejected', () async {
    final advanceId = await service.createPureAdvance(
      direction: AdvanceDirection.receivable,
      personId: personId,
      amount: 100,
      accountId: accountId,
      date: now,
    );
    expect(
      () => service.recordSettlement(
        advanceId: advanceId,
        amount: 100.01,
        accountId: accountId,
        date: now,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('payable settlement decreases cash', () async {
    final advanceId = await service.createPureAdvance(
      direction: AdvanceDirection.payable,
      personId: personId,
      amount: 100,
      accountId: accountId,
      date: now,
    );
    await service.recordSettlement(
      advanceId: advanceId,
      amount: 25,
      accountId: accountId,
      date: now,
    );
    expect(await balance(accountId), 1075);
    expect(await service.remainingCents(advanceId), 7500);
  });

  test('editing a settlement adjusts the same account balance', () async {
    final advanceId = await service.createPureAdvance(
      direction: AdvanceDirection.receivable,
      personId: personId,
      amount: 100,
      accountId: accountId,
      date: now,
    );
    final settlementId = await service.recordSettlement(
      advanceId: advanceId,
      amount: 20,
      accountId: accountId,
      date: now,
    );
    await service.updateSettlement(
      settlementId: settlementId,
      amount: 35,
      accountId: accountId,
      date: now.add(const Duration(days: 2)),
      note: 'Aggiornato',
    );

    expect(await balance(accountId), 935);
    expect(await service.remainingCents(advanceId), 6500);
    final settlement = (await service.settlements()).single;
    expect(settlement.amountCents, 3500);
    expect(settlement.note, 'Aggiornato');
  });

  test('editing a settlement can move it to another account safely', () async {
    final advanceId = await service.createPureAdvance(
      direction: AdvanceDirection.receivable,
      personId: personId,
      amount: 100,
      accountId: accountId,
      date: now,
    );
    final settlementId = await service.recordSettlement(
      advanceId: advanceId,
      amount: 20,
      accountId: accountId,
      date: now,
    );
    await service.updateSettlement(
      settlementId: settlementId,
      amount: 20,
      accountId: secondAccountId,
      date: now,
    );

    expect(await balance(accountId), 900);
    expect(await balance(secondAccountId), 520);
  });

  test('deleting a settlement restores balance and remaining amount', () async {
    final advanceId = await service.createPureAdvance(
      direction: AdvanceDirection.receivable,
      personId: personId,
      amount: 100,
      accountId: accountId,
      date: now,
    );
    final settlementId = await service.recordSettlement(
      advanceId: advanceId,
      amount: 20,
      accountId: accountId,
      date: now,
    );
    await service.deleteSettlement(settlementId);

    expect(await balance(accountId), 900);
    expect(await service.remainingCents(advanceId), 10000);
    expect(await service.settlements(), isEmpty);
  });

  test('links an existing compatible movement as a settlement', () async {
    final advanceId = await service.createPureAdvance(
      direction: AdvanceDirection.receivable,
      personId: personId,
      amount: 100,
      accountId: accountId,
      date: now,
    );
    final transactionId = await database.addTransaction(
      type: TransactionType.income,
      amount: 40,
      accountId: accountId,
      categoryId: incomeCategoryId,
      date: now.add(const Duration(days: 1)),
      note: 'Andrea rimborso',
    );
    final before = await balance(accountId);

    await service.linkExistingTransactionAsSettlement(
      advanceId: advanceId,
      transactionId: transactionId,
    );

    expect(await balance(accountId), before);
    expect(await service.remainingCents(advanceId), 6000);
    final item = await transaction(transactionId);
    expect(item.kind, 'advance_settlement');
    expect(item.includeInAnalytics, isFalse);
  });

  test('rejects linking an incompatible movement direction', () async {
    final advanceId = await service.createPureAdvance(
      direction: AdvanceDirection.receivable,
      personId: personId,
      amount: 100,
      accountId: accountId,
      date: now,
    );
    final transactionId = await database.addTransaction(
      type: TransactionType.expense,
      amount: 20,
      accountId: accountId,
      categoryId: expenseCategoryId,
      date: now,
    );
    expect(
      () => service.linkExistingTransactionAsSettlement(
        advanceId: advanceId,
        transactionId: transactionId,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('deterministic matching finds an exact named reimbursement', () async {
    final advanceId = await service.createPureAdvance(
      direction: AdvanceDirection.receivable,
      personId: personId,
      amount: 50,
      accountId: accountId,
      date: now,
    );
    final suggestion = await service.suggestMatch(
      type: TransactionType.income,
      amount: 50,
      note: 'Rimborso Andrea',
    );
    expect(suggestion, isNotNull);
    expect(suggestion!.advanceId, advanceId);
    expect(suggestion.confidence, greaterThanOrEqualTo(.9));
  });

  test('ambiguous deterministic matching returns no suggestion', () async {
    await service.createPureAdvance(
      direction: AdvanceDirection.receivable,
      personId: personId,
      amount: 50,
      accountId: accountId,
      date: now,
    );
    final secondPerson = await service.createPerson('Luca');
    await service.createPureAdvance(
      direction: AdvanceDirection.receivable,
      personId: secondPerson,
      amount: 50,
      accountId: secondAccountId,
      date: now,
    );
    final suggestion = await service.suggestMatch(
      type: TransactionType.income,
      amount: 50,
    );
    expect(suggestion, isNull);
  });

  test('cannot archive a person with open money', () async {
    await service.createPureAdvance(
      direction: AdvanceDirection.receivable,
      personId: personId,
      amount: 50,
      accountId: accountId,
      date: now,
    );
    expect(
      () => service.archivePerson(personId, true),
      throwsA(isA<StateError>()),
    );
  });

  test('can archive a person after full settlement', () async {
    final advanceId = await service.createPureAdvance(
      direction: AdvanceDirection.receivable,
      personId: personId,
      amount: 50,
      accountId: accountId,
      date: now,
    );
    await service.recordSettlement(
      advanceId: advanceId,
      amount: 50,
      accountId: accountId,
      date: now,
    );
    await service.archivePerson(personId, true);
    expect(await service.people(), isEmpty);
    final archived = await service.people(includeArchived: true);
    expect(
      archived.singleWhere((item) => item.id == personId).archived,
      isTrue,
    );
  });

  test('updates editable advance metadata', () async {
    final otherPerson = await service.createPerson('Luca');
    final advanceId = await service.createPureAdvance(
      direction: AdvanceDirection.receivable,
      personId: personId,
      amount: 50,
      accountId: accountId,
      date: now,
    );
    final due = now.add(const Duration(days: 10));
    final reminder = now.add(const Duration(days: 8));
    await service.updateAdvanceDetails(
      advanceId: advanceId,
      personId: otherPerson,
      dueDate: due,
      reminderDate: reminder,
      note: 'Cena',
    );
    final advance = (await service.advances()).singleWhere(
      (item) => item.id == advanceId,
    );
    expect(advance.personId, otherPerson);
    expect(advance.dueDate, due);
    expect(advance.reminderDate, reminder);
    expect(advance.note, 'Cena');
  });

  test(
    'cancelling a pure receivable reverses its original cash movement',
    () async {
      final advanceId = await service.createPureAdvance(
        direction: AdvanceDirection.receivable,
        personId: personId,
        amount: 100,
        accountId: accountId,
        date: now,
      );
      final sourceId = (await service.advances()).single.sourceTransactionId!;
      await service.cancelAdvance(advanceId);

      expect(await balance(accountId), 1000);
      final advance = (await service.advances()).single;
      expect(advance.closedKind, AdvanceClosedKind.cancelled);
      expect(advance.sourceTransactionId, isNull);
      final source = await database.db.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [sourceId],
      );
      expect(source, isEmpty);
    },
  );

  test(
    'cancelling a mixed expense preserves cash and makes purchase normal',
    () async {
      final transactionId = await service.createMixedExpense(
        personId: personId,
        totalAmount: 40,
        personalAmount: 10,
        advanceAmount: 30,
        accountId: accountId,
        categoryId: expenseCategoryId,
        date: now,
      );
      final advanceId = (await service.advances()).single.id;
      await service.cancelAdvance(advanceId);

      expect(await balance(accountId), 960);
      expect((await transaction(transactionId)).kind, 'normal');
      expect(
        (await service.advances()).single.closedKind,
        AdvanceClosedKind.cancelled,
      );
    },
  );

  test('cancelling an advance with settlements is rejected', () async {
    final advanceId = await service.createPureAdvance(
      direction: AdvanceDirection.receivable,
      personId: personId,
      amount: 100,
      accountId: accountId,
      date: now,
    );
    await service.recordSettlement(
      advanceId: advanceId,
      amount: 10,
      accountId: accountId,
      date: now,
    );
    expect(() => service.cancelAdvance(advanceId), throwsA(isA<StateError>()));
  });

  test(
    'write-off without analytics closes receivable without moving cash',
    () async {
      final advanceId = await service.createPureAdvance(
        direction: AdvanceDirection.receivable,
        personId: personId,
        amount: 100,
        accountId: accountId,
        date: now,
      );
      final before = await balance(accountId);
      final transactionCount = (await database.transactions()).length;
      await service.closeWithoutRecovery(
        advanceId: advanceId,
        recognizeInAnalytics: false,
      );
      final advance = (await service.advances()).single;
      expect(advance.closedKind, AdvanceClosedKind.writtenOff);
      expect(await balance(accountId), before);
      expect((await database.transactions()).length, transactionCount);
    },
  );

  test('forgiven payable closes without moving cash', () async {
    final advanceId = await service.createPureAdvance(
      direction: AdvanceDirection.payable,
      personId: personId,
      amount: 100,
      accountId: accountId,
      date: now,
    );
    final before = await balance(accountId);
    await service.closeWithoutRecovery(
      advanceId: advanceId,
      recognizeInAnalytics: false,
    );
    expect(
      (await service.advances()).single.closedKind,
      AdvanceClosedKind.forgiven,
    );
    expect(await balance(accountId), before);
  });

  test(
    'recognized write-off creates analytics adjustment without cash delta',
    () async {
      final advanceId = await service.createPureAdvance(
        direction: AdvanceDirection.receivable,
        personId: personId,
        amount: 100,
        accountId: accountId,
        date: now,
      );
      final before = await balance(accountId);
      await service.closeWithoutRecovery(
        advanceId: advanceId,
        recognizeInAnalytics: true,
        categoryId: expenseCategoryId,
        accountId: accountId,
        date: now.add(const Duration(days: 2)),
      );
      expect(await balance(accountId), before);
      final items = await database.transactions();
      final adjustment = items.singleWhere(
        (item) => item.kind == 'advance_writeoff',
      );
      expect(adjustment.includeInAnalytics, isTrue);
      expect(adjustment.amount, 100);
    },
  );

  test('mixed expense analytics expose only the personal share', () async {
    final transactionId = await service.createMixedExpense(
      personId: personId,
      totalAmount: 40,
      personalAmount: 10,
      advanceAmount: 30,
      accountId: accountId,
      categoryId: expenseCategoryId,
      date: now,
    );
    final state = AppState(database)
      ..accounts = await database.accounts()
      ..categories = await database.categories()
      ..transactions = await database.transactions()
      ..splits = await database.splits()
      ..advances = await service.advances()
      ..advanceSettlements = await service.settlements();

    final projected = state.analyticTransactions().singleWhere(
      (item) => item.id == transactionId,
    );
    expect(projected.amount, 10);
    expect(state.monthCategoryTotal(expenseCategoryId, month: now), 10);
  });

  test('pure advance origin is absent from analytic transactions', () async {
    await service.createPureAdvance(
      direction: AdvanceDirection.receivable,
      personId: personId,
      amount: 25,
      accountId: accountId,
      date: now,
    );
    final state = AppState(database)
      ..accounts = await database.accounts()
      ..categories = await database.categories()
      ..transactions = await database.transactions()
      ..advances = await service.advances()
      ..advanceSettlements = await service.settlements();
    expect(state.analyticTransactions(), isEmpty);
  });

  test('database trigger rejects raw over-settlement', () async {
    final advanceId = await service.createPureAdvance(
      direction: AdvanceDirection.receivable,
      personId: personId,
      amount: 100,
      accountId: accountId,
      date: now,
    );
    await service.recordSettlement(
      advanceId: advanceId,
      amount: 60,
      accountId: accountId,
      date: now,
    );
    final transactionId = await database.addTransaction(
      type: TransactionType.income,
      amount: 50,
      accountId: accountId,
      categoryId: incomeCategoryId,
      date: now,
    );
    expect(
      () => database.db.insert('advance_settlements', {
        'advance_id': advanceId,
        'amount_cents': 5000,
        'transaction_id': transactionId,
        'account_id': accountId,
        'date': now.millisecondsSinceEpoch,
        'created_at': now.millisecondsSinceEpoch,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('clearAllUserData removes people, advances and settlements', () async {
    final advanceId = await service.createPureAdvance(
      direction: AdvanceDirection.receivable,
      personId: personId,
      amount: 100,
      accountId: accountId,
      date: now,
    );
    await service.recordSettlement(
      advanceId: advanceId,
      amount: 10,
      accountId: accountId,
      date: now,
    );
    await database.clearAllUserData();

    expect(await database.db.query('finance_people'), isEmpty);
    expect(await database.db.query('advances'), isEmpty);
    expect(await database.db.query('advance_settlements'), isEmpty);
  });
}

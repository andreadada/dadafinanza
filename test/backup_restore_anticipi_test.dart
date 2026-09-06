import 'dart:io';

import 'package:dadafinanza/data/app_database.dart';
import 'package:dadafinanza/models/advance_models.dart';
import 'package:dadafinanza/models/models.dart';
import 'package:dadafinanza/services/advance_service.dart';
import 'package:dadafinanza/services/attachment_service.dart';
import 'package:dadafinanza/services/backup_service.dart';
import 'package:dadafinanza/services/finance_schema_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

class _TempAttachmentService extends AttachmentService {
  _TempAttachmentService(this.root);

  final Directory root;

  @override
  Future<Directory> directory() async {
    final target = Directory(p.join(root.path, 'attachments-live'));
    if (!await target.exists()) await target.create(recursive: true);
    return target;
  }
}

void main() {
  late AppDatabase database;
  late AdvanceService advances;
  late Directory temp;
  late _TempAttachmentService attachments;

  late Directory databaseRoot;

  setUpAll(() async {
    ffi.sqfliteFfiInit();
    databaseFactory = ffi.databaseFactoryFfi;
    databaseRoot = await Directory.systemTemp.createTemp(
      'dadafinanza-backup-db-',
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
    advances = AdvanceService(database);
    temp = await Directory.systemTemp.createTemp('dadafinanza-backup-test-');
    attachments = _TempAttachmentService(temp);
  });

  tearDown(() async {
    if (database.db.isOpen) await database.db.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test(
    'backup manifest and restore preserve the full Anticipi ledger',
    () async {
      final accountId = await database.addAccount(
        name: 'Carta',
        balance: 500,
        colorValue: 0xFF8E8E93,
        iconKey: 'wallet',
        type: AccountType.card,
        includeInTotal: true,
        includeInAnalytics: true,
        hideBalance: false,
      );
      final personId = await advances.createPerson('Andrea');
      final advanceId = await advances.createPureAdvance(
        direction: AdvanceDirection.receivable,
        personId: personId,
        amount: 80,
        accountId: accountId,
        date: DateTime(2026, 9, 5),
        note: 'Biglietti',
      );
      await advances.recordSettlement(
        advanceId: advanceId,
        amount: 30,
        accountId: accountId,
        date: DateTime(2026, 9, 6),
        note: 'Prima parte',
      );

      final attachmentDir = await attachments.directory();
      await File(p.join(attachmentDir.path, 'receipt-test.jpg'))
          .writeAsBytes([1, 2, 3, 4]);

      final backupService = BackupService(
        database,
        attachments: attachments,
        temporaryDirectory: () async => temp,
      );
      final backup = await backupService.create();
      final preview = await backupService.inspect(backup.path);

      expect(preview.people, 1);
      expect(preview.advances, 1);
      expect(preview.advanceSettlements, 1);
      expect(preview.attachments, 1);

      await database.clearAllUserData();
      expect(await database.db.query('finance_people'), isEmpty);
      expect(await database.db.query('advances'), isEmpty);
      expect(await database.db.query('advance_settlements'), isEmpty);

      final liveAttachment = File(
        p.join(attachmentDir.path, 'receipt-test.jpg'),
      );
      if (await liveAttachment.exists()) await liveAttachment.delete();

      await backupService.restore(backup.path);

      final restoredPeople = await database.db.query('finance_people');
      final restoredAdvances = await database.db.query('advances');
      final restoredSettlements = await database.db.query(
        'advance_settlements',
      );
      expect(restoredPeople, hasLength(1));
      expect(restoredPeople.single['name'], 'Andrea');
      expect(restoredAdvances, hasLength(1));
      expect(restoredAdvances.single['original_amount_cents'], 8000);
      expect(restoredSettlements, hasLength(1));
      expect(restoredSettlements.single['amount_cents'], 3000);
      expect(
        await File(p.join(attachmentDir.path, 'receipt-test.jpg')).exists(),
        isTrue,
      );
    },
  );
}

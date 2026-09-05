import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import 'attachment_service.dart';
import 'finance_schema_service.dart';

class BackupPreview {
  const BackupPreview({
    required this.createdAt,
    required this.schemaVersion,
    required this.accounts,
    required this.transactions,
    required this.categories,
    required this.attachments,
    required this.encrypted,
    this.people = 0,
    this.advances = 0,
    this.advanceSettlements = 0,
  });

  final DateTime createdAt;
  final int schemaVersion;
  final int accounts;
  final int transactions;
  final int categories;
  final int attachments;
  final int people;
  final int advances;
  final int advanceSettlements;
  final bool encrypted;
}

class BackupService {
  BackupService(
    this.database, {
    AttachmentService? attachments,
    Future<Directory> Function()? temporaryDirectory,
  }) : attachments = attachments ?? AttachmentService(),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  static const formatVersion = 1;
  final AppDatabase database;
  final AttachmentService attachments;
  final Future<Directory> Function() _temporaryDirectory;

  Future<File> create({String? password}) async {
    await database.db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    final temp = await _temporaryDirectory();
    final work = Directory(
      p.join(temp.path, 'dada-backup-${DateTime.now().microsecondsSinceEpoch}'),
    );
    await work.create(recursive: true);
    final databaseCopy = File(p.join(work.path, 'dadafinanza.db'));
    await File(await database.databaseFilePath()).copy(databaseCopy.path);

    final attachmentFiles = await attachments.all();
    final manifest = <String, Object?>{
      'format': 'DadaFinanzaBackup',
      'formatVersion': formatVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'schemaVersion': await _schemaVersion(database.db),
      'accounts': await _count(database.db, 'accounts', 'is_system = 0'),
      'transactions': await _count(database.db, 'transactions'),
      'categories': await _count(database.db, 'categories'),
      'people': await _count(database.db, 'finance_people'),
      'advances': await _count(database.db, 'advances'),
      'advanceSettlements': await _count(database.db, 'advance_settlements'),
      'attachments': attachmentFiles.length,
      'encrypted': password?.isNotEmpty == true,
    };
    final manifestFile = File(p.join(work.path, 'manifest.json'));
    await manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest),
      flush: true,
    );

    final zip = File(
      p.join(
        temp.path,
        'DadaFinanzaBackup-${DateTime.now().millisecondsSinceEpoch}.zip',
      ),
    );
    final encoder = ZipFileEncoder(
      password: password?.isEmpty == true ? null : password,
    );
    encoder.create(zip.path);
    await encoder.addFile(manifestFile, 'manifest.json');
    await encoder.addFile(databaseCopy, 'database/dadafinanza.db');
    for (final file in attachmentFiles) {
      await encoder.addFile(file, 'attachments/${p.basename(file.path)}');
    }
    await encoder.close();
    await work.delete(recursive: true);
    return zip;
  }

  Future<BackupPreview> inspect(String path, {String? password}) =>
      _withArchive(path, (archive) async {
        final manifestEntry = archive.files
            .where((entry) => entry.name == 'manifest.json' && entry.isFile)
            .firstOrNull;
        if (manifestEntry == null) {
          throw const FormatException('Backup DadaFinanza non riconosciuto.');
        }
        final bytes = manifestEntry.readBytes();
        if (bytes == null) {
          throw const FormatException('Manifest backup non leggibile.');
        }
        final json = jsonDecode(utf8.decode(bytes));
        if (json is! Map<String, dynamic> ||
            json['format'] != 'DadaFinanzaBackup') {
          throw const FormatException('Manifest backup non valido.');
        }
        return BackupPreview(
          createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
          schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
          accounts: (json['accounts'] as num?)?.toInt() ?? 0,
          transactions: (json['transactions'] as num?)?.toInt() ?? 0,
          categories: (json['categories'] as num?)?.toInt() ?? 0,
          people: (json['people'] as num?)?.toInt() ?? 0,
          advances: (json['advances'] as num?)?.toInt() ?? 0,
          advanceSettlements:
              (json['advanceSettlements'] as num?)?.toInt() ?? 0,
          attachments: (json['attachments'] as num?)?.toInt() ?? 0,
          encrypted: json['encrypted'] == true,
        );
      }, password: password);

  Future<void> restore(String path, {String? password}) async {
    await inspect(path, password: password);
    final temp = await _temporaryDirectory();
    final extract = Directory(
      p.join(
        temp.path,
        'dada-restore-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await extract.create(recursive: true);
    await _withArchive(
      path,
      (archive) => extractArchiveToDisk(archive, extract.path),
      password: password,
    );

    final restoredDb = File(p.join(extract.path, 'database', 'dadafinanza.db'));
    if (!await restoredDb.exists()) {
      await extract.delete(recursive: true);
      throw const FormatException('Database mancante nel backup.');
    }

    final safety = await create();
    try {
      await database.restoreDatabaseFrom(restoredDb.path);
      await FinanceSchemaService(database).ensure();
      final restoredAttachments = Directory(
        p.join(extract.path, 'attachments'),
      );
      await attachments.replaceDirectory(restoredAttachments);
      await _integrityCheck(database.db);
    } catch (_) {
      final safetyExtract = Directory(
        p.join(
          temp.path,
          'dada-safety-${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      await safetyExtract.create(recursive: true);
      await _withArchive(
        safety.path,
        (archive) => extractArchiveToDisk(archive, safetyExtract.path),
      );
      final safetyDb = File(
        p.join(safetyExtract.path, 'database', 'dadafinanza.db'),
      );
      if (await safetyDb.exists()) {
        await database.restoreDatabaseFrom(safetyDb.path);
        await FinanceSchemaService(database).ensure();
        await attachments.replaceDirectory(
          Directory(p.join(safetyExtract.path, 'attachments')),
        );
      }
      if (await safetyExtract.exists()) {
        await safetyExtract.delete(recursive: true);
      }
      rethrow;
    } finally {
      if (await extract.exists()) await extract.delete(recursive: true);
      if (await safety.exists()) await safety.delete();
    }
  }

  Future<T> _withArchive<T>(
    String path,
    Future<T> Function(Archive) use, {
    String? password,
  }) async {
    final file = File(path);
    if (!await file.exists()) throw StateError('Backup non trovato.');
    final stream = InputFileStream(file.path);
    try {
      final archive = ZipDecoder().decodeStream(stream, password: password);
      return await use(archive);
    } finally {
      await stream.close();
    }
  }

  Future<int> _schemaVersion(Database db) async =>
      Sqflite.firstIntValue(await db.rawQuery('PRAGMA user_version')) ?? 0;

  Future<int> _count(Database db, String table, [String? where]) async =>
      Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM $table${where == null ? '' : ' WHERE $where'}',
        ),
      ) ??
      0;

  Future<void> _integrityCheck(Database db) async {
    final rows = await db.rawQuery('PRAGMA integrity_check');
    if (rows.isEmpty ||
        rows.first.values.first.toString().toLowerCase() != 'ok') {
      throw StateError(
        'Il database ripristinato non supera il controllo integrità.',
      );
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

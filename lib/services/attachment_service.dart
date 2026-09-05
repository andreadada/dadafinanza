import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AttachmentService {
  static const _folderName = 'attachments';

  Future<Directory> directory() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, _folderName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> persist(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw StateError('Allegato non trovato.');
    }
    final dir = await directory();
    final extension = p.extension(source.path).toLowerCase();
    final safeExtension = extension.isEmpty ? '.jpg' : extension;
    final name =
        'receipt-${DateTime.now().microsecondsSinceEpoch}$safeExtension';
    final destination = File(p.join(dir.path, name));
    await source.copy(destination.path);
    return name;
  }

  Future<File?> resolve(String? storedPath) async {
    if (storedPath == null || storedPath.trim().isEmpty) return null;
    final direct = File(storedPath);
    if (await direct.exists()) return direct;
    final dir = await directory();
    final managed = File(p.join(dir.path, p.basename(storedPath)));
    return await managed.exists() ? managed : null;
  }

  Future<void> delete(String? storedPath) async {
    final file = await resolve(storedPath);
    if (file == null) return;
    final dir = await directory();
    final normalizedRoot = p.normalize(dir.path);
    final normalizedFile = p.normalize(file.path);
    if (!p.isWithin(normalizedRoot, normalizedFile)) return;
    if (await file.exists()) await file.delete();
  }

  Future<List<File>> all() async {
    final dir = await directory();
    return dir
        .listSync(followLinks: false)
        .whereType<File>()
        .toList(growable: false);
  }

  Future<int> cleanup(Iterable<String?> referencedPaths) async {
    final referenced = referencedPaths
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .map(p.basename)
        .toSet();
    var removed = 0;
    for (final file in await all()) {
      if (!referenced.contains(p.basename(file.path))) {
        await file.delete();
        removed++;
      }
    }
    return removed;
  }

  Future<void> replaceDirectory(Directory source) async {
    final target = await directory();
    if (await target.exists()) {
      await target.delete(recursive: true);
      await target.create(recursive: true);
    }
    if (!await source.exists()) return;
    await for (final entity in source.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      await entity.copy(p.join(target.path, name));
    }
  }
}

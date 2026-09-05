from pathlib import Path

path = Path('lib/services/backup_service.dart')
text = path.read_text()
old = """class BackupService {\n  BackupService(this.database, {AttachmentService? attachments})\n    : attachments = attachments ?? AttachmentService();\n\n  static const formatVersion = 1;\n  final AppDatabase database;\n  final AttachmentService attachments;\n"""
new = """class BackupService {\n  BackupService(\n    this.database, {\n    AttachmentService? attachments,\n    Future<Directory> Function()? temporaryDirectory,\n  }) : attachments = attachments ?? AttachmentService(),\n       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;\n\n  static const formatVersion = 1;\n  final AppDatabase database;\n  final AttachmentService attachments;\n  final Future<Directory> Function() _temporaryDirectory;\n"""
if old not in text:
    raise RuntimeError('BackupService constructor anchor not found')
text = text.replace(old, new, 1)
count = text.count('final temp = await getTemporaryDirectory();')
if count != 2:
    raise RuntimeError(f'Expected two temporary-directory calls, found {count}')
text = text.replace(
    'final temp = await getTemporaryDirectory();',
    'final temp = await _temporaryDirectory();',
)
path.write_text(text)

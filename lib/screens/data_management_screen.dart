import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/backup_service.dart';
import '../services/csv_service.dart';
import '../widgets/ui_helpers.dart';

class DataManagementScreen extends StatelessWidget {
  const DataManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Dati e backup')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          const SectionTitle('Backup completo'),
          _Action(
            icon: Icons.folder_zip_outlined,
            title: 'Crea backup',
            subtitle: 'Database, impostazioni, Smart Finance e ricevute.',
            onTap: () => _createBackup(context, state),
          ),
          _Action(
            icon: Icons.settings_backup_restore_rounded,
            title: 'Ripristina backup',
            subtitle:
                'Controlla il contenuto prima di sostituire i dati locali.',
            onTap: () => _restoreBackup(context, state),
          ),
          const SizedBox(height: 32),
          const SectionTitle('CSV portabile'),
          _Action(
            icon: Icons.file_download_outlined,
            title: 'Esporta movimenti',
            subtitle: 'Usa nomi di conti e categorie, non ID SQLite.',
            onTap: () => _exportCsv(context, state),
          ),
          _Action(
            icon: Icons.file_upload_outlined,
            title: 'Importa movimenti',
            subtitle: 'Anteprima, mapping dei dati mancanti e duplicati.',
            onTap: () => _importCsv(context, state),
          ),
          const SizedBox(height: 32),
          const SectionTitle('Locale'),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.phonelink_lock_outlined),
            title: Text('Dati sul dispositivo'),
            subtitle: Text(
              'DadaFinanza non invia movimenti, ricevute, descrizioni o pattern a servizi esterni.',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Cancella tutti i dati',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text('Operazione irreversibile dopo la conferma.'),
            onTap: () => _clear(context, state),
          ),
        ],
      ),
    );
  }

  Future<void> _createBackup(BuildContext context, AppState state) async {
    final password = await _passwordDialog(
      context,
      title: 'Proteggi il backup?',
      optional: true,
    );
    if (password == _cancelledPassword) return;
    try {
      final file = await BackupService(state.database)
          .create(password: password?.isEmpty == true ? null : password);
      final output = await FilePicker.saveFile(
        dialogTitle: 'Salva backup DadaFinanza',
        fileName:
            'DadaFinanzaBackup-${DateFormat('yyyy-MM-dd-HHmm').format(DateTime.now())}.zip',
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        bytes: await file.readAsBytes(),
      );
      if (await file.exists()) await file.delete();
      if (context.mounted && output != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup completo salvato.')),
        );
      }
    } catch (error) {
      if (context.mounted) _error(context, 'Backup non riuscito: $error');
    }
  }

  Future<void> _restoreBackup(BuildContext context, AppState state) async {
    final selected = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (selected == null) return;
    final source = await _materialize(selected, extension: '.zip');
    final service = BackupService(state.database);
    String? password;
    BackupPreview preview;
    try {
      preview = await service.inspect(source.path);
    } catch (_) {
      if (!context.mounted) return;
      password = await _passwordDialog(
        context,
        title: 'Password backup',
        optional: false,
      );
      if (password == null || password == _cancelledPassword) {
        if (await source.exists()) await source.delete();
        return;
      }
      try {
        preview = await service.inspect(source.path, password: password);
      } catch (error) {
        if (await source.exists()) await source.delete();
        if (context.mounted) _error(context, 'Backup non leggibile: $error');
        return;
      }
    }
    if (!context.mounted) return;
    final confirmed = await _confirmRestore(context, preview);
    if (!confirmed) {
      if (await source.exists()) await source.delete();
      return;
    }
    try {
      await service.restore(source.path, password: password);
      await state.load();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup ripristinato e verificato.')),
        );
      }
    } catch (error) {
      if (context.mounted) _error(context, 'Ripristino non riuscito: $error');
    } finally {
      if (await source.exists()) await source.delete();
    }
  }

  Future<bool> _confirmRestore(
    BuildContext context,
    BackupPreview preview,
  ) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contenuto backup',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _PreviewLine(
              'Creato',
              DateFormat('dd/MM/yyyy HH:mm').format(preview.createdAt),
            ),
            _PreviewLine('Schema', 'v${preview.schemaVersion}'),
            _PreviewLine('Conti', '${preview.accounts}'),
            _PreviewLine('Movimenti', '${preview.transactions}'),
            _PreviewLine('Categorie', '${preview.categories}'),
            _PreviewLine('Allegati', '${preview.attachments}'),
            const SizedBox(height: 16),
            const Text(
              'Prima del ripristino viene creato un safety backup temporaneo. Se il controllo integrità fallisce, i dati attuali vengono ripristinati.',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    child: const Text('Annulla'),
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    child: const Text('Ripristina'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  Future<void> _exportCsv(BuildContext context, AppState state) async {
    try {
      final csv = const CsvService().export(state);
      final output = await FilePicker.saveFile(
        dialogTitle: 'Esporta movimenti',
        fileName:
            'dadafinanza-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );
      if (context.mounted && output != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('CSV esportato.')));
      }
    } catch (error) {
      if (context.mounted) _error(context, 'Esportazione non riuscita: $error');
    }
  }

  Future<void> _importCsv(BuildContext context, AppState state) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (file == null) return;
    try {
      final preview = const CsvService().preview(
        state,
        utf8.decode(await file.readAsBytes()),
      );
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CsvImportWizard(preview: preview)),
      );
    } catch (error) {
      if (context.mounted) _error(context, 'CSV non valido: $error');
    }
  }

  Future<void> _clear(BuildContext context, AppState state) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Cancellare tutti i dati?',
      message: 'Conti, movimenti, categorie, budget, obiettivi, regole e apprendimento locale verranno eliminati. Crea prima un backup se vuoi conservarli.',
      confirmLabel: 'Cancella definitivamente',
    );
    if (!confirmed) return;
    await state.clearAllUserData();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dati locali cancellati.')));
    }
  }

  Future<File> _materialize(
    PlatformFile selected, {
    required String extension,
  }) async {
    if (selected.path != null) return File(selected.path!);
    final file = File(
      '${Directory.systemTemp.path}/dada-import-${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await file.writeAsBytes(await selected.readAsBytes(), flush: true);
    return file;
  }

  void _error(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

const _cancelledPassword = '__CANCELLED__';

Future<String?> _passwordDialog(
  BuildContext context, {
  required String title,
  required bool optional,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String?>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        obscureText: true,
        autofocus: !optional,
        decoration: InputDecoration(
          labelText: optional ? 'Password opzionale' : 'Password',
          helperText: optional
              ? 'Lascia vuoto per un backup non cifrato.'
              : 'Inserisci la password usata per creare il backup.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, _cancelledPassword),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: const Text('Continua'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

class CsvImportWizard extends StatefulWidget {
  const CsvImportWizard({required this.preview, super.key});
  final CsvImportPreview preview;

  @override
  State<CsvImportWizard> createState() => _CsvImportWizardState();
}

class _CsvImportWizardState extends State<CsvImportWizard> {
  final accountActions = <String, CsvMissingAction>{};
  final categoryActions = <String, CsvMissingAction>{};
  bool skipDuplicates = true;
  bool importing = false;

  @override
  void initState() {
    super.initState();
    for (final account in widget.preview.missingAccounts) {
      accountActions[account] = CsvMissingAction.unassigned;
    }
    for (final category in widget.preview.missingCategories) {
      categoryActions[category] = CsvMissingAction.ignore;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Importa CSV')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          const SectionTitle('Anteprima'),
          _PreviewLine('Righe valide', '${widget.preview.rows.length}'),
          _PreviewLine('Non valide', '${widget.preview.invalidRows}'),
          _PreviewLine('Possibili duplicati', '${widget.preview.duplicates}'),
          if (widget.preview.rows.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...widget.preview.rows
                .take(3)
                .map(
                  (row) => FlatMetric(
                    label: '${row.account} · ${row.category ?? row.type.label}',
                    value: moneyFor(state, row.amount),
                    icon: row.duplicate
                        ? Icons.content_copy_rounded
                        : Icons.receipt_long_outlined,
                  ),
                ),
          ],
          if (widget.preview.missingAccounts.isNotEmpty) ...[
            const SizedBox(height: 28),
            const SectionTitle('Conti non trovati'),
            ...widget.preview.missingAccounts.map(
              (name) => _MappingTile(
                name: name,
                value: accountActions[name]!,
                account: true,
                onChanged: (value) =>
                    setState(() => accountActions[name] = value),
              ),
            ),
          ],
          if (widget.preview.missingCategories.isNotEmpty) ...[
            const SizedBox(height: 28),
            const SectionTitle('Categorie non trovate'),
            ...widget.preview.missingCategories.map(
              (name) => _MappingTile(
                name: name,
                value: categoryActions[name]!,
                account: false,
                onChanged: (value) =>
                    setState(() => categoryActions[name] = value),
              ),
            ),
          ],
          if (widget.preview.duplicates > 0) ...[
            const SizedBox(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ignora possibili duplicati'),
              subtitle: Text(
                '${widget.preview.duplicates} righe corrispondono allo storico esistente.',
              ),
              value: skipDuplicates,
              onChanged: (value) => setState(() => skipDuplicates = value),
            ),
          ],
          const SizedBox(height: 28),
          Text(
            'Verranno considerate ${skipDuplicates ? widget.preview.importable : widget.preview.rows.length} righe prima del mapping.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: importing || widget.preview.rows.isEmpty
                  ? null
                  : () => _import(state),
              child: Text(
                importing ? 'Importazione…' : 'Conferma importazione',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _import(AppState state) async {
    setState(() => importing = true);
    try {
      final count = await const CsvService().import(
        state,
        widget.preview,
        CsvImportPlan(
          accountActions: accountActions,
          categoryActions: categoryActions,
          skipDuplicates: skipDuplicates,
        ),
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('$count movimenti importati.')),
      );
    } catch (error) {
      if (mounted) {
        setState(() => importing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Importazione non riuscita: $error')),
        );
      }
    }
  }
}

class _MappingTile extends StatelessWidget {
  const _MappingTile({
    required this.name,
    required this.value,
    required this.account,
    required this.onChanged,
  });

  final String name;
  final CsvMissingAction value;
  final bool account;
  final ValueChanged<CsvMissingAction> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(name),
    subtitle: Text(switch (value) {
      CsvMissingAction.create => 'Crea nuovo',
      CsvMissingAction.unassigned =>
        account ? 'Usa Non assegnato' : 'Senza categoria',
      CsvMissingAction.ignore => 'Ignora riferimento',
    }),
    trailing: PopupMenuButton<CsvMissingAction>(
      onSelected: onChanged,
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: CsvMissingAction.create,
          child: Text('Crea nuovo'),
        ),
        if (account)
          const PopupMenuItem(
            value: CsvMissingAction.unassigned,
            child: Text('Usa Non assegnato'),
          ),
        const PopupMenuItem(
          value: CsvMissingAction.ignore,
          child: Text('Ignora'),
        ),
      ],
    ),
  );
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: 12,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

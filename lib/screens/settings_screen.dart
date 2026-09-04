import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../main.dart';
import '../models/models.dart';
import '../widgets/ui_helpers.dart';
import 'account_screens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          const SectionTitle('Aspetto'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.contrast_rounded),
            title: const Text('Tema'),
            subtitle: Text(_themeLabel(state.themePreference)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showThemePicker(context, state),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.visibility_off_outlined),
            title: const Text('Nascondi saldi'),
            subtitle: const Text('Nasconde gli importi sensibili nelle schermate principali.'),
            value: state.hideBalance,
            onChanged: state.setHideBalance,
          ),
          const SizedBox(height: 28),
          const SectionTitle('Generali'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.euro_rounded),
            title: const Text('Valuta principale'),
            subtitle: Text(state.currency),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showCurrencyPicker(context, state),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.pin_outlined),
            title: const Text('Mostra centesimi'),
            value: state.showCents,
            onChanged: (value) => state.setSetting('show_cents', value ? '1' : '0'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.vibration_rounded),
            title: const Text('Feedback aptico'),
            value: state.haptics,
            onChanged: (value) => state.setSetting('haptics', value ? '1' : '0'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_view_week_outlined),
            title: const Text('Primo giorno della settimana'),
            subtitle: Text(state.weekStart == 7 ? 'Domenica' : 'Lunedì'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showWeekStartPicker(context, state),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Inizio mese finanziario'),
            subtitle: Text('Giorno ${state.financialMonthStart}'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showFinancialMonthStart(context, state),
          ),
          const SizedBox(height: 28),
          const SectionTitle('Movimenti'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.help_outline_rounded),
            title: const Text('Permetti “Non assegnato”'),
            subtitle: const Text('Consente di registrare velocemente un movimento e scegliere il conto in seguito.'),
            value: state.allowUnassigned,
            onChanged: (value) => state.setSetting('allow_unassigned', value ? '1' : '0'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.swap_horiz_rounded),
            title: const Text('Trasferimenti nelle statistiche'),
            subtitle: const Text('Di default i trasferimenti non gonfiano entrate e spese.'),
            value: state.showTransfersInAnalytics,
            onChanged: (value) => state.setSetting('show_transfers_analytics', value ? '1' : '0'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.warning_amber_rounded),
            title: const Text('Conferma eliminazioni'),
            value: state.confirmDelete,
            onChanged: (value) => state.setSetting('confirm_delete', value ? '1' : '0'),
          ),
          const SizedBox(height: 28),
          const SectionTitle('Organizzazione'),
          _SettingsLink(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Conti',
            subtitle: '${state.userAccounts.length} conti',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen())),
          ),
          _SettingsLink(
            icon: Icons.category_outlined,
            title: 'Categorie',
            subtitle: '${state.categories.length} categorie',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
          ),
          _SettingsLink(
            icon: Icons.dashboard_customize_outlined,
            title: 'Dashboard',
            subtitle: 'Mostra, nascondi, ridimensiona e riordina widget',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardCustomizerScreen())),
          ),
          _SettingsLink(
            icon: Icons.auto_fix_high_outlined,
            title: 'Regole automatiche',
            subtitle: '${state.rules.length} regole',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RulesScreen())),
          ),
          const SizedBox(height: 28),
          const SectionTitle('Privacy'),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.phonelink_lock_outlined),
            title: Text('Dati locali sul dispositivo'),
            subtitle: Text('DadaFinanza non richiede un account: il database finanziario resta locale.'),
          ),
          const SizedBox(height: 28),
          const SectionTitle('Dati'),
          _SettingsLink(
            icon: Icons.file_download_outlined,
            title: 'Esporta CSV',
            subtitle: 'Esporta tutti i movimenti in un file interoperabile',
            onTap: () => _exportCsv(context, state),
          ),
          _SettingsLink(
            icon: Icons.file_upload_outlined,
            title: 'Importa CSV',
            subtitle: 'Importa un CSV esportato da DadaFinanza',
            onTap: () => _importCsv(context, state),
          ),
          _SettingsLink(
            icon: Icons.backup_outlined,
            title: 'Backup database',
            subtitle: 'Salva una copia completa del database locale',
            onTap: () => _backupDatabase(context, state),
          ),
          _SettingsLink(
            icon: Icons.settings_backup_restore_rounded,
            title: 'Ripristina backup',
            subtitle: 'Sostituisce i dati correnti con un backup DadaFinanza',
            onTap: () => _restoreDatabase(context, state),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
            title: Text('Cancella tutti i dati', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            subtitle: const Text('Rimuove conti, movimenti, categorie, budget, obiettivi e ricorrenti.'),
            onTap: () => _clearAll(context, state),
          ),
          const SizedBox(height: 24),
          Text(
            'DadaFinanza · private-first personal finance',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SettingsLink extends StatelessWidget {
  const _SettingsLink({required this.icon, required this.title, required this.subtitle, required this.onTap});
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

String _themeLabel(AppThemePreference value) => switch (value) {
      AppThemePreference.system => 'Automatico',
      AppThemePreference.light => 'Chiaro',
      AppThemePreference.dark => 'Scuro',
    };

Future<void> _showThemePicker(BuildContext context, AppState state) async {
  final selected = await showModalBottomSheet<AppThemePreference>(
    context: context,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tema', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...AppThemePreference.values.map(
            (item) => RadioListTile<AppThemePreference>(
              contentPadding: EdgeInsets.zero,
              value: item,
              groupValue: state.themePreference,
              title: Text(_themeLabel(item)),
              subtitle: item == AppThemePreference.system ? const Text('Segue il tema del dispositivo') : null,
              onChanged: (value) => Navigator.pop(context, value),
            ),
          ),
        ],
      ),
    ),
  );
  if (selected != null) await state.setThemePreference(selected);
}

Future<void> _showCurrencyPicker(BuildContext context, AppState state) async {
  const values = ['EUR', 'USD', 'GBP', 'CHF'];
  final selected = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Valuta principale', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...values.map(
            (value) => RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: value,
              groupValue: state.currency,
              title: Text(value),
              onChanged: (item) => Navigator.pop(context, item),
            ),
          ),
        ],
      ),
    ),
  );
  if (selected != null) await state.setSetting('currency', selected);
}

Future<void> _showWeekStartPicker(BuildContext context, AppState state) async {
  final selected = await showModalBottomSheet<int>(
    context: context,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Primo giorno della settimana', style: Theme.of(context).textTheme.titleLarge),
          RadioListTile<int>(
            contentPadding: EdgeInsets.zero,
            value: 1,
            groupValue: state.weekStart,
            title: const Text('Lunedì'),
            onChanged: (value) => Navigator.pop(context, value),
          ),
          RadioListTile<int>(
            contentPadding: EdgeInsets.zero,
            value: 7,
            groupValue: state.weekStart,
            title: const Text('Domenica'),
            onChanged: (value) => Navigator.pop(context, value),
          ),
        ],
      ),
    ),
  );
  if (selected != null) await state.setSetting('week_start', selected.toString());
}

Future<void> _showFinancialMonthStart(BuildContext context, AppState state) async {
  var value = state.financialMonthStart.clamp(1, 28);
  final selected = await showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Inizio mese finanziario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scegli il giorno da cui considerare l’inizio del mese finanziario.'),
            const SizedBox(height: 16),
            Text('Giorno $value', style: Theme.of(context).textTheme.titleLarge),
            Slider(
              min: 1,
              max: 28,
              divisions: 27,
              value: value.toDouble(),
              label: '$value',
              onChanged: (next) => setState(() => value = next.round()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(context, value), child: const Text('Salva')),
        ],
      ),
    ),
  );
  if (selected != null) await state.setSetting('financial_month_start', selected.toString());
}

Future<void> _exportCsv(BuildContext context, AppState state) async {
  try {
    final csv = await state.exportCsv();
    final output = await FilePicker.platform.saveFile(
      dialogTitle: 'Esporta movimenti',
      fileName: 'dadafinanza-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
      bytes: utf8.encode(csv),
    );
    if (context.mounted && output != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV esportato.')));
    }
  } catch (error) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Esportazione non riuscita: $error')));
  }
}

Future<void> _importCsv(BuildContext context, AppState state) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (result == null) return;
    final file = result.files.single;
    final bytes = file.bytes ?? (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) throw StateError('Impossibile leggere il file selezionato.');
    final count = await state.importCsv(utf8.decode(bytes));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count movimenti importati.')));
    }
  } catch (error) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Importazione non riuscita: $error')));
  }
}

Future<void> _backupDatabase(BuildContext context, AppState state) async {
  try {
    final source = await state.databaseFilePath();
    final bytes = await File(source).readAsBytes();
    final output = await FilePicker.platform.saveFile(
      dialogTitle: 'Salva backup DadaFinanza',
      fileName: 'dadafinanza-backup-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.db',
      bytes: bytes,
    );
    if (context.mounted && output != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup salvato.')));
    }
  } catch (error) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup non riuscito: $error')));
  }
}

Future<void> _restoreDatabase(BuildContext context, AppState state) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['db'],
  );
  if (result == null || result.files.single.path == null || !context.mounted) return;
  final confirmed = await confirmDestructiveAction(
    context,
    title: 'Ripristinare questo backup?',
    message: 'Il database corrente verrà sostituito completamente. È consigliato creare prima un backup.',
    confirmLabel: 'Ripristina',
  );
  if (!confirmed) return;
  try {
    await state.restoreDatabaseFrom(result.files.single.path!);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup ripristinato.')));
  } catch (error) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ripristino non riuscito: $error')));
  }
}

Future<void> _clearAll(BuildContext context, AppState state) async {
  final confirmed = await confirmDestructiveAction(
    context,
    title: 'Cancellare tutti i dati?',
    message: 'Verranno rimossi definitivamente conti, movimenti, categorie, budget, obiettivi, ricorrenti e regole. Le impostazioni dell’app resteranno disponibili.',
    confirmLabel: 'Cancella definitivamente',
  );
  if (!confirmed) return;
  await state.clearAllUserData();
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dati cancellati.')));
}

class DashboardCustomizerScreen extends StatefulWidget {
  const DashboardCustomizerScreen({super.key});

  @override
  State<DashboardCustomizerScreen> createState() => _DashboardCustomizerScreenState();
}

class _DashboardCustomizerScreenState extends State<DashboardCustomizerScreen> {
  List<DashboardWidgetConfig>? items;

  void _ensure(AppState state) {
    items ??= state.dashboardWidgets
        .map(
          (item) => DashboardWidgetConfig(
            type: item.type,
            enabled: item.enabled,
            orderIndex: item.orderIndex,
            size: item.size,
          ),
        )
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }

  Future<void> _save(AppState state) async {
    final normalized = <DashboardWidgetConfig>[];
    for (var index = 0; index < items!.length; index++) {
      final item = items![index];
      normalized.add(
        DashboardWidgetConfig(
          type: item.type,
          enabled: item.enabled,
          orderIndex: index,
          size: item.size,
        ),
      );
    }
    items = normalized;
    await state.saveDashboard(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    _ensure(state);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalizza dashboard'),
        actions: [
          TextButton(
            onPressed: () async {
              await state.resetDashboard();
              if (mounted) setState(() => items = null);
            },
            child: const Text('Ripristina'),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
        itemCount: items!.length,
        onReorder: (oldIndex, newIndex) async {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final item = items!.removeAt(oldIndex);
            items!.insert(newIndex, item);
          });
          await _save(state);
        },
        itemBuilder: (context, index) {
          final item = items![index];
          return ListTile(
            key: ValueKey(item.type),
            leading: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle_rounded)),
            title: Text(item.type.label),
            subtitle: DropdownButton<DashboardWidgetSize>(
              value: item.size,
              underline: const SizedBox.shrink(),
              isDense: true,
              items: DashboardWidgetSize.values
                  .map(
                    (size) => DropdownMenuItem(
                      value: size,
                      child: Text(switch (size) {
                        DashboardWidgetSize.small => 'Compatto',
                        DashboardWidgetSize.medium => 'Medio',
                        DashboardWidgetSize.large => 'Grande',
                      }),
                    ),
                  )
                  .toList(),
              onChanged: (size) async {
                if (size == null) return;
                setState(() {
                  items![index] = DashboardWidgetConfig(
                    type: item.type,
                    enabled: item.enabled,
                    orderIndex: item.orderIndex,
                    size: size,
                  );
                });
                await _save(state);
              },
            ),
            trailing: Switch(
              value: item.enabled,
              onChanged: (enabled) async {
                setState(() {
                  items![index] = DashboardWidgetConfig(
                    type: item.type,
                    enabled: enabled,
                    orderIndex: item.orderIndex,
                    size: item.size,
                  );
                });
                await _save(state);
              },
            ),
          );
        },
      ),
    );
  }
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  Future<void> _delete(BuildContext context, AppState state, Category item) async {
    final count = state.transactionCountForCategory(item.id);
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Eliminare “${item.name}”?',
      message: '$count riferimenti usano questa categoria. I movimenti non verranno cancellati: resteranno senza categoria. Gli split che usano la categoria devono essere modificati prima della rimozione.',
    );
    if (!confirmed) return;
    try {
      await state.deleteCategory(item);
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Categoria non eliminata: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorie'),
        actions: [
          IconButton(
            tooltip: 'Nuova categoria',
            onPressed: () => showCategoryCreator(context, state),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          _CategoryGroup(
            title: 'Spese',
            items: state.categoriesFor(TransactionType.expense),
            onEdit: (item) => showCategoryEditor(context, item),
            onDelete: (item) => _delete(context, state, item),
          ),
          const SizedBox(height: 28),
          _CategoryGroup(
            title: 'Entrate',
            items: state.categoriesFor(TransactionType.income),
            onEdit: (item) => showCategoryEditor(context, item),
            onDelete: (item) => _delete(context, state, item),
          ),
        ],
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({required this.title, required this.items, required this.onEdit, required this.onDelete});
  final String title;
  final List<Category> items;
  final ValueChanged<Category> onEdit;
  final ValueChanged<Category> onDelete;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title, trailing: Text('${items.length}')),
          if (items.isEmpty)
            const Text('Nessuna categoria')
          else
            ...items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Color(item.colorValue).withValues(alpha: .13),
                  child: Icon(categoryIcon(item.iconKey), color: Color(item.colorValue)),
                ),
                title: Text(item.name),
                subtitle: Text('${item.type.label} · ${item.quickOrder == null ? 'standard' : 'rapida'}'),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Azioni categoria',
                  onSelected: (value) {
                    if (value == 'edit') onEdit(item);
                    if (value == 'delete') onDelete(item);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Modifica')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Elimina', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
}

Future<void> showCategoryEditor(BuildContext context, Category existing) async {
  final state = AppScope.of(context);
  final name = TextEditingController(text: existing.name);
  var iconKey = existing.iconKey;
  var color = Color(existing.colorValue);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Modifica categoria', style: Theme.of(context).textTheme.titleLarge),
              TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nome')),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(categoryIcon(iconKey), color: color),
                title: const Text('Icona'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final picked = await showIconPicker(context, options: categoryIconOptions, selected: iconKey);
                  if (picked != null) setSheetState(() => iconKey = picked);
                },
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categoryPalette
                    .map(
                      (item) => InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setSheetState(() => color = item),
                        child: SizedBox.square(
                          dimension: 44,
                          child: Center(
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(color: item, shape: BoxShape.circle),
                              child: item == color ? const Icon(Icons.check_rounded, size: 17, color: Colors.white) : null,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (name.text.trim().isEmpty) return;
                    await state.updateCategory(
                      Category(
                        id: existing.id,
                        name: name.text.trim(),
                        iconKey: iconKey,
                        colorValue: color.toARGB32(),
                        type: existing.type,
                        quickOrder: existing.quickOrder,
                      ),
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Salva modifiche'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  name.dispose();
}

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regole automatiche'),
        actions: [
          IconButton(
            tooltip: 'Nuova regola',
            onPressed: () => showRuleEditor(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Text(
            'Le regole vengono applicate ai nuovi movimenti e alle importazioni quando le condizioni corrispondono.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 22),
          if (state.rules.isEmpty)
            EmptyState(
              icon: Icons.auto_fix_high_outlined,
              title: 'Nessuna regola',
              subtitle: 'Esempio: se la nota contiene LIDL, assegna Alimentari e il tag Spesa.',
              action: FilledButton.icon(
                onPressed: () => showRuleEditor(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crea regola'),
              ),
            )
          else
            ...state.rules.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                minVerticalPadding: 12,
                leading: Icon(item.enabled ? Icons.auto_fix_high_rounded : Icons.pause_circle_outline_rounded),
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(_ruleSummary(state, item)),
                trailing: IconButton(
                  tooltip: 'Elimina regola',
                  onPressed: () async {
                    final ok = await confirmDestructiveAction(
                      context,
                      title: 'Eliminare “${item.name}”?',
                      message: 'I movimenti già classificati non verranno modificati.',
                    );
                    if (ok) await state.deleteRule(item);
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _ruleSummary(AppState state, AutomationRule item) {
  final conditions = <String>[];
  if (item.containsText?.isNotEmpty == true) conditions.add('testo “${item.containsText}”');
  if (item.type != null) conditions.add(item.type!.label);
  if (item.minAmount != null) conditions.add('≥ ${moneyFor(state, item.minAmount!)}');
  if (item.maxAmount != null) conditions.add('≤ ${moneyFor(state, item.maxAmount!)}');
  final actions = <String>[];
  final category = state.categoryById(item.categoryId);
  final account = state.accountById(item.accountId);
  if (category != null) actions.add('categoria ${category.name}');
  if (account != null) actions.add('conto ${account.name}');
  if (item.addTag?.isNotEmpty == true) actions.add('#${item.addTag}');
  if (item.includeInAnalytics != null) actions.add(item.includeInAnalytics! ? 'includi statistiche' : 'escludi statistiche');
  return '${conditions.isEmpty ? 'Qualsiasi movimento' : conditions.join(' · ')} → ${actions.isEmpty ? 'nessuna azione' : actions.join(' · ')}';
}

Future<void> showRuleEditor(BuildContext context) async {
  final state = AppScope.of(context);
  final name = TextEditingController();
  final contains = TextEditingController();
  final min = TextEditingController();
  final max = TextEditingController();
  final tag = TextEditingController();
  TransactionType? type;
  int? categoryId;
  int? accountId;
  bool? includeInAnalytics;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nuova regola', style: Theme.of(context).textTheme.titleLarge),
              TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nome regola')),
              TextField(controller: contains, decoration: const InputDecoration(labelText: 'Nota contiene', hintText: 'Es. LIDL')),
              DropdownButtonFormField<TransactionType?>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Tipo opzionale'),
                items: [
                  const DropdownMenuItem<TransactionType?>(value: null, child: Text('Qualsiasi tipo')),
                  ...TransactionType.values.map((item) => DropdownMenuItem<TransactionType?>(value: item, child: Text(item.label))),
                ],
                onChanged: (value) => setSheetState(() {
                  type = value;
                  categoryId = null;
                }),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: min,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Importo min.'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: max,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Importo max.'),
                    ),
                  ),
                ],
              ),
              DropdownButtonFormField<int?>(
                initialValue: categoryId,
                decoration: const InputDecoration(labelText: 'Assegna categoria'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Non cambiare categoria')),
                  ...state.categories
                      .where((item) => type == null || type == TransactionType.transfer || item.type == type)
                      .map((item) => DropdownMenuItem<int?>(value: item.id, child: Text(item.name))),
                ],
                onChanged: (value) => categoryId = value,
              ),
              DropdownButtonFormField<int?>(
                initialValue: accountId,
                decoration: const InputDecoration(labelText: 'Assegna conto'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Non cambiare conto')),
                  ...state.activeAccounts
                      .where((item) => !item.isLocked)
                      .map((item) => DropdownMenuItem<int?>(value: item.id, child: Text(item.name))),
                ],
                onChanged: (value) => accountId = value,
              ),
              TextField(controller: tag, decoration: const InputDecoration(labelText: 'Aggiungi tag opzionale')),
              DropdownButtonFormField<bool?>(
                initialValue: includeInAnalytics,
                decoration: const InputDecoration(labelText: 'Statistiche'),
                items: const [
                  DropdownMenuItem<bool?>(value: null, child: Text('Non cambiare')),
                  DropdownMenuItem<bool?>(value: true, child: Text('Includi')),
                  DropdownMenuItem<bool?>(value: false, child: Text('Escludi')),
                ],
                onChanged: (value) => includeInAnalytics = value,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final minValue = min.text.trim().isEmpty ? null : double.tryParse(min.text.replaceAll(',', '.'));
                    final maxValue = max.text.trim().isEmpty ? null : double.tryParse(max.text.replaceAll(',', '.'));
                    if (name.text.trim().isEmpty) return;
                    if (min.text.trim().isNotEmpty && minValue == null) return;
                    if (max.text.trim().isNotEmpty && maxValue == null) return;
                    if (minValue != null && maxValue != null && minValue > maxValue) return;
                    await state.addRule(
                      AutomationRule(
                        id: 0,
                        name: name.text.trim(),
                        enabled: true,
                        containsText: contains.text.trim().isEmpty ? null : contains.text.trim(),
                        type: type,
                        minAmount: minValue,
                        maxAmount: maxValue,
                        categoryId: type == TransactionType.transfer ? null : categoryId,
                        accountId: accountId,
                        addTag: tag.text.trim().isEmpty ? null : tag.text.trim(),
                        includeInAnalytics: includeInAnalytics,
                      ),
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Crea regola'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  name.dispose();
  contains.dispose();
  min.dispose();
  max.dispose();
  tag.dispose();
}

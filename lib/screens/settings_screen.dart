import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../app_state.dart';
import '../main.dart';
import '../models/models.dart';
import '../models/smart_models.dart';
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
          _SettingsLink(
            icon: Icons.contrast_rounded,
            title: 'Tema',
            subtitle: _themeLabel(state.themePreference),
            onTap: () => _pickTheme(context, state),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.visibility_off_outlined),
            title: const Text('Nascondi saldi'),
            subtitle: const Text(
              'Nasconde gli importi sensibili anche nei widget Android.',
            ),
            value: state.hideBalance,
            onChanged: state.setHideBalance,
          ),
          const SizedBox(height: 32),
          const SectionTitle('Generali'),
          _SettingsLink(
            icon: Icons.euro_rounded,
            title: 'Valuta principale',
            subtitle: state.currency,
            onTap: () => _pickCurrency(context, state),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.pin_outlined),
            title: const Text('Mostra centesimi'),
            value: state.showCents,
            onChanged: (value) =>
                state.setSetting('show_cents', value ? '1' : '0'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.vibration_rounded),
            title: const Text('Feedback aptico'),
            value: state.haptics,
            onChanged: (value) =>
                state.setSetting('haptics', value ? '1' : '0'),
          ),
          _SettingsLink(
            icon: Icons.calendar_view_week_outlined,
            title: 'Primo giorno settimana',
            subtitle: state.weekStart == 7 ? 'Domenica' : 'Lunedì',
            onTap: () => _pickWeekStart(context, state),
          ),
          _SettingsLink(
            icon: Icons.calendar_month_outlined,
            title: 'Inizio mese finanziario',
            subtitle: 'Giorno ${state.financialMonthStart}',
            onTap: () => _pickFinancialMonthStart(context, state),
          ),
          const SizedBox(height: 32),
          const SectionTitle('Movimenti'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.help_outline_rounded),
            title: const Text('Permetti “Non assegnato”'),
            subtitle: const Text(
              'Registra subito e assegna il conto in un secondo momento.',
            ),
            value: state.allowUnassigned,
            onChanged: (value) =>
                state.setSetting('allow_unassigned', value ? '1' : '0'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.swap_horiz_rounded),
            title: const Text('Trasferimenti nelle statistiche'),
            subtitle: const Text(
              'Disattivato evita di gonfiare entrate e spese.',
            ),
            value: state.showTransfersInAnalytics,
            onChanged: (value) =>
                state.setSetting('show_transfers_analytics', value ? '1' : '0'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.warning_amber_rounded),
            title: const Text('Conferma eliminazioni'),
            value: state.confirmDelete,
            onChanged: (value) =>
                state.setSetting('confirm_delete', value ? '1' : '0'),
          ),
          const SizedBox(height: 32),
          const SectionTitle('Smart Finance'),
          _SettingsLink(
            icon: Icons.bolt_outlined,
            title: 'Smart Suggestions',
            subtitle: state.smartSuggestionsEnabled
                ? '${state.learnedPatterns.length} pattern appresi · ${_sensitivityLabel(state.smartSensitivity)}'
                : 'Disattivate',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SmartSuggestionsSettingsScreen(),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const SectionTitle('Organizzazione'),
          _SettingsLink(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Conti',
            subtitle: '${state.userAccounts.length} conti',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountsScreen()),
            ),
          ),
          _SettingsLink(
            icon: Icons.category_outlined,
            title: 'Categorie',
            subtitle: '${state.categories.length} categorie',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
            ),
          ),
          _SettingsLink(
            icon: Icons.dashboard_customize_outlined,
            title: 'Dashboard',
            subtitle: 'Mostra, nascondi, ridimensiona e riordina widget',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DashboardCustomizerScreen(),
              ),
            ),
          ),
          _SettingsLink(
            icon: Icons.auto_fix_high_outlined,
            title: 'Regole automatiche',
            subtitle: '${state.rules.length} regole manuali',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RulesScreen()),
            ),
          ),
          const SizedBox(height: 32),
          const SectionTitle('Privacy'),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.phonelink_lock_outlined),
            title: Text('Dati locali sul dispositivo'),
            subtitle: Text(
              'Movimenti, descrizioni, pattern e obiettivi non vengono inviati a servizi esterni.',
            ),
          ),
          const SizedBox(height: 32),
          const SectionTitle('Dati'),
          _SettingsLink(
            icon: Icons.file_download_outlined,
            title: 'Esporta CSV',
            subtitle: 'Esporta i movimenti in formato interoperabile',
            onTap: () => _exportCsv(context, state),
          ),
          _SettingsLink(
            icon: Icons.file_upload_outlined,
            title: 'Importa CSV',
            subtitle: 'Importa e aggiorna anche l’apprendimento locale',
            onTap: () => _importCsv(context, state),
          ),
          _SettingsLink(
            icon: Icons.backup_outlined,
            title: 'Backup database',
            subtitle: 'Include anche pattern e preferenze Smart Finance',
            onTap: () => _backup(context, state),
          ),
          _SettingsLink(
            icon: Icons.settings_backup_restore_rounded,
            title: 'Ripristina backup',
            subtitle: 'Sostituisce il database corrente con un backup',
            onTap: () => _restore(context, state),
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
            subtitle: const Text(
              'Rimuove definitivamente tutti i dati finanziari locali.',
            ),
            onTap: () => _clearAll(context, state),
          ),
        ],
      ),
    );
  }
}

class _SettingsLink extends StatelessWidget {
  const _SettingsLink({
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

class SmartSuggestionsSettingsScreen extends StatelessWidget {
  const SmartSuggestionsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Suggestions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Text(
            'Il sistema riconosce abitudini con statistiche locali e regole spiegabili. Non usa IA né cloud.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.bolt_rounded),
            title: const Text('Suggerimenti automatici'),
            subtitle: const Text(
              'Mostra “Completa” solo quando la confidenza è sufficiente.',
            ),
            value: state.smartSuggestionsEnabled,
            onChanged: (value) => state.setSetting(
              'smart_suggestions_enabled',
              value ? '1' : '0',
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Segnali'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Usa descrizione'),
            subtitle: const Text('È il segnale principale del modello locale.'),
            value: state.smartUseDescription,
            onChanged: state.smartSuggestionsEnabled
                ? (value) => state.setSetting(
                    'smart_use_description',
                    value ? '1' : '0',
                  )
                : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Usa importo'),
            subtitle: const Text(
              'Rafforza pattern con fasce di importo simili.',
            ),
            value: state.smartUseAmount,
            onChanged: state.smartSuggestionsEnabled
                ? (value) =>
                      state.setSetting('smart_use_amount', value ? '1' : '0')
                : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Usa giorno e orario'),
            subtitle: const Text(
              'Segnali deboli: rafforzano una previsione, non la creano da soli.',
            ),
            value: state.smartUseTime,
            onChanged: state.smartSuggestionsEnabled
                ? (value) =>
                      state.setSetting('smart_use_time', value ? '1' : '0')
                : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Rileva ricorrenze'),
            subtitle: const Text(
              'Propone di configurare pattern settimanali, mensili o annuali.',
            ),
            value: state.smartDetectRecurring,
            onChanged: state.smartSuggestionsEnabled
                ? (value) => state.setSetting(
                    'smart_detect_recurring',
                    value ? '1' : '0',
                  )
                : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Suggerimenti obiettivi'),
            subtitle: const Text(
              'Calcola un ritmo realistico usando il tuo cash-flow storico.',
            ),
            value: state.smartGoalSuggestions,
            onChanged: state.smartSuggestionsEnabled
                ? (value) => state.setSetting(
                    'smart_goal_suggestions',
                    value ? '1' : '0',
                  )
                : null,
          ),
          const SizedBox(height: 24),
          _SettingsLink(
            icon: Icons.tune_rounded,
            title: 'Sensibilità',
            subtitle: _sensitivityLabel(state.smartSensitivity),
            onTap: () => _pickSensitivity(context, state),
          ),
          _SettingsLink(
            icon: Icons.manage_search_rounded,
            title: 'Gestisci apprendimento',
            subtitle:
                '${state.learnedPatterns.length} pattern · ${state.detectedRecurringPatterns.length} ricorrenze rilevate',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LearningManagementScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _sensitivityLabel(SmartSensitivity value) => switch (value) {
  SmartSensitivity.conservative => 'Conservativa',
  SmartSensitivity.balanced => 'Bilanciata',
  SmartSensitivity.proactive => 'Proattiva',
};

Future<void> _pickSensitivity(BuildContext context, AppState state) async {
  final result = await showModalBottomSheet<SmartSensitivity>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sensibilità', style: Theme.of(context).textTheme.titleLarge),
          ...SmartSensitivity.values.map(
            (item) => RadioListTile<SmartSensitivity>(
              contentPadding: EdgeInsets.zero,
              value: item,
              groupValue: state.smartSensitivity,
              title: Text(_sensitivityLabel(item)),
              subtitle: Text(switch (item) {
                SmartSensitivity.conservative =>
                  'Richiede più esempi e una confidenza più alta.',
                SmartSensitivity.balanced =>
                  'Equilibrio tra utilità e prudenza. Consigliata.',
                SmartSensitivity.proactive =>
                  'Mostra prima i pattern, mantenendo sempre la conferma.',
              }),
              onChanged: (value) => Navigator.pop(context, value),
            ),
          ),
        ],
      ),
    ),
  );
  if (result != null) {
    await state.setSetting('smart_sensitivity', result.name);
  }
}

class LearningManagementScreen extends StatelessWidget {
  const LearningManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apprendimento'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Azioni apprendimento',
            onSelected: (value) async {
              if (value == 'clear') {
                final confirmed = await confirmDestructiveAction(
                  context,
                  title: 'Cancellare l’apprendimento?',
                  message:
                      'Pattern, feedback e soppressioni verranno eliminati. I movimenti resteranno invariati e il sistema potrà imparare di nuovo.',
                  confirmLabel: 'Cancella apprendimento',
                );
                if (confirmed) await state.clearLearning();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear',
                child: Text(
                  'Cancella apprendimento',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Text(
            'I pattern sono ricavati dai tuoi movimenti. Puoi disattivarli, convertirli in regole esplicite o eliminarli senza modificare lo storico.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          if (state.learnedPatterns.isEmpty)
            const EmptyState(
              icon: Icons.school_outlined,
              title: 'Nessun pattern ancora',
              subtitle:
                  'Dopo alcuni movimenti coerenti compariranno qui le abitudini riconosciute.',
            )
          else
            ...state.learnedPatterns.map((pattern) {
              final category = state.categoryById(pattern.categoryId);
              final account = state.accountById(pattern.accountId);
              return Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      pattern.enabled
                          ? Icons.auto_awesome_rounded
                          : Icons.visibility_off_outlined,
                    ),
                    title: Text(
                      pattern.normalizedText,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      [
                        '${pattern.sampleCount} esempi',
                        if (category != null) category.name,
                        if (account != null && !account.isSystem) account.name,
                        if (pattern.acceptedCount > 0)
                          '${pattern.acceptedCount} accettati',
                        if (pattern.rejectedCount > 0)
                          '${pattern.rejectedCount} rifiutati',
                      ].join(' · '),
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Azioni pattern',
                      onSelected: (value) async {
                        if (value == 'toggle') {
                          await state.setPatternEnabled(
                            pattern,
                            !pattern.enabled,
                          );
                        } else if (value == 'rule') {
                          await state.convertPatternToRule(pattern);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Regola manuale creata.'),
                              ),
                            );
                          }
                        } else if (value == 'delete') {
                          await state.deleteLearnedPattern(pattern);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(pattern.enabled ? 'Disattiva' : 'Attiva'),
                        ),
                        const PopupMenuItem(
                          value: 'rule',
                          child: Text('Converti in regola'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Elimina pattern',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
              );
            }),
        ],
      ),
    );
  }
}

String _themeLabel(AppThemePreference value) => switch (value) {
  AppThemePreference.system => 'Automatico',
  AppThemePreference.light => 'Chiaro',
  AppThemePreference.dark => 'Scuro',
};

Future<void> _pickTheme(BuildContext context, AppState state) async {
  final result = await showModalBottomSheet<AppThemePreference>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: AppThemePreference.values
            .map(
              (item) => RadioListTile<AppThemePreference>(
                contentPadding: EdgeInsets.zero,
                value: item,
                groupValue: state.themePreference,
                title: Text(_themeLabel(item)),
                onChanged: (value) => Navigator.pop(context, value),
              ),
            )
            .toList(),
      ),
    ),
  );
  if (result != null) await state.setThemePreference(result);
}

Future<void> _pickCurrency(BuildContext context, AppState state) async {
  const currencies = ['EUR', 'USD', 'GBP', 'CHF'];
  final result = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: currencies
            .map(
              (item) => RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: item,
                groupValue: state.currency,
                title: Text(item),
                onChanged: (value) => Navigator.pop(context, value),
              ),
            )
            .toList(),
      ),
    ),
  );
  if (result != null) await state.setSetting('currency', result);
}

Future<void> _pickWeekStart(BuildContext context, AppState state) async {
  final result = await showModalBottomSheet<int>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
  if (result != null) await state.setSetting('week_start', result.toString());
}

Future<void> _pickFinancialMonthStart(
  BuildContext context,
  AppState state,
) async {
  var value = state.financialMonthStart.clamp(1, 28).toInt();
  final result = await showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Inizio mese finanziario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Giorno $value',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Slider(
              min: 1,
              max: 28,
              divisions: 27,
              value: value.toDouble(),
              label: '$value',
              onChanged: (next) => setDialogState(() => value = next.round()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, value),
            child: const Text('Salva'),
          ),
        ],
      ),
    ),
  );
  if (result != null) {
    await state.setSetting('financial_month_start', result.toString());
  }
}

Future<void> _exportCsv(BuildContext context, AppState state) async {
  try {
    final csv = await state.exportCsv();
    final output = await FilePicker.saveFile(
      dialogTitle: 'Esporta movimenti',
      fileName:
          'dadafinanza-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );
    if (context.mounted && output != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('CSV esportato.')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Esportazione non riuscita: $error')),
      );
    }
  }
}

Future<void> _importCsv(BuildContext context, AppState state) async {
  try {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (file == null) return;
    final count = await state.importCsv(utf8.decode(await file.readAsBytes()));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$count movimenti importati.')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Importazione non riuscita: $error')),
      );
    }
  }
}

Future<void> _backup(BuildContext context, AppState state) async {
  try {
    final bytes = await File(await state.databaseFilePath()).readAsBytes();
    final output = await FilePicker.saveFile(
      dialogTitle: 'Salva backup DadaFinanza',
      fileName:
          'dadafinanza-backup-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.db',
      type: FileType.custom,
      allowedExtensions: const ['db'],
      bytes: bytes,
    );
    if (context.mounted && output != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Backup salvato.')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup non riuscito: $error')));
    }
  }
}

Future<void> _restore(BuildContext context, AppState state) async {
  try {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['db'],
    );
    if (picked == null || !context.mounted) return;
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Ripristinare questo backup?',
      message:
          'Il database corrente verrà sostituito completamente. Crea prima un backup se vuoi conservarlo.',
      confirmLabel: 'Ripristina',
    );
    if (!confirmed) return;
    final temp = await getTemporaryDirectory();
    final source = File('${temp.path}/dadafinanza-restore.db');
    await source.writeAsBytes(await picked.readAsBytes(), flush: true);
    await state.restoreDatabaseFrom(source.path);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Backup ripristinato.')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ripristino non riuscito: $error')),
      );
    }
  }
}

Future<void> _clearAll(BuildContext context, AppState state) async {
  final confirmed = await confirmDestructiveAction(
    context,
    title: 'Cancellare tutti i dati?',
    message:
        'Verranno rimossi conti, movimenti, categorie, budget, obiettivi, ricorrenti, regole e apprendimento locale.',
    confirmLabel: 'Cancella definitivamente',
  );
  if (!confirmed) return;
  await state.clearAllUserData();
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Dati cancellati.')));
  }
}

class DashboardCustomizerScreen extends StatefulWidget {
  const DashboardCustomizerScreen({super.key});

  @override
  State<DashboardCustomizerScreen> createState() =>
      _DashboardCustomizerScreenState();
}

class _DashboardCustomizerScreenState extends State<DashboardCustomizerScreen> {
  List<DashboardWidgetConfig>? items;

  void _load(AppState state) {
    items ??= [...state.dashboardWidgets]
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
    _load(state);
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
        onReorderItem: (oldIndex, newIndex) async {
          setState(() {
            final item = items!.removeAt(oldIndex);
            items!.insert(newIndex, item);
          });
          await _save(state);
        },
        itemBuilder: (context, index) {
          final item = items![index];
          return ListTile(
            key: ValueKey(item.type),
            leading: const Icon(Icons.drag_handle_rounded),
            title: Text(item.type.label),
            subtitle: DropdownButton<DashboardWidgetSize>(
              value: item.size,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: DashboardWidgetSize.values
                  .map(
                    (size) => DropdownMenuItem(
                      value: size,
                      child: Text(_sizeLabel(size)),
                    ),
                  )
                  .toList(),
              onChanged: (size) async {
                if (size == null) return;
                setState(
                  () => items![index] = DashboardWidgetConfig(
                    type: item.type,
                    enabled: item.enabled,
                    orderIndex: item.orderIndex,
                    size: size,
                  ),
                );
                await _save(state);
              },
            ),
            trailing: Switch(
              value: item.enabled,
              onChanged: (enabled) async {
                setState(
                  () => items![index] = DashboardWidgetConfig(
                    type: item.type,
                    enabled: enabled,
                    orderIndex: item.orderIndex,
                    size: item.size,
                  ),
                );
                await _save(state);
              },
            ),
          );
        },
      ),
    );
  }
}

String _sizeLabel(DashboardWidgetSize size) => switch (size) {
  DashboardWidgetSize.small => 'Compatto',
  DashboardWidgetSize.medium => 'Medio',
  DashboardWidgetSize.large => 'Grande',
};

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  Future<void> _delete(
    BuildContext context,
    AppState state,
    Category category,
  ) async {
    final references = state.transactionCountForCategory(category.id);
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Eliminare “${category.name}”?',
      message:
          '$references riferimenti usano questa categoria. I movimenti resteranno disponibili.',
    );
    if (confirmed) await state.deleteCategory(category);
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
          _CategorySection(
            title: 'Spese',
            items: state.categoriesFor(TransactionType.expense),
            onEdit: (item) => _editCategory(context, state, item),
            onDelete: (item) => _delete(context, state, item),
          ),
          const SizedBox(height: 32),
          _CategorySection(
            title: 'Entrate',
            items: state.categoriesFor(TransactionType.income),
            onEdit: (item) => _editCategory(context, state, item),
            onDelete: (item) => _delete(context, state, item),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

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
              child: Icon(
                categoryIcon(item.iconKey),
                color: Color(item.colorValue),
              ),
            ),
            title: Text(item.name),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit(item);
                if (value == 'delete') onDelete(item);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Modifica')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Elimina',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

Future<void> _editCategory(
  BuildContext context,
  AppState state,
  Category existing,
) async {
  final name = TextEditingController(text: existing.name);
  var iconKey = existing.iconKey;
  var color = Color(existing.colorValue);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(categoryIcon(iconKey), color: color),
                title: const Text('Icona'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final picked = await showIconPicker(
                    context,
                    options: categoryIconOptions,
                    selected: iconKey,
                  );
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
                              decoration: BoxDecoration(
                                color: item,
                                shape: BoxShape.circle,
                              ),
                              child: item == color
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 17,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
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
            onPressed: () => _addRule(context, state),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Text(
            'Le regole manuali hanno precedenza sui pattern appresi e possono classificare direttamente i nuovi movimenti.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          if (state.rules.isEmpty)
            EmptyState(
              icon: Icons.auto_fix_high_outlined,
              title: 'Nessuna regola',
              subtitle: 'Esempio: descrizione contiene LIDL → Alimentari.',
              action: FilledButton.icon(
                onPressed: () => _addRule(context, state),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crea regola'),
              ),
            )
          else
            ...state.rules.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_fix_high_rounded),
                title: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(_ruleSummary(state, item)),
                trailing: IconButton(
                  tooltip: 'Elimina regola',
                  onPressed: () async {
                    final confirmed = await confirmDestructiveAction(
                      context,
                      title: 'Eliminare “${item.name}”?',
                      message:
                          'I movimenti già classificati non verranno modificati.',
                    );
                    if (confirmed) await state.deleteRule(item);
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

String _ruleSummary(AppState state, AutomationRule rule) {
  final conditions = <String>[];
  if (rule.containsText?.isNotEmpty == true) {
    conditions.add('“${rule.containsText}”');
  }
  if (rule.type != null) conditions.add(rule.type!.label);
  if (rule.minAmount != null) {
    conditions.add('≥ ${moneyFor(state, rule.minAmount!)}');
  }
  if (rule.maxAmount != null) {
    conditions.add('≤ ${moneyFor(state, rule.maxAmount!)}');
  }
  final actions = <String>[];
  final category = state.categoryById(rule.categoryId);
  final account = state.accountById(rule.accountId);
  if (category != null) actions.add(category.name);
  if (account != null) actions.add(account.name);
  if (rule.addTag?.isNotEmpty == true) actions.add('#${rule.addTag}');
  return '${conditions.isEmpty ? 'Qualsiasi' : conditions.join(' · ')} → ${actions.isEmpty ? 'regola statistiche' : actions.join(' · ')}';
}

Future<void> _addRule(BuildContext context, AppState state) async {
  final name = TextEditingController();
  final contains = TextEditingController();
  final min = TextEditingController();
  final max = TextEditingController();
  final tag = TextEditingController();
  TransactionType? type;
  int? categoryId;
  int? accountId;
  bool? analytics;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nuova regola',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              TextField(
                controller: contains,
                decoration: const InputDecoration(
                  labelText: 'Descrizione contiene',
                  hintText: 'Es. LIDL',
                ),
              ),
              DropdownButtonFormField<TransactionType?>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Tipo opzionale'),
                items: [
                  const DropdownMenuItem<TransactionType?>(
                    value: null,
                    child: Text('Qualsiasi tipo'),
                  ),
                  ...TransactionType.values.map(
                    (item) => DropdownMenuItem<TransactionType?>(
                      value: item,
                      child: Text(item.label),
                    ),
                  ),
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
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Importo min.',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: max,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Importo max.',
                      ),
                    ),
                  ),
                ],
              ),
              DropdownButtonFormField<int?>(
                initialValue: categoryId,
                decoration: const InputDecoration(
                  labelText: 'Assegna categoria',
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Non cambiare'),
                  ),
                  ...state.categories
                      .where(
                        (item) =>
                            type == null ||
                            type == TransactionType.transfer ||
                            item.type == type,
                      )
                      .map(
                        (item) => DropdownMenuItem<int?>(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      ),
                ],
                onChanged: (value) => categoryId = value,
              ),
              DropdownButtonFormField<int?>(
                initialValue: accountId,
                decoration: const InputDecoration(labelText: 'Assegna conto'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Non cambiare'),
                  ),
                  ...state.activeAccounts
                      .where((item) => !item.isLocked)
                      .map(
                        (item) => DropdownMenuItem<int?>(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      ),
                ],
                onChanged: (value) => accountId = value,
              ),
              TextField(
                controller: tag,
                decoration: const InputDecoration(
                  labelText: 'Aggiungi tag opzionale',
                ),
              ),
              DropdownButtonFormField<bool?>(
                initialValue: analytics,
                decoration: const InputDecoration(labelText: 'Statistiche'),
                items: const [
                  DropdownMenuItem<bool?>(
                    value: null,
                    child: Text('Non cambiare'),
                  ),
                  DropdownMenuItem<bool?>(value: true, child: Text('Includi')),
                  DropdownMenuItem<bool?>(value: false, child: Text('Escludi')),
                ],
                onChanged: (value) => analytics = value,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final minValue = min.text.trim().isEmpty
                        ? null
                        : double.tryParse(min.text.replaceAll(',', '.'));
                    final maxValue = max.text.trim().isEmpty
                        ? null
                        : double.tryParse(max.text.replaceAll(',', '.'));
                    if (name.text.trim().isEmpty ||
                        (min.text.trim().isNotEmpty && minValue == null) ||
                        (max.text.trim().isNotEmpty && maxValue == null) ||
                        (minValue != null &&
                            maxValue != null &&
                            minValue > maxValue)) {
                      return;
                    }
                    await state.addRule(
                      AutomationRule(
                        id: 0,
                        name: name.text.trim(),
                        enabled: true,
                        containsText: contains.text.trim().isEmpty
                            ? null
                            : contains.text.trim(),
                        type: type,
                        minAmount: minValue,
                        maxAmount: maxValue,
                        categoryId: type == TransactionType.transfer
                            ? null
                            : categoryId,
                        accountId: accountId,
                        addTag: tag.text.trim().isEmpty
                            ? null
                            : tag.text.trim(),
                        includeInAnalytics: analytics,
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

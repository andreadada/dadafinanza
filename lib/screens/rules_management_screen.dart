import 'package:flutter/material.dart';

import '../app_state.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/rule_service.dart';
import '../widgets/ui_helpers.dart';

class RulesManagementScreen extends StatefulWidget {
  const RulesManagementScreen({super.key});

  @override
  State<RulesManagementScreen> createState() => _RulesManagementScreenState();
}

class _RulesManagementScreenState extends State<RulesManagementScreen> {
  final service = const RuleService();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final rules = [...state.rules]
      ..sort((a, b) {
        final p = b.priority.compareTo(a.priority);
        return p != 0 ? p : a.id.compareTo(b.id);
      });
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regole automatiche'),
        actions: [
          IconButton(
            tooltip: 'Nuova regola',
            onPressed: () => _edit(context, state),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: rules.isEmpty
          ? EmptyState(
              icon: Icons.auto_fix_high_outlined,
              title: 'Nessuna regola',
              subtitle: 'Esempio: descrizione contiene LIDL → Alimentari.',
              action: FilledButton.icon(
                onPressed: () => _edit(context, state),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crea regola'),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount: rules.length,
              onReorderItem: (oldIndex, newIndex) async {
                if (newIndex > oldIndex) newIndex--;
                final moved = rules.removeAt(oldIndex);
                rules.insert(newIndex, moved);
                await service.reorder(state, rules);
                if (mounted) setState(() {});
              },
              itemBuilder: (context, index) {
                final rule = rules[index];
                final preview = service.preview(state, rule);
                return ListTile(
                  key: ValueKey(rule.id),
                  contentPadding: EdgeInsets.zero,
                  minVerticalPadding: 12,
                  leading: const Icon(Icons.drag_handle_rounded),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          rule.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (!rule.enabled)
                        Text(
                          'Disattiva',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                    ],
                  ),
                  subtitle: Text(
                    '${_summary(state, rule)}\n${preview.count} movimenti corrispondenti',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Azioni regola',
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _edit(context, state, existing: rule);
                      } else if (value == 'toggle') {
                        await service.update(
                          state,
                          rule.copyWith(enabled: !rule.enabled),
                        );
                      } else if (value == 'duplicate') {
                        await service.duplicate(state, rule);
                      } else if (value == 'test' && context.mounted) {
                        await _testRule(context, state, rule);
                      } else if (value == 'delete' && context.mounted) {
                        final confirmed = await confirmDestructiveAction(
                          context,
                          title: 'Eliminare “${rule.name}”?',
                          message:
                              'I movimenti già classificati non cambieranno.',
                        );
                        if (confirmed) await state.deleteRule(rule);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Modifica'),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(rule.enabled ? 'Disattiva' : 'Attiva'),
                      ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Text('Duplica'),
                      ),
                      const PopupMenuItem(
                        value: 'test',
                        child: Text('Prova regola'),
                      ),
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
                  onTap: () => _testRule(context, state, rule),
                );
              },
            ),
    );
  }

  String _summary(AppState state, AutomationRule rule) {
    final conditions = <String>[];
    if (rule.containsText?.isNotEmpty == true) {
      conditions.add('“${rule.containsText}”');
    }
    if (rule.type != null) conditions.add(rule.type!.label);
    if (rule.minAmount != null)
      conditions.add('≥ ${moneyFor(state, rule.minAmount!)}');
    if (rule.maxAmount != null)
      conditions.add('≤ ${moneyFor(state, rule.maxAmount!)}');
    final actions = <String>[];
    final category = state.categoryById(rule.categoryId);
    final account = state.accountById(rule.accountId);
    if (category != null) actions.add(category.name);
    if (account != null) actions.add(account.name);
    if (rule.addTag?.isNotEmpty == true) actions.add('#${rule.addTag}');
    return '${conditions.isEmpty ? 'Qualsiasi' : conditions.join(' · ')} → ${actions.isEmpty ? 'statistiche' : actions.join(' · ')}';
  }

  Future<void> _testRule(
    BuildContext context,
    AppState state,
    AutomationRule rule,
  ) async {
    final preview = service.preview(state, rule);
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
              'Prova regola',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              preview.count == 1
                  ? 'Questa regola corrisponde a 1 movimento.'
                  : 'Questa regola corrisponde a ${preview.count} movimenti.',
            ),
            const SizedBox(height: 12),
            ...preview.matches
                .take(4)
                .map(
                  (item) => FlatMetric(
                    label: item.note ?? item.type.label,
                    value: moneyFor(state, item.amount),
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
            if (preview.count > 4)
              Text(
                '+ ${preview.count - 4} altri',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    child: const Text('Chiudi'),
                  ),
                ),
                if (preview.count > 0)
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('Applica allo storico'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (result != true || !context.mounted) return;
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Applicare allo storico?',
      message:
          'La regola aggiornerà ${preview.count} movimenti corrispondenti. I saldi vengono ricalcolati se cambia il conto.',
      confirmLabel: 'Applica',
    );
    if (!confirmed) return;
    final changed = await service.applyToHistory(state, rule);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$changed movimenti aggiornati.')));
    }
  }

  Future<void> _edit(
    BuildContext context,
    AppState state, {
    AutomationRule? existing,
  }) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final contains = TextEditingController(text: existing?.containsText ?? '');
    final min = TextEditingController(
      text: existing?.minAmount?.toStringAsFixed(2) ?? '',
    );
    final max = TextEditingController(
      text: existing?.maxAmount?.toStringAsFixed(2) ?? '',
    );
    final tag = TextEditingController(text: existing?.addTag ?? '');
    TransactionType? type = existing?.type;
    int? categoryId = existing?.categoryId;
    int? accountId = existing?.accountId;
    bool? analytics = existing?.includeInAnalytics;
    var enabled = existing?.enabled ?? true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null ? 'Nuova regola' : 'Modifica regola',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                TextField(
                  controller: name,
                  autofocus: existing == null,
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
                  decoration: const InputDecoration(labelText: 'Tipo'),
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
                if (type != TransactionType.transfer)
                  DropdownButtonFormField<int?>(
                    initialValue: categoryId,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Non cambiare'),
                      ),
                      ...state.categories
                          .where((item) => type == null || item.type == type)
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
                  decoration: const InputDecoration(labelText: 'Conto'),
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
                  decoration: const InputDecoration(labelText: 'Aggiungi tag'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Regola attiva'),
                  value: enabled,
                  onChanged: (value) => setSheetState(() => enabled = value),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Statistiche'),
                  subtitle: Text(
                    analytics == null
                        ? 'Non cambiare'
                        : analytics!
                        ? 'Includi'
                        : 'Escludi',
                  ),
                  trailing: PopupMenuButton<bool?>(
                    onSelected: (value) =>
                        setSheetState(() => analytics = value),
                    itemBuilder: (_) => const [
                      PopupMenuItem<bool?>(
                        value: null,
                        child: Text('Non cambiare'),
                      ),
                      PopupMenuItem<bool?>(value: true, child: Text('Includi')),
                      PopupMenuItem<bool?>(
                        value: false,
                        child: Text('Escludi'),
                      ),
                    ],
                  ),
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
                      final rule = AutomationRule(
                        id: existing?.id ?? 0,
                        name: name.text.trim(),
                        enabled: enabled,
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
                        priority: existing?.priority ?? state.rules.length,
                      );
                      if (existing == null) {
                        await state.addRule(rule);
                      } else {
                        await service.update(state, rule);
                      }
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    child: Text(
                      existing == null ? 'Crea regola' : 'Salva modifiche',
                    ),
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
}

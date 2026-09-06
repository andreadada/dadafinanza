import 'package:flutter/material.dart';

import '../app_state.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/quick_preset_service.dart';
import '../widgets/full_page_empty_state.dart';
import '../widgets/ui_helpers.dart';

class PresetManagementScreen extends StatefulWidget {
  const PresetManagementScreen({super.key});

  @override
  State<PresetManagementScreen> createState() => _PresetManagementScreenState();
}

class _PresetManagementScreenState extends State<PresetManagementScreen> {
  List<QuickPreset>? items;
  bool _requestedInitialLoad = false;

  Future<void> _load() async {
    final state = AppScope.of(context);
    final value = await QuickPresetService(state.database).all();
    if (mounted) setState(() => items = value);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedInitialLoad) return;
    _requestedInitialLoad = true;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final presets = items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preset rapidi'),
        actions: [
          IconButton(
            tooltip: 'Nuovo preset',
            onPressed: () async {
              await _edit(context, state);
              await _load();
            },
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: presets == null
          ? const Center(child: CircularProgressIndicator())
          : presets.isEmpty
          ? FullPageEmptyState(
              icon: Icons.bookmark_add_outlined,
              title: 'Nessun preset',
              subtitle:
                  'Crea scorciatoie per i movimenti che inserisci spesso.',
              action: FilledButton.icon(
                onPressed: () async {
                  await _edit(context, state);
                  await _load();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crea preset'),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount: presets.length,
              onReorderItem: (oldIndex, newIndex) async {
                if (newIndex > oldIndex) newIndex--;
                final moved = presets.removeAt(oldIndex);
                presets.insert(newIndex, moved);
                setState(() {});
                await QuickPresetService(state.database).reorder(presets);
              },
              itemBuilder: (context, index) {
                final preset = presets[index];
                return ListTile(
                  key: ValueKey(preset.id),
                  contentPadding: EdgeInsets.zero,
                  minVerticalPadding: 12,
                  leading: const Icon(Icons.drag_handle_rounded),
                  title: Text(
                    preset.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(_summary(state, preset)),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Azioni preset',
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _edit(context, state, existing: preset);
                      } else if (value == 'delete') {
                        final confirmed = await confirmDestructiveAction(
                          context,
                          title: 'Eliminare “${preset.name}”?',
                          message:
                              'Il preset verrà rimosso. I movimenti già registrati non cambieranno.',
                        );
                        if (confirmed) {
                          await QuickPresetService(
                            state.database,
                          ).delete(preset.id);
                        }
                      }
                      if (mounted) await _load();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Modifica'),
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
                  onTap: () async {
                    await _edit(context, state, existing: preset);
                    if (mounted) await _load();
                  },
                );
              },
            ),
    );
  }

  String _summary(AppState state, QuickPreset item) {
    final account = state.accountById(item.accountId)?.name;
    final destination = state.accountById(item.toAccountId)?.name;
    final category = state.categoryById(item.categoryId)?.name;
    return [
      item.type.label,
      if (category != null) category,
      if (account != null) account,
      if (destination != null) '→ $destination',
      if (item.amount != null) moneyFor(state, item.amount!),
    ].join(' · ');
  }

  Future<void> _edit(
    BuildContext context,
    AppState state, {
    QuickPreset? existing,
  }) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final amount = TextEditingController(
      text: existing?.amount == null
          ? ''
          : existing!.amount!.toStringAsFixed(2),
    );
    final note = TextEditingController(text: existing?.note ?? '');
    var type = existing?.type ?? TransactionType.expense;
    int? accountId = existing?.accountId;
    int? toAccountId = existing?.toAccountId;
    int? categoryId = existing?.categoryId;
    final service = QuickPresetService(state.database);
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
                  existing == null ? 'Nuovo preset' : 'Modifica preset',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                TextField(
                  controller: name,
                  autofocus: existing == null,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                DropdownButtonFormField<TransactionType>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: TransactionType.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setSheetState(() {
                      type = value;
                      categoryId = null;
                      if (type != TransactionType.transfer) toAccountId = null;
                    });
                  },
                ),
                DropdownButtonFormField<int?>(
                  initialValue: accountId,
                  decoration: const InputDecoration(
                    labelText: 'Conto preferito',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Usa ultimo conto'),
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
                  onChanged: (value) => setSheetState(() {
                    accountId = value;
                    if (toAccountId == accountId) toAccountId = null;
                  }),
                ),
                if (type == TransactionType.transfer)
                  DropdownButtonFormField<int?>(
                    initialValue: toAccountId,
                    decoration: const InputDecoration(
                      labelText: 'Destinazione',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Scegli nel Quick Add'),
                      ),
                      ...state.activeAccounts
                          .where(
                            (item) => !item.isLocked && item.id != accountId,
                          )
                          .map(
                            (item) => DropdownMenuItem<int?>(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          ),
                    ],
                    onChanged: (value) => toAccountId = value,
                  )
                else
                  DropdownButtonFormField<int?>(
                    initialValue: categoryId,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Scegli nel Quick Add'),
                      ),
                      ...state.categoriesFor(type).map(
                        (item) => DropdownMenuItem<int?>(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => categoryId = value,
                  ),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Importo opzionale',
                    suffixText: state.currency,
                  ),
                ),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(
                    labelText: 'Nota opzionale',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final parsed = amount.text.trim().isEmpty
                          ? null
                          : double.tryParse(amount.text.replaceAll(',', '.'));
                      if (name.text.trim().isEmpty ||
                          (amount.text.trim().isNotEmpty &&
                              (parsed == null || parsed <= 0)) ||
                          (type == TransactionType.transfer &&
                              accountId != null &&
                              accountId == toAccountId)) {
                        return;
                      }
                      await service.save(
                        id: existing?.id,
                        name: name.text.trim(),
                        type: type,
                        accountId: accountId,
                        toAccountId: toAccountId,
                        categoryId: categoryId,
                        amount: parsed,
                        note: note.text.trim(),
                        tags: existing?.tags ?? const [],
                        position: existing?.position,
                        enabled: existing?.enabled ?? true,
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    child: const Text('Salva preset'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    name.dispose();
    amount.dispose();
    note.dispose();
  }
}

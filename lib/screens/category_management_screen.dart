import 'package:flutter/material.dart';

import '../app_state.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/data_integrity_service.dart';
import '../widgets/ui_helpers.dart';
import 'transaction_screens.dart';

Future<void> showCategoryEditor(
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
                'Modifica categoria',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(categoryIcon(iconKey), color: color),
                title: const Text('Icona'),
                subtitle: const Text('Puoi cambiarla in qualsiasi momento'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final selected = await showIconPicker(
                    sheetContext,
                    options: categoryIconOptions,
                    selected: iconKey,
                  );
                  if (selected != null) {
                    setSheetState(() => iconKey = selected);
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Colore',
                style: Theme.of(sheetContext).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categoryPalette
                    .map(
                      (item) => Semantics(
                        button: true,
                        selected: item == color,
                        label: 'Colore categoria',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setSheetState(() => color = item),
                          child: SizedBox.square(
                            dimension: 48,
                            child: Center(
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: item,
                                  shape: BoxShape.circle,
                                ),
                                child: item == color
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final trimmed = name.text.trim();
                    if (trimmed.isEmpty) return;
                    await state.updateCategory(
                      existing.copyWith(
                        name: trimmed,
                        iconKey: iconKey,
                        colorValue: color.toARGB32(),
                      ),
                    );
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
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

class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

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
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.widgets_outlined),
            title: const Text('Quick slot widget'),
            subtitle: const Text('Scegli fino a quattro categorie di spesa.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _quickSlots(context, state),
          ),
          const SizedBox(height: 24),
          _section(context, state, TransactionType.expense, 'Spese'),
          const SizedBox(height: 32),
          _section(context, state, TransactionType.income, 'Entrate'),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context,
    AppState state,
    TransactionType type,
    String title,
  ) {
    final items = state.categoriesFor(type).toList()
      ..sort((a, b) {
        if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
        final aOrder = a.quickOrder ?? 999;
        final bOrder = b.quickOrder ?? 999;
        final order = aOrder.compareTo(bOrder);
        return order != 0 ? order : a.name.compareTo(b.name);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title, trailing: Text('${items.length}')),
        if (items.isEmpty)
          const Text('Nessuna categoria')
        else
          ...items.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              minVerticalPadding: 10,
              leading: Icon(
                categoryIcon(item.iconKey),
                color: Color(item.colorValue),
              ),
              title: Text(item.name),
              subtitle: Text(
                [
                  if (item.isFavorite) 'Preferita',
                  if (item.quickOrder != null) 'Quick ${item.quickOrder! + 1}',
                ].join(' · '),
              ),
              trailing: PopupMenuButton<String>(
                tooltip: 'Azioni categoria',
                onSelected: (value) async {
                  if (value == 'edit') {
                    await showCategoryEditor(context, state, item);
                  } else if (value == 'favorite') {
                    await DataIntegrityService.setCategoryFavorite(
                      state,
                      item,
                      !item.isFavorite,
                    );
                  } else if (value == 'merge' && context.mounted) {
                    await _merge(context, state, item);
                  } else if (value == 'delete' && context.mounted) {
                    await _delete(context, state, item);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Modifica')),
                  PopupMenuItem(
                    value: 'favorite',
                    child: Text(
                      item.isFavorite
                          ? 'Rimuovi preferita'
                          : 'Aggiungi preferita',
                    ),
                  ),
                  if (items.length > 1)
                    const PopupMenuItem(
                      value: 'merge',
                      child: Text('Unisci in…'),
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
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryDetailScreen(categoryId: item.id),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _quickSlots(BuildContext context, AppState state) async {
    final expenses = state.categoriesFor(TransactionType.expense).toList();
    final selected = expenses.where((item) => item.quickOrder != null).toList()
      ..sort((a, b) => a.quickOrder!.compareTo(b.quickOrder!));
    final result = await showModalBottomSheet<List<Category>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick slot',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text('Scegli e ordina fino a quattro categorie.'),
              const SizedBox(height: 12),
              Flexible(
                child: ReorderableListView(
                  shrinkWrap: true,
                  onReorder: (oldIndex, newIndex) {
                    setSheetState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = selected.removeAt(oldIndex);
                      selected.insert(newIndex, item);
                    });
                  },
                  children: [
                    for (final item in selected)
                      ListTile(
                        key: ValueKey(item.id),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.drag_handle_rounded),
                        title: Text(item.name),
                        trailing: IconButton(
                          tooltip: 'Rimuovi',
                          onPressed: () => setSheetState(
                            () => selected.removeWhere((c) => c.id == item.id),
                          ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                  ],
                ),
              ),
              if (selected.length < 4)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: expenses
                      .where((item) => !selected.any((c) => c.id == item.id))
                      .map(
                        (item) => ActionChip(
                          avatar: Icon(categoryIcon(item.iconKey), size: 18),
                          label: Text(item.name),
                          onPressed: () =>
                              setSheetState(() => selected.add(item)),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, selected),
                  child: const Text('Salva quick slot'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) await DataIntegrityService.setQuickSlots(state, result);
  }

  Future<void> _merge(
    BuildContext context,
    AppState state,
    Category source,
  ) async {
    final candidates = state
        .categoriesFor(source.type)
        .where((item) => item.id != source.id)
        .toList();
    final target = await showModalBottomSheet<Category>(
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
              'Unisci “${source.name}”',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Movimenti, split, budget, regole e apprendimento verranno spostati nella categoria scelta.',
            ),
            const SizedBox(height: 12),
            ...candidates.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  categoryIcon(item.iconKey),
                  color: Color(item.colorValue),
                ),
                title: Text(item.name),
                onTap: () => Navigator.pop(sheetContext, item),
              ),
            ),
          ],
        ),
      ),
    );
    if (target == null || !context.mounted) return;
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Unire le categorie?',
      message:
          '“${source.name}” confluirà in “${target.name}”. L’operazione aggiorna i collegamenti in modo transazionale.',
      confirmLabel: 'Unisci',
    );
    if (confirmed) {
      await DataIntegrityService.mergeCategories(
        state,
        source: source,
        destination: target,
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    AppState state,
    Category category,
  ) async {
    final count = state.transactionCountForCategory(category.id);
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Eliminare “${category.name}”?',
      message:
          '$count riferimenti perderanno questa categoria. Se vuoi conservare la classificazione, usa “Unisci in…”.',
    );
    if (confirmed) await state.deleteCategory(category);
  }
}

class CategoryDetailScreen extends StatelessWidget {
  const CategoryDetailScreen({required this.categoryId, super.key});
  final int categoryId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final category = state.categoryById(categoryId);
    if (category == null) {
      return const Scaffold(body: Center(child: Text('Categoria non trovata')));
    }
    final recent = state.transactions
        .where(
          (item) =>
              item.categoryId == category.id ||
              state
                  .splitsFor(item.id)
                  .any((split) => split.categoryId == category.id),
        )
        .take(8)
        .toList();
    final budgets = state.budgets
        .where((item) => item.categoryId == category.id)
        .toList();
    final rules = state.rules
        .where((item) => item.categoryId == category.id)
        .toList();
    final total = category.type == TransactionType.expense
        ? state.monthCategoryTotal(category.id)
        : state.transactions
              .where(
                (item) =>
                    item.type == TransactionType.income &&
                    item.categoryId == category.id &&
                    item.date.year == DateTime.now().year &&
                    item.date.month == DateTime.now().month,
              )
              .fold<double>(0, (sum, item) => sum + item.amount);
    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
        actions: [
          IconButton(
            tooltip: 'Modifica categoria',
            onPressed: () => showCategoryEditor(context, state, category),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Row(
            children: [
              Icon(
                categoryIcon(category.iconKey),
                color: Color(category.colorValue),
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FlatMetric(
                  label: 'Questo mese',
                  value: moneyFor(state, total),
                  icon: category.type == TransactionType.expense
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SectionTitle(
            'Collegamenti',
            trailing: Text('${budgets.length + rules.length}'),
          ),
          FlatMetric(
            label: 'Budget',
            value: '${budgets.length}',
            icon: Icons.pie_chart_outline_rounded,
          ),
          const Divider(height: 1),
          FlatMetric(
            label: 'Regole',
            value: '${rules.length}',
            icon: Icons.auto_fix_high_outlined,
          ),
          const SizedBox(height: 28),
          const SectionTitle('Movimenti recenti'),
          if (recent.isEmpty)
            const Text('Ancora nessun movimento')
          else
            ...recent.map((item) => TransactionListTile(item: item)),
        ],
      ),
    );
  }
}

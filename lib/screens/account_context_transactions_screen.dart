import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/account_context_service.dart';
import '../widgets/account_context_selector.dart';
import '../widgets/ui_helpers.dart';
import 'quick_add_page.dart';
import 'transaction_screens.dart';

enum _MovementView { list, grouped }
enum _MovementSort { newest, oldest, amountDesc, amountAsc }

class AccountContextTransactionsScreen extends StatefulWidget {
  const AccountContextTransactionsScreen({
    required this.accountId,
    required this.onAccountChanged,
    super.key,
  });

  final int? accountId;
  final ValueChanged<int?> onAccountChanged;

  @override
  State<AccountContextTransactionsScreen> createState() =>
      _AccountContextTransactionsScreenState();
}

class _AccountContextTransactionsScreenState
    extends State<AccountContextTransactionsScreen> {
  final search = TextEditingController();
  String query = '';
  TransactionType? type;
  int? categoryId;
  DateTime? from;
  DateTime? to;
  _MovementView view = _MovementView.list;
  _MovementSort sort = _MovementSort.newest;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<FinanceTransaction> _items(AppState state) {
    final lowered = query.trim().toLowerCase();
    final items = AccountContextService.transactionsFor(state, widget.accountId)
        .where((item) {
      if (type != null && item.type != type) return false;
      if (categoryId != null) {
        final direct = item.categoryId == categoryId;
        final split = state
            .splitsFor(item.id)
            .any((part) => part.categoryId == categoryId);
        if (!direct && !split) return false;
      }
      if (from != null && item.date.isBefore(from!)) return false;
      if (to != null) {
        final inclusiveEnd = DateTime(to!.year, to!.month, to!.day, 23, 59, 59);
        if (item.date.isAfter(inclusiveEnd)) return false;
      }
      if (lowered.isNotEmpty) {
        final account = state.accountById(item.accountId);
        final destination = state.accountById(item.toAccountId);
        final category = state.categoryById(item.categoryId);
        final text = [
          item.note ?? '',
          account?.name ?? '',
          destination?.name ?? '',
          category?.name ?? '',
          ...item.tags,
        ].join(' ').toLowerCase();
        if (!text.contains(lowered)) return false;
      }
      return true;
    }).toList();

    switch (sort) {
      case _MovementSort.newest:
        items.sort((a, b) => b.date.compareTo(a.date));
      case _MovementSort.oldest:
        items.sort((a, b) => a.date.compareTo(b.date));
      case _MovementSort.amountDesc:
        items.sort((a, b) => b.amount.compareTo(a.amount));
      case _MovementSort.amountAsc:
        items.sort((a, b) => a.amount.compareTo(b.amount));
    }
    return items;
  }

  bool get hasFilters =>
      type != null || categoryId != null || from != null || to != null ||
      sort != _MovementSort.newest;

  void _clearFilters() {
    setState(() {
      type = null;
      categoryId = null;
      from = null;
      to = null;
      sort = _MovementSort.newest;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final items = _items(state);
    final groups = AccountContextService.groupByCategory(state, items);

    return Scaffold(
      appBar: AppBar(
        title: AccountContextSelector(
          accountId: widget.accountId,
          onChanged: widget.onAccountChanged,
        ),
        actions: [
          IconButton(
            tooltip: 'Filtri',
            onPressed: () => _showFilters(context, state),
            icon: Badge(
              isLabelVisible: hasFilters,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cerca nota, conto, categoria o tag',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Cancella ricerca',
                        onPressed: () {
                          search.clear();
                          setState(() => query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<_MovementView>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _MovementView.list,
                    icon: Icon(Icons.view_list_rounded),
                    label: Text('Lista'),
                  ),
                  ButtonSegment(
                    value: _MovementView.grouped,
                    icon: Icon(Icons.category_outlined),
                    label: Text('Raggruppata'),
                  ),
                ],
                selected: {view},
                onSelectionChanged: (value) =>
                    setState(() => view = value.first),
              ),
            ),
          ),
          if (hasFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Azzera filtri'),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: state.transactions.isEmpty
                        ? 'Nessun movimento'
                        : 'Nessun risultato',
                    subtitle: state.transactions.isEmpty
                        ? 'Aggiungi una spesa o un’entrata.'
                        : 'Prova a modificare ricerca o filtri.',
                    action: FilledButton.icon(
                      onPressed: () => _openNew(context, TransactionType.expense),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nuovo movimento'),
                    ),
                  )
                : view == _MovementView.list
                    ? ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) =>
                            TransactionListTile(item: items[index]),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                        itemCount: groups.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          final category = state.categoryById(group.categoryId);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            minVerticalPadding: 10,
                            leading: Icon(
                              group.type == TransactionType.transfer
                                  ? Icons.swap_horiz_rounded
                                  : category == null
                                      ? Icons.receipt_long_outlined
                                      : categoryIcon(category.iconKey),
                              color: category == null
                                  ? transactionColor(context, group.type)
                                  : Color(category.colorValue),
                            ),
                            title: Text(
                              group.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${group.count} ${group.count == 1 ? 'movimento' : 'movimenti'} · '
                              '${group.percentage.toStringAsFixed(0)}% ${_typeShareLabel(group.type)}',
                            ),
                            trailing: Text(
                              _groupAmount(state, group),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: transactionColor(context, group.type),
                              ),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _GroupedMovementsPage(
                                  title: group.title,
                                  ids: group.transactionIds,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _typeShareLabel(TransactionType type) => switch (type) {
        TransactionType.expense => 'delle spese',
        TransactionType.income => 'delle entrate',
        TransactionType.transfer => 'dei trasferimenti',
      };

  String _groupAmount(AppState state, AccountCategoryGroup group) =>
      switch (group.type) {
        TransactionType.expense => '-${moneyFor(state, group.total)}',
        TransactionType.income => '+${moneyFor(state, group.total)}',
        TransactionType.transfer => moneyFor(state, group.total),
      };

  Future<void> _openNew(BuildContext context, TransactionType type) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuickAddPage(
          initialTypeName: type.name,
          initialAccountId: widget.accountId,
        ),
      ),
    );
  }

  Future<void> _showFilters(BuildContext context, AppState state) async {
    var draftType = type;
    var draftCategory = categoryId;
    var draftFrom = from;
    var draftTo = to;
    var draftSort = sort;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final availableCategories = draftType == null ||
                  draftType == TransactionType.transfer
              ? state.categories
              : state.categoriesFor(draftType!);
          if (draftCategory != null &&
              !availableCategories.any((item) => item.id == draftCategory)) {
            draftCategory = null;
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtra movimenti',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<TransactionType?>(
                    initialValue: draftType,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: [
                      const DropdownMenuItem<TransactionType?>(
                        value: null,
                        child: Text('Tutti'),
                      ),
                      ...TransactionType.values.map(
                        (item) => DropdownMenuItem<TransactionType?>(
                          value: item,
                          child: Text(item.label),
                        ),
                      ),
                    ],
                    onChanged: (value) => setSheetState(() {
                      draftType = value;
                      draftCategory = null;
                    }),
                  ),
                  DropdownButtonFormField<int?>(
                    key: ValueKey('movement-category-$draftType-$draftCategory'),
                    initialValue: draftCategory,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tutte le categorie'),
                      ),
                      ...availableCategories.map(
                        (item) => DropdownMenuItem<int?>(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => draftCategory = value,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.date_range_outlined),
                    title: const Text('Dal'),
                    trailing: Text(
                      draftFrom == null
                          ? 'Qualsiasi'
                          : DateFormat('dd/MM/yyyy').format(draftFrom!),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDate: draftFrom ?? DateTime.now(),
                      );
                      if (picked != null) {
                        setSheetState(() => draftFrom = picked);
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available_outlined),
                    title: const Text('Al'),
                    trailing: Text(
                      draftTo == null
                          ? 'Qualsiasi'
                          : DateFormat('dd/MM/yyyy').format(draftTo!),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: draftFrom ?? DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDate: draftTo ?? DateTime.now(),
                      );
                      if (picked != null) setSheetState(() => draftTo = picked);
                    },
                  ),
                  DropdownButtonFormField<_MovementSort>(
                    initialValue: draftSort,
                    decoration: const InputDecoration(labelText: 'Ordina'),
                    items: const [
                      DropdownMenuItem(
                        value: _MovementSort.newest,
                        child: Text('Più recenti'),
                      ),
                      DropdownMenuItem(
                        value: _MovementSort.oldest,
                        child: Text('Più vecchi'),
                      ),
                      DropdownMenuItem(
                        value: _MovementSort.amountDesc,
                        child: Text('Importo decrescente'),
                      ),
                      DropdownMenuItem(
                        value: _MovementSort.amountAsc,
                        child: Text('Importo crescente'),
                      ),
                    ],
                    onChanged: (value) => draftSort = value ?? draftSort,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            setState(_clearFilters);
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('Azzera'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              type = draftType;
                              categoryId = draftCategory;
                              from = draftFrom;
                              to = draftTo;
                              sort = draftSort;
                            });
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('Applica'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GroupedMovementsPage extends StatelessWidget {
  const _GroupedMovementsPage({required this.title, required this.ids});

  final String title;
  final Set<int> ids;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final items = state.transactions.where((item) => ids.contains(item.id)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: items.isEmpty
          ? const Center(child: Text('Nessun movimento'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  TransactionListTile(item: items[index]),
            ),
    );
  }
}

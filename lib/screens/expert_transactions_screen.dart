import 'package:flutter/material.dart';

import '../app_state.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/account_scope_service.dart';
import '../widgets/account_scope_selector.dart';
import '../widgets/ui_helpers.dart';
import 'transaction_screens.dart';

enum TransactionsViewMode { list, accounts, categories }

enum _TypeFilter { all, expense, income, transfer }

enum _SortMode { newest, oldest, amountDesc, amountAsc }

class ExpertTransactionsScreen extends StatefulWidget {
  const ExpertTransactionsScreen({
    required this.selectedAccountId,
    required this.onAccountChanged,
    super.key,
  });

  final int? selectedAccountId;
  final ValueChanged<int?> onAccountChanged;

  @override
  State<ExpertTransactionsScreen> createState() =>
      _ExpertTransactionsScreenState();
}

class _ExpertTransactionsScreenState extends State<ExpertTransactionsScreen> {
  final _search = TextEditingController();
  TransactionsViewMode _viewMode = TransactionsViewMode.list;
  _TypeFilter _typeFilter = _TypeFilter.all;
  _SortMode _sortMode = _SortMode.newest;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scoped = AccountScopeService.transactions(
      state,
      widget.selectedAccountId,
    );

    return Scaffold(
      appBar: AppBar(
        title: AccountScopeSelector(
          selectedAccountId: widget.selectedAccountId,
          onChanged: widget.onAccountChanged,
        ),
        actions: [
          if (_viewMode == TransactionsViewMode.list)
            PopupMenuButton<_SortMode>(
              tooltip: 'Ordina movimenti',
              initialValue: _sortMode,
              onSelected: (value) => setState(() => _sortMode = value),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _SortMode.newest,
                  child: Text('Più recenti'),
                ),
                PopupMenuItem(
                  value: _SortMode.oldest,
                  child: Text('Più vecchi'),
                ),
                PopupMenuItem(
                  value: _SortMode.amountDesc,
                  child: Text('Importo maggiore'),
                ),
                PopupMenuItem(
                  value: _SortMode.amountAsc,
                  child: Text('Importo minore'),
                ),
              ],
              icon: const Icon(Icons.sort_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<TransactionsViewMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: TransactionsViewMode.list,
                  icon: Icon(Icons.view_agenda_outlined),
                  label: Text('Elenco'),
                ),
                ButtonSegment(
                  value: TransactionsViewMode.accounts,
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  label: Text('Conti'),
                ),
                ButtonSegment(
                  value: TransactionsViewMode.categories,
                  icon: Icon(Icons.category_outlined),
                  label: Text('Categorie'),
                ),
              ],
              selected: {_viewMode},
              onSelectionChanged: (value) =>
                  setState(() => _viewMode = value.first),
            ),
          ),
          const SizedBox(height: 20),
          switch (_viewMode) {
            TransactionsViewMode.list => _buildList(state, scoped),
            TransactionsViewMode.accounts => _buildAccounts(state),
            TransactionsViewMode.categories => _buildCategories(state, scoped),
          },
        ],
      ),
    );
  }

  Widget _buildList(AppState state, List<FinanceTransaction> scoped) {
    final query = _search.text.trim().toLowerCase();
    var items = scoped.where((item) {
      if (_typeFilter != _TypeFilter.all) {
        final expected = switch (_typeFilter) {
          _TypeFilter.expense => TransactionType.expense,
          _TypeFilter.income => TransactionType.income,
          _TypeFilter.transfer => TransactionType.transfer,
          _TypeFilter.all => item.type,
        };
        if (item.type != expected) return false;
      }
      if (query.isEmpty) return true;
      final account = state.accountById(item.accountId)?.name ?? '';
      final destination = state.accountById(item.toAccountId)?.name ?? '';
      final category = state.categoryById(item.categoryId)?.name ?? '';
      final haystack = [
        item.note ?? '',
        account,
        destination,
        category,
        ...item.tags,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    items.sort(
      (a, b) => switch (_sortMode) {
        _SortMode.newest => b.date.compareTo(a.date),
        _SortMode.oldest => a.date.compareTo(b.date),
        _SortMode.amountDesc => b.amount.compareTo(a.amount),
        _SortMode.amountAsc => a.amount.compareTo(b.amount),
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            labelText: 'Cerca movimenti',
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('Tutti', _TypeFilter.all),
              const SizedBox(width: 8),
              _filterChip('Spese', _TypeFilter.expense),
              const SizedBox(width: 8),
              _filterChip('Entrate', _TypeFilter.income),
              const SizedBox(width: 8),
              _filterChip('Trasferimenti', _TypeFilter.transfer),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SectionTitle('Movimenti', trailing: Text('${items.length}')),
        if (items.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Nessun movimento',
            subtitle: 'Prova a cambiare conto, filtro o ricerca.',
          )
        else
          ...items.map((item) => TransactionListTile(item: item)),
      ],
    );
  }

  Widget _filterChip(String label, _TypeFilter value) => FilterChip(
    label: Text(label),
    selected: _typeFilter == value,
    onSelected: (_) => setState(() => _typeFilter = value),
  );

  Widget _buildAccounts(AppState state) {
    final accounts = widget.selectedAccountId == null
        ? state.activeAccounts
        : state.activeAccounts
              .where((item) => item.id == widget.selectedAccountId)
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Per conto', trailing: Text('${accounts.length}')),
        if (accounts.isEmpty)
          const EmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Nessun conto',
            subtitle: 'Crea un conto per raggruppare i movimenti.',
          )
        else
          ...accounts.map((account) {
            final income = state.accountMonthTotal(
              account.id,
              TransactionType.income,
            );
            final expense = state.accountMonthTotal(
              account.id,
              TransactionType.expense,
            );
            final count = state.transactions
                .where(
                  (item) =>
                      item.accountId == account.id ||
                      item.toAccountId == account.id,
                )
                .length;
            return Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minVerticalPadding: 12,
                  leading: Icon(
                    accountIcon(account.iconKey),
                    color: Color(account.colorValue),
                  ),
                  title: Text(
                    account.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${moneyFor(state, income)} entrate · ${moneyFor(state, expense)} spese · $count movimenti',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        state.hideBalance || account.hideBalance
                            ? '••••'
                            : moneyFor(state, account.balance),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
                  onTap: () {
                    widget.onAccountChanged(account.id);
                    setState(() => _viewMode = TransactionsViewMode.list);
                  },
                ),
                const Divider(height: 1),
              ],
            );
          }),
      ],
    );
  }

  Widget _buildCategories(AppState state, List<FinanceTransaction> scoped) {
    final groups = _categoryGroups(state, scoped);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Per categoria', trailing: Text('${groups.length}')),
        if (groups.isEmpty)
          const EmptyState(
            icon: Icons.category_outlined,
            title: 'Nessuna categoria',
            subtitle: 'I movimenti categorizzati compariranno qui.',
          )
        else
          ...groups.map(
            (group) => Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minVerticalPadding: 12,
                  leading: Icon(group.icon, color: group.color),
                  title: Text(
                    group.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('${group.items.length} movimenti'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        moneyFor(state, group.total),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _CategoryTransactionsPage(group: group),
                    ),
                  ),
                ),
                const Divider(height: 1),
              ],
            ),
          ),
      ],
    );
  }

  List<_CategoryGroup> _categoryGroups(
    AppState state,
    List<FinanceTransaction> items,
  ) {
    final map = <String, _CategoryGroupBuilder>{};

    for (final item in items) {
      if (item.type == TransactionType.transfer) {
        final builder = map.putIfAbsent(
          'transfer',
          () => _CategoryGroupBuilder(
            label: 'Trasferimenti',
            icon: Icons.swap_horiz_rounded,
            color: null,
          ),
        );
        builder.total += item.amount;
        builder.items[item.id] = item;
        continue;
      }

      final splits = state.splitsFor(item.id);
      if (splits.isNotEmpty && item.type == TransactionType.expense) {
        for (final split in splits) {
          final category = state.categoryById(split.categoryId);
          final key = '${item.type.name}:${split.categoryId}';
          final builder = map.putIfAbsent(
            key,
            () => _CategoryGroupBuilder(
              label: category?.name ?? 'Senza categoria',
              icon: category == null
                  ? Icons.category_outlined
                  : categoryIcon(category.iconKey),
              color: category == null ? null : Color(category.colorValue),
            ),
          );
          builder.total += split.amount;
          builder.items[item.id] = item;
        }
        continue;
      }

      final category = state.categoryById(item.categoryId);
      final key = '${item.type.name}:${item.categoryId ?? 0}';
      final builder = map.putIfAbsent(
        key,
        () => _CategoryGroupBuilder(
          label:
              category?.name ??
              (item.type == TransactionType.income
                  ? 'Entrate senza categoria'
                  : 'Senza categoria'),
          icon: category == null
              ? Icons.category_outlined
              : categoryIcon(category.iconKey),
          color: category == null ? null : Color(category.colorValue),
        ),
      );
      builder.total += item.type == TransactionType.expense
          ? state.effectiveExpense(item)
          : item.amount;
      builder.items[item.id] = item;
    }

    final groups =
        map.values
            .map(
              (builder) => _CategoryGroup(
                label: builder.label,
                icon: builder.icon,
                color: builder.color,
                total: builder.total,
                items: builder.items.values.toList()
                  ..sort((a, b) => b.date.compareTo(a.date)),
              ),
            )
            .toList()
          ..sort((a, b) => b.total.compareTo(a.total));
    return groups;
  }
}

class _CategoryGroupBuilder {
  _CategoryGroupBuilder({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color? color;
  final Map<int, FinanceTransaction> items = {};
  double total = 0;
}

class _CategoryGroup {
  const _CategoryGroup({
    required this.label,
    required this.icon,
    required this.color,
    required this.total,
    required this.items,
  });

  final String label;
  final IconData icon;
  final Color? color;
  final double total;
  final List<FinanceTransaction> items;
}

class _CategoryTransactionsPage extends StatelessWidget {
  const _CategoryTransactionsPage({required this.group});

  final _CategoryGroup group;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(group.label)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Text('TOTALE', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(
            moneyFor(state, group.total),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 24),
          SectionTitle('Movimenti', trailing: Text('${group.items.length}')),
          ...group.items.map((item) => TransactionListTile(item: item)),
        ],
      ),
    );
  }
}

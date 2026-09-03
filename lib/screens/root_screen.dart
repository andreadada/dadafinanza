import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../main.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_helpers.dart';
import 'quick_add_page.dart';

part 'root_analytics_accounts.dart';
part 'root_more.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(),
      const TransactionsScreen(),
      const AnalyticsScreen(),
      const AccountsScreen(),
      const MoreScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const QuickAddPage()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuovo'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Movimenti',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Analisi',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Conti',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            selectedIcon: Icon(Icons.more_horiz_rounded),
            label: 'Altro',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final expense = state.monthTotal(TransactionType.expense);
    final income = state.monthTotal(TransactionType.income);
    final recent = state.transactions.take(5).toList();
    final month = DateFormat('MMMM yyyy', 'it_IT').format(DateTime.now());

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DadaFinanza'),
              Text(
                month,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: state.hideBalance ? 'Mostra saldo' : 'Nascondi saldo',
              onPressed: () => state.setHideBalance(!state.hideBalance),
              icon: Icon(
                state.hideBalance
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
          sliver: SliverList.list(
            children: [
              _BalanceHero(state: state, income: income, expense: expense),
              const SizedBox(height: 14),
              const _QuickActions(),
              if (state.accounts.isEmpty || state.categories.isEmpty) ...[
                const SizedBox(height: 22),
                _SetupStrip(
                  missingAccounts: state.accounts.isEmpty,
                  missingCategories: state.categories.isEmpty,
                ),
              ],
              const SizedBox(height: 28),
              SectionTitle(
                'Budget',
                trailing: state.monthlyBudget > 0
                    ? Text('${(state.budgetProgress * 100).round()}%')
                    : null,
              ),
              _BudgetCard(state: state, expense: expense),
              const SizedBox(height: 28),
              SectionTitle(
                'Ultimi movimenti',
                trailing: state.transactions.isEmpty
                    ? null
                    : Text('${state.transactions.length}'),
              ),
              if (recent.isEmpty)
                const _EmptyCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'Ancora nessun movimento',
                  subtitle:
                      'Quando registri una spesa o un’entrata, la trovi qui.',
                )
              else
                ...recent.map((t) => _TransactionTile(item: t)),
              const SizedBox(height: 28),
              const SectionTitle('Riepilogo'),
              _InsightCard(state: state),
            ],
          ),
        ),
      ],
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.state,
    required this.income,
    required this.expense,
  });

  final AppState state;
  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'SALDO TOTALE',
                style: textTheme.labelSmall?.copyWith(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F4F5),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            state.hideBalance ? '••••••' : money(state.totalBalance),
            style: textTheme.displaySmall?.copyWith(
              fontSize: 42,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: 'Entrate mese',
                  value: income,
                  type: TransactionType.income,
                  hidden: state.hideBalance,
                ),
              ),
              Container(width: 1, height: 42, color: AppTheme.border),
              const SizedBox(width: 18),
              Expanded(
                child: _HeroMetric(
                  label: 'Spese mese',
                  value: expense,
                  type: TransactionType.expense,
                  hidden: state.hideBalance,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.type,
    required this.hidden,
  });

  final String label;
  final double value;
  final TransactionType type;
  final bool hidden;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.muted,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            hidden ? '••••' : money(value),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: transactionColor(context, type),
            ),
          ),
        ],
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    void open(TransactionType type) => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QuickAddPage(initialTypeName: type.name),
          ),
        );
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.arrow_upward_rounded,
            label: 'Spesa',
            onTap: () => open(TransactionType.expense),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.arrow_downward_rounded,
            label: 'Entrata',
            onTap: () => open(TransactionType.income),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.swap_horiz_rounded,
            label: 'Giroconto',
            onTap: () => open(TransactionType.transfer),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20),
              ),
              const SizedBox(height: 9),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
}

class _SetupStrip extends StatelessWidget {
  const _SetupStrip({
    required this.missingAccounts,
    required this.missingCategories,
  });

  final bool missingAccounts;
  final bool missingCategories;

  @override
  Widget build(BuildContext context) {
    final title = missingAccounts ? 'Crea il primo conto' : 'Crea le tue categorie';
    final subtitle = missingAccounts
        ? 'Parti da un conto con saldo iniziale 0 € o inserisci il saldo reale.'
        : 'Scegli nome, tipo, colore e una delle tante icone disponibili.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                missingAccounts
                    ? Icons.account_balance_wallet_outlined
                    : Icons.category_outlined,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => missingAccounts
                      ? const AccountsScreen()
                      : const CategoriesScreen(),
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.state, required this.expense});

  final AppState state;
  final double expense;

  @override
  Widget build(BuildContext context) {
    if (state.monthlyBudget <= 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.tune_rounded),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nessun budget impostato',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text('Impostalo solo se vuoi tenere un limite mensile.'),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                child: const Text('Imposta'),
              ),
            ],
          ),
        ),
      );
    }

    final remaining = math.max(0, state.monthlyBudget - expense).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${money(expense)} spesi',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${money(remaining)} rimasti',
                  style: const TextStyle(color: AppTheme.muted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: state.budgetProgress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(99),
            ),
            const SizedBox(height: 10),
            Text(
              'Budget mensile ${money(state.monthlyBudget)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final top = state.topExpenseCategories(limit: 1);
    final subtitle = top.isEmpty
        ? 'Il riepilogo si costruisce automaticamente mentre usi l’app.'
        : '${top.first.key.name} è la categoria più pesante del mese: ${money(top.first.value)}.';
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(18),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.auto_graph_rounded),
        ),
        title: const Text('Questo mese', style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(subtitle),
        ),
      ),
    );
  }
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final search = TextEditingController();
  TransactionType? filter;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final q = search.text.trim().toLowerCase();
    final items = state.transactions.where((t) {
      if (filter != null && t.type != filter) return false;
      if (q.isEmpty) return true;
      final category = state.categoryById(t.categoryId)?.name.toLowerCase() ?? '';
      final account = state.accountById(t.accountId)?.name.toLowerCase() ?? '';
      return category.contains(q) ||
          account.contains(q) ||
          (t.note ?? '').toLowerCase().contains(q) ||
          t.tags.any((tag) => tag.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Movimenti')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Cerca movimenti',
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Tutti'),
                  selected: filter == null,
                  onSelected: (_) => setState(() => filter = null),
                ),
                const SizedBox(width: 8),
                ...TransactionType.values.map(
                  (type) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(type.label),
                      selected: filter == type,
                      onSelected: (_) => setState(() => filter = type),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (items.isEmpty)
            _EmptyCard(
              icon: q.isEmpty ? Icons.receipt_long_outlined : Icons.search_off_rounded,
              title: q.isEmpty ? 'Nessun movimento' : 'Nessun risultato',
              subtitle: q.isEmpty
                  ? 'Aggiungi il primo movimento dal pulsante Nuovo.'
                  : 'Prova a cambiare ricerca o filtro.',
            )
          else
            ...items.map(
              (t) => Dismissible(
                key: ValueKey(t.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async =>
                    await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Eliminare il movimento?'),
                        content: const Text(
                          'Il saldo del conto verrà corretto automaticamente.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Annulla'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Elimina'),
                          ),
                        ],
                      ),
                    ) ??
                    false,
                onDismissed: (_) => state.deleteTransaction(t),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.delete_outline_rounded),
                ),
                child: _TransactionTile(item: t),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.item});

  final FinanceTransaction item;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final category = state.categoryById(item.categoryId);
    final account = state.accountById(item.accountId);
    final toAccount = state.accountById(item.toAccountId);
    final title = item.type == TransactionType.transfer
        ? '${account?.name ?? 'Conto'} → ${toAccount?.name ?? 'Conto'}'
        : category?.name ?? item.type.label;
    final subtitle = [
      DateFormat('d MMM, HH:mm', 'it_IT').format(item.date),
      if (item.type != TransactionType.transfer) account?.name,
      if ((item.note ?? '').isNotEmpty) item.note,
    ].whereType<String>().join(' • ');
    final sign = item.type == TransactionType.income ? item.amount : -item.amount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: category != null
                  ? Color(category.colorValue).withValues(alpha: .18)
                  : Colors.white.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              category != null
                  ? categoryIcon(category.iconKey)
                  : Icons.swap_horiz_rounded,
              color: category != null
                  ? Color(category.colorValue)
                  : const Color(0xFFD4D4D8),
            ),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            item.type == TransactionType.transfer
                ? money(item.amount)
                : money(sign, signed: true),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: transactionColor(context, item.type),
            ),
          ),
        ),
      ),
    );
  }
}

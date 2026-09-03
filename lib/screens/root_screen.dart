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
        label: const Text('Aggiungi'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Movimenti'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: 'Analisi'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Conti'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'Altro'),
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
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: const Text('DadaFinanza'),
          actions: [
            IconButton(
              tooltip: state.hideBalance ? 'Mostra saldo' : 'Nascondi saldo',
              onPressed: () => state.setHideBalance(!state.hideBalance),
              icon: Icon(state.hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          sliver: SliverList.list(
            children: [
              _BalanceHero(state: state, income: income, expense: expense),
              const SizedBox(height: 16),
              const _QuickActions(),
              const SizedBox(height: 24),
              SectionTitle(
                'Budget del mese',
                trailing: Text('${(state.budgetProgress * 100).round()}%'),
              ),
              _BudgetCard(state: state, expense: expense),
              const SizedBox(height: 24),
              SectionTitle(
                'Movimenti recenti',
                trailing: Text('${state.transactions.length} totali'),
              ),
              if (recent.isEmpty)
                const _EmptyCard(
                  icon: Icons.receipt_long_rounded,
                  title: 'Nessun movimento ancora',
                  subtitle: 'Aggiungi la prima spesa o entrata dal pulsante in basso.',
                )
              else
                ...recent.map((t) => _TransactionTile(item: t)),
              const SizedBox(height: 24),
              const SectionTitle('In evidenza'),
              _InsightCard(state: state),
            ],
          ),
        ),
      ],
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.state, required this.income, required this.expense});

  final AppState state;
  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C6A50), Color(0xFF123A2E)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, size: 20),
              const SizedBox(width: 8),
              Text('Saldo disponibile', style: textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            state.hideBalance ? '••••••' : money(state.totalBalance),
            style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _HeroMetric(label: 'Entrate mese', value: income, positive: true, hidden: state.hideBalance)),
              const SizedBox(width: 12),
              Expanded(child: _HeroMetric(label: 'Spese mese', value: expense, positive: false, hidden: state.hideBalance)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value, required this.positive, required this.hidden});
  final String label;
  final double value;
  final bool positive;
  final bool hidden;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              hidden ? '••••' : money(value),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: positive ? const Color(0xFF6DE6B6) : const Color(0xFFFFA08E),
              ),
            ),
          ],
        ),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    void open(TransactionType type) => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => QuickAddPage(initialTypeName: type.name)),
        );
    return Row(
      children: [
        Expanded(child: _ActionButton(icon: Icons.remove_rounded, label: 'Spesa', onTap: () => open(TransactionType.expense))),
        const SizedBox(width: 10),
        Expanded(child: _ActionButton(icon: Icons.add_rounded, label: 'Entrata', onTap: () => open(TransactionType.income))),
        const SizedBox(width: 10),
        Expanded(child: _ActionButton(icon: Icons.swap_horiz_rounded, label: 'Giroconto', onTap: () => open(TransactionType.transfer))),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF13201B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .06)),
          ),
          child: Column(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 7),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.state, required this.expense});
  final AppState state;
  final double expense;

  @override
  Widget build(BuildContext context) {
    final remaining = math.max(0, state.monthlyBudget - expense).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 82,
              height: 82,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: state.budgetProgress,
                    strokeWidth: 9,
                    backgroundColor: Colors.white.withValues(alpha: .08),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(child: Text('${(state.budgetProgress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900))),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${money(expense)} di ${money(state.monthlyBudget)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Ti restano ${money(remaining)} per questo mese.', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
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
        ? 'Appena registri qualche spesa, qui compariranno suggerimenti automatici.'
        : '${top.first.key.name} è la categoria con più spese questo mese: ${money(top.first.value)}.';
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(18),
        leading: const CircleAvatar(child: Icon(Icons.auto_awesome_rounded)),
        title: const Text('Insight mensile', style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: Text(subtitle)),
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
      return category.contains(q) || account.contains(q) || (t.note ?? '').toLowerCase().contains(q) || t.tags.any((tag) => tag.toLowerCase().contains(q));
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Movimenti')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Cerca categoria, conto, tag o nota'),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(label: const Text('Tutti'), selected: filter == null, onSelected: (_) => setState(() => filter = null)),
                const SizedBox(width: 8),
                ...TransactionType.values.map((type) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(label: Text(type.label), selected: filter == type, onSelected: (_) => setState(() => filter = type)),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const _EmptyCard(icon: Icons.search_off_rounded, title: 'Nessun risultato', subtitle: 'Prova a cambiare ricerca o filtro.')
          else
            ...items.map((t) => Dismissible(
                  key: ValueKey(t.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async => await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Eliminare il movimento?'),
                          content: const Text('Il saldo del conto verrà corretto automaticamente.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
                            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Elimina')),
                          ],
                        ),
                      ) ??
                      false,
                  onDismissed: (_) => state.deleteTransaction(t),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.delete_outline_rounded),
                  ),
                  child: _TransactionTile(item: t),
                )),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          leading: CircleAvatar(
            backgroundColor: category != null ? Color(category.colorValue) : Theme.of(context).colorScheme.primaryContainer,
            child: Icon(category != null ? categoryIcon(category.iconKey) : Icons.swap_horiz_rounded, color: Colors.white),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: Text(
            item.type == TransactionType.transfer ? money(item.amount) : money(sign, signed: true),
            style: TextStyle(fontWeight: FontWeight.w900, color: transactionColor(context, item.type)),
          ),
        ),
      ),
    );
  }
}

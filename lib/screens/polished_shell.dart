import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../main.dart';
import '../models/models.dart';
import '../widgets/ui_helpers.dart';
import 'account_screens.dart';
import 'android_widgets_screen.dart';
import 'planning_screens.dart';
import 'quick_add_page.dart';
import 'root_screen.dart' as advanced;
import 'settings_screen.dart';
import 'transaction_screens.dart';

class PolishedRootScreen extends StatefulWidget {
  const PolishedRootScreen({super.key});

  @override
  State<PolishedRootScreen> createState() => _PolishedRootScreenState();
}

class _PolishedRootScreenState extends State<PolishedRootScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [
      PolishedHomeScreen(),
      TransactionsScreen(),
      PolishedAnalyticsScreen(),
      PolishedPlanningScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Nuovo movimento',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const QuickAddPage()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Movimento'),
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
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Analisi',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded),
            label: 'Pianifica',
          ),
        ],
      ),
    );
  }
}

class PolishedHomeScreen extends StatelessWidget {
  const PolishedHomeScreen({super.key});

  Future<void> _quick(BuildContext context, String type) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => QuickAddPage(initialTypeName: type)),
      );

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final expense = state.monthTotal(TransactionType.expense);
    final income = state.monthTotal(TransactionType.income);
    final accounts = state.activeAccounts.take(4).toList();
    final recent = state.transactions.take(5).toList();
    final upcoming = state.recurring.where((item) => item.enabled).toList()
      ..sort((a, b) => a.nextDate.compareTo(b.nextDate));
    final budget = state.budgets.where((item) => item.enabled).firstOrNull;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DadaFinanza'),
              Text(
                DateFormat('MMMM yyyy', 'it_IT').format(DateTime.now()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: state.hideBalance ? 'Mostra saldi' : 'Nascondi saldi',
              onPressed: () => state.setHideBalance(!state.hideBalance),
              icon: Icon(
                state.hideBalance
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Altre opzioni',
              onSelected: (value) {
                final Widget page = switch (value) {
                  'widgets' => const AndroidWidgetsScreen(),
                  'dashboard' => const advanced.HomeScreen(),
                  _ => const SettingsScreen(),
                };
                Navigator.push(context, MaterialPageRoute(builder: (_) => page));
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'widgets', child: Text('Widget Android')),
                PopupMenuItem(value: 'dashboard', child: Text('Dashboard avanzata')),
                PopupMenuItem(value: 'settings', child: Text('Impostazioni')),
              ],
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
          sliver: SliverList.list(
            children: [
              if (state.userAccounts.isEmpty) ...[
                _SetupBlock(
                  onAccount: () => showAccountEditor(context),
                  onMovement: () => _quick(context, 'expense'),
                ),
                const SizedBox(height: 30),
              ],
              Text(
                'PATRIMONIO',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(letterSpacing: 1.1),
              ),
              const SizedBox(height: 4),
              Text(
                state.hideBalance ? '••••••' : moneyFor(state, state.totalBalance),
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Metric(
                      'Entrate',
                      state.hideBalance ? '••••' : moneyFor(state, income),
                      context.financeColors.positive,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Metric(
                      'Spese',
                      state.hideBalance ? '••••' : moneyFor(state, expense),
                      context.financeColors.negative,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Metric(
                      'Disponibile',
                      state.hideBalance ? '••••' : moneyFor(state, state.safeToSpend),
                      null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _QuickButton(
                      icon: Icons.arrow_upward_rounded,
                      label: 'Spesa',
                      onTap: () => _quick(context, 'expense'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickButton(
                      icon: Icons.arrow_downward_rounded,
                      label: 'Entrata',
                      onTap: () => _quick(context, 'income'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickButton(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Trasferisci',
                      onTap: () => _quick(context, 'transfer'),
                    ),
                  ),
                ],
              ),
              if (state.unassignedCount > 0) ...[
                const SizedBox(height: 22),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.rule_folder_outlined,
                    color: context.financeColors.warning,
                  ),
                  title: Text(
                    '${state.unassignedCount} movimenti da assegnare',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('Completa il conto per mantenere i saldi ordinati.'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SectionTitle(
                'Conti',
                trailing: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AccountsScreen()),
                  ),
                  child: const Text('Tutti'),
                ),
              ),
              if (accounts.isEmpty)
                EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Nessun conto ancora',
                  subtitle: 'Aggiungi il conto che usi davvero o continua con movimenti Non assegnati.',
                  action: FilledButton.icon(
                    onPressed: () => showAccountEditor(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Crea conto'),
                  ),
                )
              else
                ...accounts.map((account) => _AccountRow(account: account)),
              if (budget != null) ...[
                const SizedBox(height: 30),
                _BudgetSummary(budget: budget),
              ],
              const SizedBox(height: 30),
              const SectionTitle('Ultimi movimenti'),
              if (recent.isEmpty)
                EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Inizia dal primo movimento',
                  subtitle: 'Registra una spesa o un’entrata: analisi e previsioni nasceranno dai tuoi dati reali.',
                  action: FilledButton.icon(
                    onPressed: () => _quick(context, 'expense'),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Registra movimento'),
                  ),
                )
              else
                ...recent.map((item) => TransactionListTile(item: item)),
              const SizedBox(height: 30),
              SectionTitle(
                'Prossime scadenze',
                trailing: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RecurringScreen()),
                  ),
                  child: const Text('Apri'),
                ),
              ),
              if (upcoming.isEmpty)
                EmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'Nessuna scadenza prevista',
                  subtitle: 'Aggiungi bollette, abbonamenti o stipendio per prevedere il saldo futuro.',
                  action: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RecurringScreen()),
                    ),
                    icon: const Icon(Icons.repeat_rounded),
                    label: const Text('Aggiungi ricorrenza'),
                  ),
                )
              else
                ...upcoming.take(3).map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.repeat_rounded,
                          color: transactionColor(context, item.type),
                        ),
                        title: Text(item.name),
                        subtitle: Text(
                          DateFormat('EEE d MMM', 'it_IT').format(item.nextDate),
                        ),
                        trailing: Text(
                          moneyFor(state, item.amount),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.dashboard_customize_outlined),
                title: const Text('Dashboard avanzata'),
                subtitle: const Text('Tutti i widget, grafici e personalizzazioni.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const advanced.HomeScreen()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      );
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: FilledButton.tonalIcon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      );
}

class _SetupBlock extends StatelessWidget {
  const _SetupBlock({required this.onAccount, required this.onMovement});
  final VoidCallback onAccount;
  final VoidCallback onMovement;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Configura DadaFinanza', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          const Text('Parti dal primo conto oppure registra subito un movimento e assegnalo in seguito.'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onAccount,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crea primo conto'),
              ),
              OutlinedButton.icon(
                onPressed: onMovement,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Registra movimento'),
              ),
            ],
          ),
        ],
      );
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account});
  final Account account;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 11,
      leading: CircleAvatar(
        backgroundColor: Color(account.colorValue).withValues(alpha: .12),
        child: Icon(accountIcon(account.iconKey), color: Color(account.colorValue)),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(account.name, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          if (account.isLocked)
            const Tooltip(
              message: 'Conto bloccato',
              child: Icon(Icons.lock_outline_rounded, size: 16),
            ),
        ],
      ),
      subtitle: Text(
        '${account.accountType.label}${!account.includeInTotal ? ' · fuori patrimonio' : ''}',
      ),
      trailing: Text(
        state.hideBalance || account.hideBalance
            ? '••••'
            : moneyFor(state, account.balance),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AccountDetailPage(accountId: account.id)),
      ),
    );
  }
}

class _BudgetSummary extends StatelessWidget {
  const _BudgetSummary({required this.budget});
  final Budget budget;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final spent = state.budgetSpent(budget);
    final progress = state.budgetProgressFor(budget);
    final remaining = math.max(0, budget.limit - spent).toDouble();
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BudgetsScreen()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Budget', trailing: Text('${(progress * 100).round()}%')),
          Text(budget.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('${moneyFor(state, remaining)} ancora disponibili'),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0).toDouble(),
            minHeight: 7,
            borderRadius: BorderRadius.circular(99),
            color: progress >= 1
                ? context.financeColors.negative
                : progress >= .8
                    ? context.financeColors.warning
                    : null,
          ),
        ],
      ),
    );
  }
}

class PolishedPlanningScreen extends StatelessWidget {
  const PolishedPlanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final budgets = state.budgets.where((item) => item.enabled).toList();
    final recurring = state.recurring.where((item) => item.enabled).toList()
      ..sort((a, b) => a.nextDate.compareTo(b.nextDate));
    final goals = state.goals.where((item) => !item.archived && !item.completed).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Pianifica')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Text(
            'Tre cose da controllare: quanto puoi spendere, cosa sta per arrivare e per cosa stai risparmiando.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 26),
          _PlanEntry(
            icon: Icons.pie_chart_outline_rounded,
            title: 'Budget del periodo',
            value: budgets.isEmpty ? 'Nessun limite' : '${budgets.length} attivi',
            detail: budgets.isEmpty
                ? 'Imposta un limite per sapere quanto puoi ancora spendere.'
                : 'Apri per vedere residuo e ritmo di spesa.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BudgetsScreen()),
            ),
          ),
          const Divider(height: 28),
          _PlanEntry(
            icon: Icons.event_repeat_rounded,
            title: 'Prossime scadenze',
            value: recurring.isEmpty
                ? 'Nessuna'
                : DateFormat('d MMM', 'it_IT').format(recurring.first.nextDate),
            detail: recurring.isEmpty
                ? 'Aggiungi bollette, abbonamenti o stipendio.'
                : '${recurring.first.name} · ${moneyFor(state, recurring.first.amount)}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecurringScreen()),
            ),
          ),
          const Divider(height: 28),
          _PlanEntry(
            icon: Icons.flag_outlined,
            title: 'Obiettivi',
            value: goals.isEmpty ? 'Nessuno' : '${goals.length} attivi',
            detail: goals.isEmpty
                ? 'Dai un nome ai risparmi che vuoi costruire.'
                : '${goals.first.name}: ${moneyFor(state, goals.first.currentAmount)} / ${moneyFor(state, goals.first.targetAmount)}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GoalsScreen()),
            ),
          ),
          const SizedBox(height: 30),
          const SectionTitle('Viste'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Calendario finanziario'),
            subtitle: const Text('Entrate e uscite previste in ordine temporale.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FinanceCalendarScreen()),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune_rounded),
            title: const Text('Pianificazione avanzata'),
            subtitle: const Text('Tutte le viste e opzioni avanzate.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlanningScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanEntry extends StatelessWidget {
  const _PlanEntry({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        minVerticalPadding: 10,
        leading: Icon(icon, size: 28),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(detail),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value, style: Theme.of(context).textTheme.labelLarge),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
        onTap: onTap,
      );
}

enum _Period { week, month, year, custom }

class PolishedAnalyticsScreen extends StatefulWidget {
  const PolishedAnalyticsScreen({super.key});

  @override
  State<PolishedAnalyticsScreen> createState() => _PolishedAnalyticsScreenState();
}

class _PolishedAnalyticsScreenState extends State<PolishedAnalyticsScreen> {
  _Period period = _Period.month;
  DateTimeRange? custom;

  (DateTime, DateTime) _bounds(AppState state) {
    final now = DateTime.now();
    switch (period) {
      case _Period.week:
        final startWeekday = state.weekStart.clamp(1, 7);
        final offset = (now.weekday - startWeekday) % 7;
        final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: offset));
        return (start, start.add(const Duration(days: 7)));
      case _Period.month:
        final day = state.financialMonthStart.clamp(1, 28);
        var start = DateTime(now.year, now.month, day);
        if (now.isBefore(start)) start = DateTime(now.year, now.month - 1, day);
        return (start, DateTime(start.year, start.month + 1, day));
      case _Period.year:
        return (DateTime(now.year), DateTime(now.year + 1));
      case _Period.custom:
        final range = custom;
        if (range == null) return (DateTime(now.year, now.month), DateTime(now.year, now.month + 1));
        return (
          DateTime(range.start.year, range.start.month, range.start.day),
          DateTime(range.end.year, range.end.month, range.end.day + 1),
        );
    }
  }

  Map<Category, double> _categories(AppState state, DateTime from, DateTime to) {
    final totals = <Category, double>{};
    for (final transaction in state
        .analyticTransactions(from: from, to: to)
        .where((item) => item.type == TransactionType.expense)) {
      final splits = state.splitsFor(transaction.id);
      if (splits.isNotEmpty) {
        for (final split in splits) {
          final category = state.categoryById(split.categoryId);
          if (category != null) {
            totals[category] = (totals[category] ?? 0) + split.amount;
          }
        }
      } else {
        final category = state.categoryById(transaction.categoryId);
        if (category != null) {
          totals[category] =
              (totals[category] ?? 0) + state.effectiveExpense(transaction);
        }
      }
    }
    return totals;
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 3650)),
      initialDateRange: custom ??
          DateTimeRange(start: DateTime(now.year, now.month), end: now),
    );
    if (result != null && mounted) {
      setState(() {
        custom = result;
        period = _Period.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final (from, to) = _bounds(state);
    final duration = to.difference(from);
    final previousFrom = from.subtract(duration);
    final income = state.periodTotal(TransactionType.income, from, to);
    final expense = state.periodTotal(TransactionType.expense, from, to);
    final previous = state.periodTotal(TransactionType.expense, previousFrom, from);
    final delta = previous == 0 ? null : (expense - previous) / previous * 100;
    final categories = _categories(state, from, to).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final count = state.analyticTransactions(from: from, to: to).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Analisi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<_Period>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Period.week, label: Text('Settimana')),
                ButtonSegment(value: _Period.month, label: Text('Mese')),
                ButtonSegment(value: _Period.year, label: Text('Anno')),
                ButtonSegment(value: _Period.custom, label: Text('Custom')),
              ],
              selected: {period},
              onSelectionChanged: (value) {
                if (value.first == _Period.custom) {
                  _pickCustom();
                } else {
                  setState(() => period = value.first);
                }
              },
            ),
          ),
          const SizedBox(height: 22),
          Text(
            '${DateFormat('d MMM', 'it_IT').format(from)} – ${DateFormat('d MMM', 'it_IT').format(to.subtract(const Duration(days: 1)))}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  'Entrate',
                  moneyFor(state, income),
                  context.financeColors.positive,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _Metric(
                  'Spese',
                  moneyFor(state, expense),
                  context.financeColors.negative,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Insight(
            icon: delta == null
                ? Icons.horizontal_rule_rounded
                : delta <= 0
                    ? Icons.trending_down_rounded
                    : Icons.trending_up_rounded,
            text: delta == null
                ? 'Servono più dati per confrontare il periodo precedente.'
                : 'Hai speso ${delta.abs().toStringAsFixed(0)}% ${delta <= 0 ? 'in meno' : 'in più'} rispetto al periodo precedente.',
            color: delta == null
                ? null
                : delta <= 0
                    ? context.financeColors.positive
                    : context.financeColors.negative,
          ),
          const SizedBox(height: 10),
          _Insight(
            icon: Icons.calculate_outlined,
            text:
                '$count movimenti · media ${moneyFor(state, expense / math.max(1, duration.inDays))} di spese al giorno.',
          ),
          const SizedBox(height: 30),
          const SectionTitle('Dove stai spendendo'),
          if (categories.isEmpty)
            const EmptyState(
              icon: Icons.donut_small_outlined,
              title: 'Nessun dato nel periodo',
              subtitle: 'Le categorie compariranno qui quando registri movimenti.',
            )
          else
            ...categories.take(6).map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor:
                          Color(entry.key.colorValue).withValues(alpha: .12),
                      child: Icon(
                        categoryIcon(entry.key.iconKey),
                        color: Color(entry.key.colorValue),
                      ),
                    ),
                    title: Text(entry.key.name),
                    subtitle: Text(
                      expense <= 0
                          ? ''
                          : '${(entry.value / expense * 100).toStringAsFixed(0)}% delle spese',
                    ),
                    trailing: Text(
                      moneyFor(state, entry.value),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _CategoryPeriodScreen(
                          categoryId: entry.key.id,
                          from: from,
                          to: to,
                        ),
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.query_stats_rounded),
            title: const Text('Analisi avanzata'),
            subtitle: const Text('Grafici, patrimonio e viste aggiuntive.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const advanced.AnalyticsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _Insight extends StatelessWidget {
  const _Insight({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 9),
          Expanded(child: Text(text)),
        ],
      );
}

class _CategoryPeriodScreen extends StatelessWidget {
  const _CategoryPeriodScreen({
    required this.categoryId,
    required this.from,
    required this.to,
  });
  final int categoryId;
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final category = state.categoryById(categoryId);
    final items = state
        .analyticTransactions(from: from, to: to)
        .where(
          (item) => item.categoryId == categoryId ||
              state.splitsFor(item.id).any((split) => split.categoryId == categoryId),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(category?.name ?? 'Categoria')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 60),
        children: [
          Text('${items.length} ${items.length == 1 ? 'movimento' : 'movimenti'} nel periodo'),
          const SizedBox(height: 18),
          if (items.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Nessun movimento',
              subtitle: 'Non risultano movimenti per questa categoria nel periodo.',
            )
          else
            ...items.map((item) => TransactionListTile(item: item)),
        ],
      ),
    );
  }
}

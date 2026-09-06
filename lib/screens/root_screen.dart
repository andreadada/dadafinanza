import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../core/money.dart';
import '../main.dart';
import '../models/models.dart';
import '../widgets/ui_helpers.dart';
import 'account_screens.dart';
import 'advances_screen.dart';
import 'planning_screens.dart';
import 'quick_add_page.dart';
import 'settings_screen.dart';
import 'transaction_screens.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [
      HomeScreen(),
      TransactionsScreen(),
      AnalyticsScreen(),
      PlanningScreen(),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: index, children: pages),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuovo movimento',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const QuickAddPage()),
        ),
        child: const Icon(Icons.add_rounded),
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
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded),
            label: 'Pianifica',
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
    final widgets =
        state.dashboardWidgets.where((item) => item.enabled).toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final month = DateFormat('MMMM yyyy', 'it_IT').format(DateTime.now());

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DadaFinanza'),
              Text(month, style: Theme.of(context).textTheme.bodySmall),
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
            IconButton(
              tooltip: 'Personalizza dashboard',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DashboardCustomizerScreen(),
                ),
              ),
              icon: const Icon(Icons.dashboard_customize_outlined),
            ),
            IconButton(
              tooltip: 'Impostazioni',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          sliver: SliverList.list(
            children: [
              if (state.userAccounts.isEmpty) ...[
                const _SetupGuide(),
                const SizedBox(height: 28),
              ],
              ...widgets.map(
                (config) => Padding(
                  padding: const EdgeInsets.only(bottom: 26),
                  child: _DashboardWidget(config: config),
                ),
              ),
              if (widgets.isEmpty)
                EmptyState(
                  icon: Icons.dashboard_customize_outlined,
                  title: 'Dashboard vuota',
                  subtitle: 'Scegli i widget che vuoi vedere nella Home.',
                  action: FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DashboardCustomizerScreen(),
                      ),
                    ),
                    child: const Text('Personalizza'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SetupGuide extends StatelessWidget {
  const _SetupGuide();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Configura DadaFinanza',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 6),
      Text(
        'Puoi creare il primo conto oppure registrare subito un movimento come Non assegnato.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            onPressed: () => showAccountEditor(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crea primo conto'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuickAddPage()),
            ),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Registra movimento'),
          ),
        ],
      ),
    ],
  );
}

class _DashboardWidget extends StatelessWidget {
  const _DashboardWidget({required this.config});
  final DashboardWidgetConfig config;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final type = config.type;
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1);
    final currentExpense = state.monthTotal(TransactionType.expense);
    final previousExpense = state.monthTotal(
      TransactionType.expense,
      month: previousMonth,
    );

    Widget metric(
      String value, {
      String? subtitle,
      IconData? icon,
      VoidCallback? onTap,
      Color? valueColor,
    }) => _DashboardMetric(
      title: type.label,
      value: value,
      subtitle: subtitle,
      icon: icon,
      onTap: onTap,
      valueColor: valueColor,
      large: config.size == DashboardWidgetSize.large,
    );

    switch (type) {
      case DashboardWidgetType.totalBalance:
        return metric(
          state.hideBalance ? '••••••' : moneyFor(state, state.totalBalance),
          subtitle: 'Patrimonio incluso nel totale',
          icon: Icons.account_balance_wallet_outlined,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountsScreen()),
          ),
        );
      case DashboardWidgetType.monthlyCashFlow:
        return metric(
          moneyFor(state, state.monthlyCashFlow, signed: true),
          subtitle:
              '${moneyFor(state, state.monthTotal(TransactionType.income))} entrate · ${moneyFor(state, currentExpense)} spese',
          icon: Icons.compare_arrows_rounded,
          valueColor: state.monthlyCashFlow >= 0
              ? context.financeColors.positive
              : context.financeColors.negative,
        );
      case DashboardWidgetType.monthlyIncome:
        return metric(
          moneyFor(state, state.monthTotal(TransactionType.income)),
          icon: Icons.arrow_downward_rounded,
          valueColor: context.financeColors.positive,
        );
      case DashboardWidgetType.monthlyExpense:
        return metric(
          moneyFor(state, currentExpense),
          icon: Icons.arrow_upward_rounded,
          valueColor: context.financeColors.negative,
        );
      case DashboardWidgetType.monthlyBudget:
        final budget = state.budgets.where((item) => item.enabled).firstOrNull;
        if (budget == null) {
          return metric(
            'Nessun budget',
            subtitle: 'Crea un limite in Pianifica',
            icon: Icons.pie_chart_outline_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BudgetsScreen()),
            ),
          );
        }
        final spent = state.budgetSpent(budget);
        final progress = state.budgetProgressFor(budget);
        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BudgetsScreen()),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                type.label,
                trailing: Text('${(progress * 100).round()}%'),
              ),
              Text(
                '${moneyFor(state, spent)} / ${moneyFor(state, budget.limit)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
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
      case DashboardWidgetType.safeToSpend:
        return metric(
          state.hideBalance ? '••••••' : moneyFor(state, state.safeToSpend),
          subtitle: 'Stima fino a fine mese',
          icon: Icons.safety_check_outlined,
          onTap: () => _showSafeToSpendInfo(context),
        );
      case DashboardWidgetType.netWorth:
        return metric(
          state.hideBalance ? '••••••' : moneyFor(state, state.totalBalance),
          subtitle: 'Patrimonio corrente',
          icon: Icons.show_chart_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NetWorthScreen()),
          ),
        );
      case DashboardWidgetType.accounts:
        final count = config.size == DashboardWidgetSize.large ? 5 : 3;
        final visible = state.activeAccounts.take(count).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              type.label,
              trailing: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountsScreen()),
                ),
                child: const Text('Tutti'),
              ),
            ),
            if (visible.isEmpty)
              const Text('Nessun conto')
            else
              ...visible.map(
                (account) => FlatMetric(
                  label: account.name,
                  value: state.hideBalance || account.hideBalance
                      ? '••••'
                      : moneyFor(state, account.balance),
                  icon: accountIcon(account.iconKey),
                  color: Color(account.colorValue),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AccountDetailPage(accountId: account.id),
                    ),
                  ),
                ),
              ),
          ],
        );
      case DashboardWidgetType.recentTransactions:
        final count = config.size == DashboardWidgetSize.large ? 6 : 3;
        final recent = state.transactions.take(count).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(type.label),
            if (recent.isEmpty)
              const Text('Ancora nessun movimento')
            else
              ...recent.map((item) => TransactionListTile(item: item)),
          ],
        );
      case DashboardWidgetType.todayExpense:
        return metric(
          moneyFor(state, state.todayExpense),
          icon: Icons.today_outlined,
          valueColor: context.financeColors.negative,
        );
      case DashboardWidgetType.weekExpense:
        return metric(
          moneyFor(state, state.weekExpense),
          icon: Icons.date_range_outlined,
          valueColor: context.financeColors.negative,
        );
      case DashboardWidgetType.previousMonthComparison:
        final delta = previousExpense == 0
            ? null
            : (currentExpense - previousExpense) / previousExpense * 100;
        return metric(
          delta == null
              ? 'Nessun confronto'
              : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}%',
          subtitle:
              '${moneyFor(state, currentExpense)} questo mese · ${moneyFor(state, previousExpense)} precedente',
          icon: Icons.compare_rounded,
          valueColor: delta == null
              ? null
              : delta <= 0
              ? context.financeColors.positive
              : context.financeColors.negative,
        );
      case DashboardWidgetType.topCategories:
        final count = config.size == DashboardWidgetSize.large ? 5 : 3;
        final top = state.topExpenseCategories(limit: count);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(type.label),
            if (top.isEmpty)
              const Text('Nessun dato')
            else
              ...top.map(
                (entry) => FlatMetric(
                  label: entry.key.name,
                  value: moneyFor(state, entry.value),
                  icon: categoryIcon(entry.key.iconKey),
                  color: Color(entry.key.colorValue),
                ),
              ),
          ],
        );
      case DashboardWidgetType.closestBudget:
        final active = state.budgets.where((item) => item.enabled).toList()
          ..sort(
            (a, b) => state
                .budgetProgressFor(b)
                .compareTo(state.budgetProgressFor(a)),
          );
        final budget = active.firstOrNull;
        return metric(
          budget == null
              ? 'Nessun budget'
              : '${(state.budgetProgressFor(budget) * 100).round()}%',
          subtitle: budget?.name,
          icon: Icons.warning_amber_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BudgetsScreen()),
          ),
        );
      case DashboardWidgetType.upcomingRecurring:
        final count = config.size == DashboardWidgetSize.large ? 5 : 3;
        final upcoming = state.recurring
            .where((item) => item.enabled)
            .take(count)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              type.label,
              trailing: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RecurringScreen()),
                ),
                child: const Text('Apri'),
              ),
            ),
            if (upcoming.isEmpty)
              const Text('Nessun pagamento previsto')
            else
              ...upcoming.map(
                (item) => FlatMetric(
                  label:
                      '${item.name} · ${DateFormat('dd MMM', 'it_IT').format(item.nextDate)}',
                  value:
                      '${item.type == TransactionType.expense
                          ? '-'
                          : item.type == TransactionType.income
                          ? '+'
                          : ''}${moneyFor(state, item.amount)}',
                  icon: Icons.repeat_rounded,
                  color: transactionColor(context, item.type),
                ),
              ),
          ],
        );
      case DashboardWidgetType.financeCalendar:
        final next = state.recurring.where((item) => item.enabled).firstOrNull;
        return metric(
          next == null
              ? 'Nessuna scadenza'
              : DateFormat('dd MMM', 'it_IT').format(next.nextDate),
          subtitle: next?.name,
          icon: Icons.calendar_month_outlined,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FinanceCalendarScreen()),
          ),
        );
      case DashboardWidgetType.goals:
        final active = state.goals
            .where((item) => !item.archived && !item.completed)
            .firstOrNull;
        return metric(
          active == null
              ? 'Nessun obiettivo'
              : '${((active.currentAmount / active.targetAmount) * 100).clamp(0, 100).round()}%',
          subtitle: active == null
              ? 'Crea un obiettivo in Pianifica'
              : '${active.name} · ${moneyFor(state, active.currentAmount)} / ${moneyFor(state, active.targetAmount)}',
          icon: Icons.flag_outlined,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GoalsScreen()),
          ),
        );
      case DashboardWidgetType.netWorthTrend:
        final snapshots = state.netWorthSnapshots;
        final delta = snapshots.length < 2
            ? null
            : (snapshots.last['amount'] as num).toDouble() -
                  (snapshots.first['amount'] as num).toDouble();
        return metric(
          delta == null ? 'In raccolta' : moneyFor(state, delta, signed: true),
          subtitle: '${snapshots.length} snapshot locali',
          icon: Icons.timeline_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NetWorthScreen()),
          ),
        );
      case DashboardWidgetType.dailyAverage:
        return metric(
          moneyFor(state, state.dailyAverageExpense),
          subtitle: 'Media giornaliera del mese',
          icon: Icons.av_timer_rounded,
        );
      case DashboardWidgetType.noSpendDays:
        return metric(
          '${state.noSpendDaysThisMonth}',
          subtitle: 'Giorni senza spese questo mese',
          icon: Icons.event_available_outlined,
        );
      case DashboardWidgetType.endMonthForecast:
        return metric(
          state.hideBalance
              ? '••••••'
              : moneyFor(state, state.endOfMonthForecast),
          subtitle: 'Previsione basata sui ricorrenti attivi',
          icon: Icons.auto_graph_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FinanceCalendarScreen()),
          ),
        );
      case DashboardWidgetType.unassignedTransactions:
        return metric(
          '${state.unassignedCount}',
          subtitle: state.unassignedCount == 1
              ? 'movimento da assegnare'
              : 'movimenti da assegnare',
          icon: Icons.help_outline_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const TransactionsScreen(initialUnassignedOnly: true),
            ),
          ),
        );
    }
  }

  void _showSafeToSpendInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Disponibile da spendere',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 10),
            Text(
              'È una stima: parte dal patrimonio spendibile, sottrae le uscite ricorrenti previste fino a fine mese e conserva una riserva prudenziale per gli obiettivi. Non è un saldo bancario garantito.',
            ),
            SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.onTap,
    this.valueColor,
    this.large = false,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? valueColor;
  final bool large;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Icon(icon, size: 22),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  value,
                  style:
                      (large
                              ? Theme.of(context).textTheme.headlineLarge
                              : Theme.of(context).textTheme.headlineMedium)
                          ?.copyWith(color: valueColor),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Icon(Icons.chevron_right_rounded),
            ),
        ],
      ),
    ),
  );
}

enum _TransactionSort { newest, oldest, amountAsc, amountDesc }

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({this.initialUnassignedOnly = false, super.key});
  final bool initialUnassignedOnly;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final search = TextEditingController();
  final selected = <int>{};
  String query = '';
  TransactionType? type;
  int? accountId;
  int? categoryId;
  DateTime? from;
  DateTime? to;
  double? minAmount;
  double? maxAmount;
  bool withReceiptOnly = false;
  bool advancesOnly = false;
  late bool unassignedOnly;
  _TransactionSort sort = _TransactionSort.newest;

  @override
  void initState() {
    super.initState();
    unassignedOnly = widget.initialUnassignedOnly;
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<FinanceTransaction> _filtered(AppState state) {
    final lowered = query.trim().toLowerCase();
    final unassignedId = state.unassignedAccount?.id;
    final items = state.transactions.where((item) {
      final category = state.categoryById(item.categoryId);
      final account = state.accountById(item.accountId);
      final destination = state.accountById(item.toAccountId);
      final searchable = [
        item.note ?? '',
        category?.name ?? '',
        account?.name ?? '',
        destination?.name ?? '',
        ...item.tags,
      ].join(' ').toLowerCase();
      if (lowered.isNotEmpty && !searchable.contains(lowered)) return false;
      if (type != null && item.type != type) return false;
      if (accountId != null &&
          item.accountId != accountId &&
          item.toAccountId != accountId)
        return false;
      if (categoryId != null) {
        final direct = item.categoryId == categoryId;
        final split = state
            .splitsFor(item.id)
            .any((part) => part.categoryId == categoryId);
        if (!direct && !split) return false;
      }
      if (from != null && item.date.isBefore(from!)) return false;
      if (to != null &&
          item.date.isAfter(DateTime(to!.year, to!.month, to!.day, 23, 59, 59)))
        return false;
      if (minAmount != null && item.amount < minAmount!) return false;
      if (maxAmount != null && item.amount > maxAmount!) return false;
      if (withReceiptOnly && item.receiptPath?.isNotEmpty != true) return false;
      if (advancesOnly && !state.isAdvanceProtectedTransaction(item))
        return false;
      if (unassignedOnly && item.accountId != unassignedId) return false;
      return true;
    }).toList();

    switch (sort) {
      case _TransactionSort.newest:
        items.sort((a, b) => b.date.compareTo(a.date));
      case _TransactionSort.oldest:
        items.sort((a, b) => a.date.compareTo(b.date));
      case _TransactionSort.amountAsc:
        items.sort((a, b) => a.amount.compareTo(b.amount));
      case _TransactionSort.amountDesc:
        items.sort((a, b) => b.amount.compareTo(a.amount));
    }
    return items;
  }

  bool get hasFilters =>
      type != null ||
      accountId != null ||
      categoryId != null ||
      from != null ||
      to != null ||
      minAmount != null ||
      maxAmount != null ||
      withReceiptOnly ||
      advancesOnly ||
      unassignedOnly ||
      sort != _TransactionSort.newest;

  void _clearFilters() {
    setState(() {
      type = null;
      accountId = null;
      categoryId = null;
      from = null;
      to = null;
      minAmount = null;
      maxAmount = null;
      withReceiptOnly = false;
      advancesOnly = false;
      unassignedOnly = false;
      sort = _TransactionSort.newest;
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (!selected.add(id)) selected.remove(id);
    });
  }

  Future<void> _bulkDelete(AppState state) async {
    if (selected.isEmpty) return;
    final count = selected.length;
    final ok = await confirmDestructiveAction(
      context,
      title: 'Eliminare $count movimenti?',
      message: 'I saldi dei conti verranno ricalcolati automaticamente.',
      confirmLabel: 'Elimina $count',
    );
    if (!ok) return;
    final items = state.transactions
        .where((item) => selected.contains(item.id))
        .toList();
    for (final item in items) {
      await state.deleteTransaction(item);
    }
    if (mounted) setState(selected.clear);
  }

  Future<void> _bulkCategory(AppState state) async {
    final candidates = state.categoriesFor(TransactionType.expense);
    if (selected.isEmpty || candidates.isEmpty) return;
    final chosen = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Text(
            'Cambia categoria',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          ...candidates.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                categoryIcon(item.iconKey),
                color: Color(item.colorValue),
              ),
              title: Text(item.name),
              onTap: () => Navigator.pop(context, item.id),
            ),
          ),
        ],
      ),
    );
    if (chosen == null) return;
    final targets = state.transactions
        .where(
          (item) =>
              selected.contains(item.id) &&
              item.type == TransactionType.expense,
        )
        .toList();
    for (final item in targets) {
      await state.updateTransaction(
        item,
        item.copyWith(categoryId: chosen, updatedAt: DateTime.now()),
      );
    }
    if (mounted) setState(selected.clear);
  }

  Future<void> _bulkAccount(AppState state) async {
    final accounts = state.activeAccounts
        .where((item) => !item.isLocked)
        .toList();
    if (selected.isEmpty || accounts.isEmpty) return;
    final chosen = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Text(
            'Sposta su conto',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          ...accounts.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                accountIcon(item.iconKey),
                color: Color(item.colorValue),
              ),
              title: Text(item.name),
              onTap: () => Navigator.pop(context, item.id),
            ),
          ),
        ],
      ),
    );
    if (chosen == null) return;
    final targets = state.transactions
        .where(
          (item) =>
              selected.contains(item.id) &&
              item.type != TransactionType.transfer,
        )
        .toList();
    for (final item in targets) {
      await state.updateTransaction(
        item,
        item.copyWith(accountId: chosen, updatedAt: DateTime.now()),
      );
    }
    if (mounted) setState(selected.clear);
  }

  Future<void> _bulkAnalytics(AppState state, bool include) async {
    final targets = state.transactions
        .where((item) => selected.contains(item.id))
        .toList();
    for (final item in targets) {
      await state.updateTransaction(
        item,
        item.copyWith(includeInAnalytics: include, updatedAt: DateTime.now()),
      );
    }
    if (mounted) setState(selected.clear);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final items = _filtered(state);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          selected.isEmpty ? 'Movimenti' : '${selected.length} selezionati',
        ),
        leading: selected.isEmpty
            ? null
            : IconButton(
                tooltip: 'Annulla selezione',
                onPressed: () => setState(selected.clear),
                icon: const Icon(Icons.close_rounded),
              ),
        actions: selected.isEmpty
            ? [
                IconButton(
                  tooltip: 'Filtri',
                  onPressed: () => _showFilters(context, state),
                  icon: Badge(
                    isLabelVisible: hasFilters,
                    child: const Icon(Icons.tune_rounded),
                  ),
                ),
              ]
            : [
                PopupMenuButton<String>(
                  tooltip: 'Azioni multiple',
                  onSelected: (value) async {
                    if (value == 'category') await _bulkCategory(state);
                    if (value == 'account') await _bulkAccount(state);
                    if (value == 'include') await _bulkAnalytics(state, true);
                    if (value == 'exclude') await _bulkAnalytics(state, false);
                    if (value == 'delete') await _bulkDelete(state);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'category',
                      child: Text('Cambia categoria spese'),
                    ),
                    const PopupMenuItem(
                      value: 'account',
                      child: Text('Cambia conto'),
                    ),
                    const PopupMenuItem(
                      value: 'include',
                      child: Text('Includi nelle statistiche'),
                    ),
                    const PopupMenuItem(
                      value: 'exclude',
                      child: Text('Escludi dalle statistiche'),
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
          if (hasFilters)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (advancesOnly)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Chip(label: Text('Anticipi')),
                    ),
                  if (unassignedOnly)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Chip(label: Text('Non assegnati')),
                    ),
                  if (type != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(label: Text(type!.label)),
                    ),
                  if (accountId != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          state.accountById(accountId)?.name ?? 'Conto',
                        ),
                      ),
                    ),
                  if (categoryId != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          state.categoryById(categoryId)?.name ?? 'Categoria',
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Azzera'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: state.transactions.isEmpty
                        ? 'Nessun movimento'
                        : 'Nessun risultato',
                    subtitle: state.transactions.isEmpty
                        ? 'Aggiungi una spesa, un’entrata o un trasferimento.'
                        : 'Prova a modificare ricerca o filtri.',
                    action: state.transactions.isEmpty
                        ? FilledButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const QuickAddPage(),
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Nuovo movimento'),
                          )
                        : null,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _SelectableTransactionTile(
                        item: item,
                        selected: selected.contains(item.id),
                        selectionMode: selected.isNotEmpty,
                        onSelect: () => _toggleSelection(item.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilters(BuildContext context, AppState state) async {
    var draftType = type;
    var draftAccount = accountId;
    var draftCategory = categoryId;
    var draftFrom = from;
    var draftTo = to;
    var draftMin = minAmount;
    var draftMax = maxAmount;
    var draftReceipt = withReceiptOnly;
    var draftAdvances = advancesOnly;
    var draftUnassigned = unassignedOnly;
    var draftSort = sort;
    final minController = TextEditingController(
      text: minAmount?.toString() ?? '',
    );
    final maxController = TextEditingController(
      text: maxAmount?.toString() ?? '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final availableCategories =
              draftType == null || draftType == TransactionType.transfer
              ? state.categories
              : state.categoriesFor(draftType!);
          if (draftCategory != null &&
              !availableCategories.any((item) => item.id == draftCategory)) {
            draftCategory = null;
          }
          return Padding(
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
                    'Filtra movimenti',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
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
                    initialValue: draftAccount,
                    decoration: const InputDecoration(labelText: 'Conto'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tutti i conti'),
                      ),
                      ...state.userAccounts.map(
                        (item) => DropdownMenuItem<int?>(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => draftAccount = value,
                  ),
                  DropdownButtonFormField<int?>(
                    key: ValueKey('filter-category-$draftType-$draftCategory'),
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
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minController,
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
                          controller: maxController,
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
                      if (picked != null)
                        setSheetState(() => draftFrom = picked);
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Solo con ricevuta'),
                    value: draftReceipt,
                    onChanged: (value) =>
                        setSheetState(() => draftReceipt = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.handshake_outlined),
                    title: const Text('Solo Anticipi'),
                    subtitle: const Text(
                      'Include anticipi, rimborsi e restituzioni.',
                    ),
                    value: draftAdvances,
                    onChanged: (value) =>
                        setSheetState(() => draftAdvances = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Solo Non assegnati'),
                    value: draftUnassigned,
                    onChanged: (value) =>
                        setSheetState(() => draftUnassigned = value),
                  ),
                  DropdownButtonFormField<_TransactionSort>(
                    initialValue: draftSort,
                    decoration: const InputDecoration(labelText: 'Ordina'),
                    items: const [
                      DropdownMenuItem(
                        value: _TransactionSort.newest,
                        child: Text('Più recenti'),
                      ),
                      DropdownMenuItem(
                        value: _TransactionSort.oldest,
                        child: Text('Più vecchi'),
                      ),
                      DropdownMenuItem(
                        value: _TransactionSort.amountAsc,
                        child: Text('Importo crescente'),
                      ),
                      DropdownMenuItem(
                        value: _TransactionSort.amountDesc,
                        child: Text('Importo decrescente'),
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
                            Navigator.pop(context);
                          },
                          child: const Text('Azzera'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            draftMin = minController.text.trim().isEmpty
                                ? null
                                : double.tryParse(
                                    minController.text.replaceAll(',', '.'),
                                  );
                            draftMax = maxController.text.trim().isEmpty
                                ? null
                                : double.tryParse(
                                    maxController.text.replaceAll(',', '.'),
                                  );
                            setState(() {
                              type = draftType;
                              accountId = draftAccount;
                              categoryId = draftCategory;
                              from = draftFrom;
                              to = draftTo;
                              minAmount = draftMin;
                              maxAmount = draftMax;
                              withReceiptOnly = draftReceipt;
                              advancesOnly = draftAdvances;
                              unassignedOnly = draftUnassigned;
                              sort = draftSort;
                            });
                            Navigator.pop(context);
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
    minController.dispose();
    maxController.dispose();
  }
}

class _SelectableTransactionTile extends StatelessWidget {
  const _SelectableTransactionTile({
    required this.item,
    required this.selected,
    required this.selectionMode,
    required this.onSelect,
  });

  final FinanceTransaction item;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final category = state.categoryById(item.categoryId);
    final account = state.accountById(item.accountId);
    final sourceAdvance = state.advanceForSourceTransaction(item.id);
    final settlementAdvance = state.advanceForSettlementTransaction(item.id);
    final linkedAdvance = sourceAdvance ?? settlementAdvance;
    final person = state.personById(linkedAdvance?.personId);
    final protected = state.isAdvanceProtectedTransaction(item);
    final advanceTitle = switch (item.kind) {
      'advance_origin' when linkedAdvance?.direction.name == 'receivable' =>
        'Anticipo a ${person?.name ?? 'persona'}',
      'advance_origin' => 'Anticipo da ${person?.name ?? 'persona'}',
      'advance_settlement' when linkedAdvance?.direction.name == 'receivable' =>
        'Rimborso da ${person?.name ?? 'persona'}',
      'advance_settlement' => 'Restituzione a ${person?.name ?? 'persona'}',
      'advance_writeoff' => 'Anticipo non recuperato',
      'advance_forgiven_income' => 'Anticipo condonato',
      _ => null,
    };
    return ListTile(
      selected: selected,
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 10,
      leading: selectionMode
          ? Checkbox(value: selected, onChanged: (_) => onSelect())
          : CircleAvatar(
              backgroundColor: category == null
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Color(category.colorValue).withValues(alpha: .13),
              child: Icon(
                category == null
                    ? item.type == TransactionType.transfer
                          ? Icons.swap_horiz_rounded
                          : Icons.receipt_long_rounded
                    : categoryIcon(category.iconKey),
                color: category == null ? null : Color(category.colorValue),
              ),
            ),
      title: Text(
        advanceTitle ??
            (item.type == TransactionType.transfer
                ? 'Trasferimento'
                : category?.name ?? 'Senza categoria'),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [
          account?.isSystem == true
              ? 'Non assegnato'
              : account?.name ?? 'Conto',
          DateFormat('dd MMM, HH:mm', 'it_IT').format(item.date),
          if (item.kind == 'mixed_advance' && sourceAdvance != null)
            'Include ${moneyFor(state, Money.fromCents(sourceAdvance.originalAmountCents))} anticipati a ${person?.name ?? 'persona'}',
          if (linkedAdvance != null && item.kind == 'advance_settlement')
            '${moneyFor(state, Money.fromCents(state.advanceRemainingCents(linkedAdvance.id)))} residui',
          if (item.note?.isNotEmpty == true) item.note!,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        item.type == TransactionType.expense
            ? '-${moneyFor(state, item.amount)}'
            : item.type == TransactionType.income
            ? '+${moneyFor(state, item.amount)}'
            : moneyFor(state, item.amount),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: transactionColor(context, item.type),
        ),
      ),
      onLongPress: protected ? null : onSelect,
      onTap: selectionMode
          ? (protected ? null : onSelect)
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    linkedAdvance != null && item.kind != 'mixed_advance'
                    ? AdvanceDetailScreen(advanceId: linkedAdvance.id)
                    : TransactionDetailPage(transactionId: item.id),
              ),
            ),
    );
  }
}

enum _AnalyticsPeriod { week, month, year, custom }

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _AnalyticsPeriod period = _AnalyticsPeriod.month;
  DateTime? customFrom;
  DateTime? customTo;

  (DateTime, DateTime) _range() {
    final now = DateTime.now();
    return switch (period) {
      _AnalyticsPeriod.week => (
        DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1)),
        DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1))
            .add(const Duration(days: 7)),
      ),
      _AnalyticsPeriod.month => (
        DateTime(now.year, now.month),
        DateTime(now.year, now.month + 1),
      ),
      _AnalyticsPeriod.year => (DateTime(now.year), DateTime(now.year + 1)),
      _AnalyticsPeriod.custom => (
        customFrom ?? DateTime(now.year, now.month),
        (customTo ?? now).add(const Duration(days: 1)),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final (from, to) = _range();
    final income = state.periodTotal(TransactionType.income, from, to);
    final expense = state.periodTotal(TransactionType.expense, from, to);
    final net = income - expense;
    final transactions = state
        .analyticTransactions(from: from, to: to)
        .toList();
    final previousFrom = from.subtract(to.difference(from));
    final previousExpense = state.periodTotal(
      TransactionType.expense,
      previousFrom,
      from,
    );
    final change = previousExpense == 0
        ? null
        : (expense - previousExpense) / previousExpense * 100;
    final categoryTotals = _categoryTotals(state, transactions);
    final tagTotals = _tagTotals(transactions);
    final accountTotals = _accountTotals(state, transactions);
    final largest = transactions.isEmpty
        ? null
        : transactions.reduce((a, b) => a.amount >= b.amount ? a : b);
    final days = math.max(1, to.difference(from).inDays);
    final spentDays = transactions
        .where((item) => item.type == TransactionType.expense)
        .map((item) => '${item.date.year}-${item.date.month}-${item.date.day}')
        .toSet()
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Analisi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<_AnalyticsPeriod>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _AnalyticsPeriod.week,
                  label: Text('Settimana'),
                ),
                ButtonSegment(
                  value: _AnalyticsPeriod.month,
                  label: Text('Mese'),
                ),
                ButtonSegment(
                  value: _AnalyticsPeriod.year,
                  label: Text('Anno'),
                ),
                ButtonSegment(
                  value: _AnalyticsPeriod.custom,
                  label: Text('Custom'),
                ),
              ],
              selected: {period},
              onSelectionChanged: (value) async {
                final next = value.first;
                if (next == _AnalyticsPeriod.custom) {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDateRange: DateTimeRange(
                      start:
                          customFrom ??
                          DateTime(DateTime.now().year, DateTime.now().month),
                      end: customTo ?? DateTime.now(),
                    ),
                  );
                  if (range == null) return;
                  setState(() {
                    customFrom = range.start;
                    customTo = range.end;
                    period = next;
                  });
                } else {
                  setState(() => period = next);
                }
              },
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _AnalyticsMetric(
                  label: 'Entrate',
                  value: moneyFor(state, income),
                  color: context.financeColors.positive,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _AnalyticsMetric(
                  label: 'Spese',
                  value: moneyFor(state, expense),
                  color: context.financeColors.negative,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AnalyticsMetric(
            label: 'Netto',
            value: moneyFor(state, net, signed: true),
            color: net >= 0
                ? context.financeColors.positive
                : context.financeColors.negative,
          ),
          const SizedBox(height: 28),
          SectionTitle(
            'Andamento',
            trailing: change == null
                ? null
                : Text(
                    '${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}% vs periodo precedente',
                  ),
          ),
          SizedBox(
            height: 230,
            child: _PeriodChart(state: state, from: from, to: to),
          ),
          const SizedBox(height: 30),
          const SectionTitle('Categorie di spesa'),
          if (categoryTotals.isEmpty)
            const Text('Nessun dato')
          else
            ...categoryTotals
                .take(6)
                .map(
                  (entry) => FlatMetric(
                    label: entry.$1.name,
                    value: moneyFor(state, entry.$2),
                    icon: categoryIcon(entry.$1.iconKey),
                    color: Color(entry.$1.colorValue),
                  ),
                ),
          const SizedBox(height: 28),
          const SectionTitle('Indicatori'),
          FlatMetric(
            label: 'Media spesa giornaliera',
            value: moneyFor(state, expense / days),
            icon: Icons.av_timer_rounded,
          ),
          const Divider(height: 1),
          FlatMetric(
            label: 'Giorni senza spese',
            value: '${math.max(0, days - spentDays)}',
            icon: Icons.event_available_outlined,
          ),
          const Divider(height: 1),
          FlatMetric(
            label: 'Numero movimenti',
            value: '${transactions.length}',
            icon: Icons.receipt_long_outlined,
          ),
          if (largest != null) ...[
            const Divider(height: 1),
            FlatMetric(
              label: 'Movimento maggiore',
              value: moneyFor(state, largest.amount),
              icon: Icons.north_east_rounded,
            ),
          ],
          if (tagTotals.isNotEmpty) ...[
            const SizedBox(height: 28),
            const SectionTitle('Top tag'),
            ...tagTotals
                .take(5)
                .map(
                  (entry) => FlatMetric(
                    label: '#${entry.$1}',
                    value: moneyFor(state, entry.$2),
                    icon: Icons.tag_rounded,
                  ),
                ),
          ],
          if (accountTotals.isNotEmpty) ...[
            const SizedBox(height: 28),
            const SectionTitle('Spese per conto'),
            ...accountTotals
                .take(5)
                .map(
                  (entry) => FlatMetric(
                    label: entry.$1.name,
                    value: moneyFor(state, entry.$2),
                    icon: accountIcon(entry.$1.iconKey),
                    color: Color(entry.$1.colorValue),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AccountDetailPage(accountId: entry.$1.id),
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _AnalyticsMetric extends StatelessWidget {
  const _AnalyticsMetric({
    required this.label,
    required this.value,
    this.color,
  });
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 4),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(color: color),
      ),
    ],
  );
}

class _PeriodChart extends StatelessWidget {
  const _PeriodChart({
    required this.state,
    required this.from,
    required this.to,
  });
  final AppState state;
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    final days = math.max(1, to.difference(from).inDays);
    final buckets = days <= 14 ? days : math.min(12, days);
    final bucketDays = math.max(1, (days / buckets).ceil());
    final groups = <BarChartGroupData>[];
    for (var index = 0; index < buckets; index++) {
      final start = from.add(Duration(days: index * bucketDays));
      final end = start.add(Duration(days: bucketDays));
      final income = state.periodTotal(TransactionType.income, start, end);
      final expense = state.periodTotal(TransactionType.expense, start, end);
      groups.add(
        BarChartGroupData(
          x: index,
          barsSpace: 3,
          barRods: [
            BarChartRodData(
              toY: income,
              width: 7,
              borderRadius: BorderRadius.circular(3),
              color: context.financeColors.positive,
            ),
            BarChartRodData(
              toY: expense,
              width: 7,
              borderRadius: BorderRadius.circular(3),
              color: context.financeColors.negative,
            ),
          ],
        ),
      );
    }
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: groups,
      ),
    );
  }
}

List<(Category, double)> _categoryTotals(
  AppState state,
  List<FinanceTransaction> transactions,
) {
  final totals = <int, double>{};
  for (final item in transactions.where(
    (item) => item.type == TransactionType.expense,
  )) {
    final splits = state.splitsFor(item.id);
    if (splits.isNotEmpty) {
      for (final split in splits) {
        totals[split.categoryId] =
            (totals[split.categoryId] ?? 0) + split.amount;
      }
    } else if (item.categoryId != null) {
      totals[item.categoryId!] =
          (totals[item.categoryId!] ?? 0) + state.effectiveExpense(item);
    }
  }
  final result = <(Category, double)>[];
  for (final entry in totals.entries) {
    final category = state.categoryById(entry.key);
    if (category != null) result.add((category, entry.value));
  }
  result.sort((a, b) => b.$2.compareTo(a.$2));
  return result;
}

List<(String, double)> _tagTotals(List<FinanceTransaction> transactions) {
  final totals = <String, double>{};
  for (final item in transactions.where(
    (item) => item.type == TransactionType.expense,
  )) {
    for (final tag in item.tags) {
      totals[tag] = (totals[tag] ?? 0) + item.amount;
    }
  }
  final result = totals.entries
      .map((entry) => (entry.key, entry.value))
      .toList();
  result.sort((a, b) => b.$2.compareTo(a.$2));
  return result;
}

List<(Account, double)> _accountTotals(
  AppState state,
  List<FinanceTransaction> transactions,
) {
  final totals = <int, double>{};
  for (final item in transactions.where(
    (item) => item.type == TransactionType.expense,
  )) {
    final account = state.accountById(item.accountId);
    if (account == null || account.isSystem) continue;
    totals[item.accountId] =
        (totals[item.accountId] ?? 0) + state.effectiveExpense(item);
  }
  final result = <(Account, double)>[];
  for (final entry in totals.entries) {
    final account = state.accountById(entry.key);
    if (account != null) result.add((account, entry.value));
  }
  result.sort((a, b) => b.$2.compareTo(a.$2));
  return result;
}

class NetWorthScreen extends StatelessWidget {
  const NetWorthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final snapshots = state.netWorthSnapshots;
    final values = snapshots
        .map((row) => (row['amount'] as num).toDouble())
        .toList();
    final delta = values.length < 2 ? null : values.last - values.first;
    final spots = <FlSpot>[];
    for (var index = 0; index < values.length; index++) {
      spots.add(FlSpot(index.toDouble(), values[index]));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Patrimonio netto')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Text(
            'PATRIMONIO ATTUALE',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(letterSpacing: 1.1),
          ),
          const SizedBox(height: 6),
          Text(
            state.hideBalance ? '••••••' : moneyFor(state, state.totalBalance),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          if (delta != null) ...[
            const SizedBox(height: 5),
            Text(
              '${delta >= 0 ? '+' : ''}${moneyFor(state, delta.abs())} dal primo snapshot',
              style: TextStyle(
                color: delta >= 0
                    ? context.financeColors.positive
                    : context.financeColors.negative,
              ),
            ),
          ],
          const SizedBox(height: 30),
          SizedBox(
            height: 250,
            child: spots.length < 2
                ? const Center(
                    child: Text(
                      'Lo storico si costruisce automaticamente durante l’uso.',
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          barWidth: 3,
                          color: Theme.of(context).colorScheme.primary,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 28),
          const SectionTitle('Conti inclusi'),
          ...state.activeAccounts
              .where((item) => item.includeInTotal)
              .map(
                (item) => FlatMetric(
                  label: item.name,
                  value: state.hideBalance || item.hideBalance
                      ? '••••'
                      : moneyFor(state, item.balance),
                  icon: accountIcon(item.iconKey),
                  color: Color(item.colorValue),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AccountDetailPage(accountId: item.id),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

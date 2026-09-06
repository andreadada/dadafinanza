import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../core/money.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/quick_preset_service.dart';
import '../widgets/finance_quick_action.dart';
import '../widgets/ui_helpers.dart';
import 'account_management_screen.dart';
import 'advances_screen.dart';
import 'category_management_screen.dart';
import 'personal_settings_screen.dart';
import 'planning_screens.dart';
import 'quick_add_page.dart';
import 'root_screen.dart' show TransactionsScreen;
import 'transaction_screens.dart';

class CanonicalRootScreen extends StatefulWidget {
  const CanonicalRootScreen({super.key});

  @override
  State<CanonicalRootScreen> createState() => _CanonicalRootScreenState();
}

class _CanonicalRootScreenState extends State<CanonicalRootScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [
      CanonicalHomeScreen(),
      TransactionsScreen(),
      CanonicalAnalyticsScreen(),
      PlanningScreen(),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: index, children: pages),
      ),
      floatingActionButton: GestureDetector(
        onLongPress: _showQuickMenu,
        child: FloatingActionButton(
          tooltip: 'Nuovo movimento. Tieni premuto per preset e scorciatoie.',
          onPressed: () => _openQuick(TransactionType.expense),
          child: const Icon(Icons.add_rounded),
        ),
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

  Future<void> _openQuick(TransactionType type, {QuickPreset? preset}) async {
    final state = AppScope.of(context);
    int? preferredAccount = preset?.accountId;
    int? preferredDestination = preset?.toAccountId;
    if (preferredAccount == null) {
      final key = switch (type) {
        TransactionType.expense => 'preferred_expense_account',
        TransactionType.income => 'preferred_income_account',
        TransactionType.transfer => 'preferred_transfer_source',
      };
      preferredAccount = int.tryParse(
        await state.database.getSetting(key) ?? '',
      );
    }
    if (type == TransactionType.transfer && preferredDestination == null) {
      preferredDestination = int.tryParse(
        await state.database.getSetting('preferred_transfer_destination') ?? '',
      );
    }
    if (!mounted) return;
    final category = preset?.categoryId == null
        ? null
        : state.categoryById(preset!.categoryId)?.name;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuickAddPage(
          initialTypeName: type.name,
          initialAccountId: preferredAccount,
          initialToAccountId: preferredDestination,
          initialCategoryName: category,
          initialAmount: preset?.amount,
        ),
      ),
    );
  }

  Future<void> _showQuickMenu() async {
    final state = AppScope.of(context);
    final presets = await QuickPresetService(state.database)
        .all(enabledOnly: true);
    if (!mounted) return;
    final choice = await showModalBottomSheet<Object>(
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
              'Nuovo movimento',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FinanceQuickAction(
                    icon: Icons.arrow_upward_rounded,
                    label: 'Spesa',
                    onTap: () =>
                        Navigator.pop(sheetContext, TransactionType.expense),
                  ),
                ),
                Expanded(
                  child: FinanceQuickAction(
                    icon: Icons.arrow_downward_rounded,
                    label: 'Entrata',
                    onTap: () =>
                        Navigator.pop(sheetContext, TransactionType.income),
                  ),
                ),
                Expanded(
                  child: FinanceQuickAction(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Trasferisci',
                    onTap: () =>
                        Navigator.pop(sheetContext, TransactionType.transfer),
                  ),
                ),
              ],
            ),
            if (presets.isNotEmpty) ...[
              const SizedBox(height: 20),
              const SectionTitle('Preset'),
              ...presets
                  .take(6)
                  .map(
                    (preset) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      minVerticalPadding: 8,
                      leading: const Icon(Icons.bookmark_outline_rounded),
                      title: Text(preset.name),
                      subtitle: Text(
                        [
                          preset.type.label,
                          if (preset.amount != null)
                            moneyFor(state, preset.amount!),
                        ].join(' · '),
                      ),
                      onTap: () => Navigator.pop(sheetContext, preset),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice is QuickPreset) {
      await _openQuick(choice.type, preset: choice);
    } else if (choice is TransactionType) {
      await _openQuick(choice);
    }
  }
}

class CanonicalHomeScreen extends StatelessWidget {
  const CanonicalHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final enabled = [...state.dashboardWidgets]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final visibleWidgets = enabled
        .where((item) => item.enabled && !_fixedTypes.contains(item.type))
        .toList();
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
              tooltip: 'Impostazioni',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PersonalSettingsScreen(),
                ),
              ),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          sliver: SliverList.list(
            children: [
              Text(
                'PATRIMONIO',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              Text(
                state.hideBalance
                    ? '••••••'
                    : moneyFor(state, state.totalBalance),
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'Entrate',
                      value: moneyFor(
                        state,
                        state.monthTotal(TransactionType.income),
                      ),
                      color: context.financeColors.positive,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _Metric(
                      label: 'Spese',
                      value: moneyFor(
                        state,
                        state.monthTotal(TransactionType.expense),
                      ),
                      color: context.financeColors.negative,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _Metric(
                      label: 'Disponibile',
                      value: state.hideBalance
                          ? '••••'
                          : moneyFor(state, state.safeToSpend),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FinanceQuickAction(
                      icon: Icons.arrow_upward_rounded,
                      label: 'Spesa',
                      color: context.financeColors.negative,
                      onTap: () => _open(context, TransactionType.expense),
                    ),
                  ),
                  Expanded(
                    child: FinanceQuickAction(
                      icon: Icons.arrow_downward_rounded,
                      label: 'Entrata',
                      color: context.financeColors.positive,
                      onTap: () => _open(context, TransactionType.income),
                    ),
                  ),
                  Expanded(
                    child: FinanceQuickAction(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Trasferisci',
                      onTap: () => _open(context, TransactionType.transfer),
                    ),
                  ),
                ],
              ),
              if (_smartInsight(state) case final insight?) ...[
                const SizedBox(height: 28),
                const SectionTitle('Per te'),
                _InsightLine(insight: insight),
              ],
              const SizedBox(height: 30),
              SectionTitle(
                'Conti',
                trailing: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountManagementScreen(),
                    ),
                  ),
                  child: const Text('Tutti'),
                ),
              ),
              if (state.activeAccounts.isEmpty)
                const Text('Nessun conto')
              else
                ...state.activeAccounts
                    .take(4)
                    .map(
                      (account) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        minVerticalPadding: 10,
                        leading: Icon(
                          accountIcon(account.iconKey),
                          color: Color(account.colorValue),
                        ),
                        title: Text(account.name),
                        subtitle: Text(account.accountType.label),
                        trailing: Text(
                          state.hideBalance || account.hideBalance
                              ? '••••'
                              : moneyFor(state, account.balance),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SafeAccountDetailScreen(accountId: account.id),
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 28),
              ...visibleWidgets.map(
                (config) => Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: CanonicalDashboardWidget(config: config),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const _fixedTypes = {
    DashboardWidgetType.totalBalance,
    DashboardWidgetType.monthlyIncome,
    DashboardWidgetType.monthlyExpense,
    DashboardWidgetType.safeToSpend,
    DashboardWidgetType.accounts,
  };

  Future<void> _open(BuildContext context, TransactionType type) async {
    final state = AppScope.of(context);
    final key = switch (type) {
      TransactionType.expense => 'preferred_expense_account',
      TransactionType.income => 'preferred_income_account',
      TransactionType.transfer => 'preferred_transfer_source',
    };
    final accountId = int.tryParse(await state.database.getSetting(key) ?? '');
    final destination = type == TransactionType.transfer
        ? int.tryParse(
            await state.database.getSetting('preferred_transfer_destination') ??
                '',
          )
        : null;
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuickAddPage(
          initialTypeName: type.name,
          initialAccountId: accountId,
          initialToAccountId: destination,
        ),
      ),
    );
  }

  _HomeInsight? _smartInsight(AppState state) {
    if (state.smartGoalSuggestions) {
      for (final goal in state.goals.where(
        (item) => !item.archived && !item.completed,
      )) {
        final plan = state.goalPlan(goal);
        if (plan.status.name == 'slightlyBehind' ||
            plan.status.name == 'unrealistic') {
          return _HomeInsight(
            icon: Icons.flag_outlined,
            title: goal.name,
            detail: plan.realisticWeekly > 0
                ? '${moneyFor(state, plan.realisticWeekly)}/settimana è il ritmo realistico stimato.'
                : 'Il cash-flow attuale non lascia ancora un margine stabile.',
          );
        }
      }
    }
    if (state.detectedRecurringPatterns.isNotEmpty) {
      final pattern = state.detectedRecurringPatterns.first;
      return _HomeInsight(
        icon: Icons.event_repeat_rounded,
        title: 'Possibile ricorrenza',
        detail: '${pattern.normalizedText} · ${pattern.frequency}',
      );
    }
    return null;
  }
}

class _HomeInsight {
  const _HomeInsight({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;
}

class _InsightLine extends StatelessWidget {
  const _InsightLine({required this.insight});
  final _HomeInsight insight;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(insight.icon, size: 22),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              insight.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(insight.detail),
          ],
        ),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});
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
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: color),
        ),
      ),
    ],
  );
}

class CanonicalDashboardWidget extends StatelessWidget {
  const CanonicalDashboardWidget({required this.config, super.key});
  final DashboardWidgetConfig config;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final type = config.type;
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1);
    final expense = state.monthTotal(TransactionType.expense);
    final previousExpense = state.monthTotal(
      TransactionType.expense,
      month: previousMonth,
    );

    Widget metric(String value, {String? detail, IconData? icon}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(type.label),
        if (icon != null) Icon(icon, size: 22),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        if (detail != null) ...[
          const SizedBox(height: 4),
          Text(detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );

    switch (type) {
      case DashboardWidgetType.totalBalance:
      case DashboardWidgetType.monthlyIncome:
      case DashboardWidgetType.monthlyExpense:
      case DashboardWidgetType.safeToSpend:
      case DashboardWidgetType.accounts:
        return const SizedBox.shrink();
      case DashboardWidgetType.monthlyCashFlow:
        return metric(
          moneyFor(state, state.monthlyCashFlow, signed: true),
          detail:
              '${moneyFor(state, state.monthTotal(TransactionType.income))} entrate · ${moneyFor(state, expense)} spese',
          icon: Icons.compare_arrows_rounded,
        );
      case DashboardWidgetType.monthlyBudget:
      case DashboardWidgetType.closestBudget:
        final budgets = state.budgets.where((item) => item.enabled).toList()
          ..sort(
            (a, b) => state
                .budgetProgressFor(b)
                .compareTo(state.budgetProgressFor(a)),
          );
        if (budgets.isEmpty) {
          return metric('Nessun budget', icon: Icons.pie_chart_outline_rounded);
        }
        final budget = budgets.first;
        final progress = state.budgetProgressFor(budget);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              'Budget',
              trailing: Text('${(progress * 100).round()}%'),
            ),
            Text(budget.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.clamp(0, 1).toDouble(),
              minHeight: 6,
              borderRadius: BorderRadius.circular(99),
              color: progress >= 1
                  ? context.financeColors.negative
                  : progress >= .8
                  ? context.financeColors.warning
                  : null,
            ),
          ],
        );
      case DashboardWidgetType.netWorth:
        return metric(
          state.hideBalance ? '••••••' : moneyFor(state, state.totalBalance),
          detail: 'Patrimonio incluso nel totale',
          icon: Icons.show_chart_rounded,
        );
      case DashboardWidgetType.recentTransactions:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Ultimi movimenti'),
            if (state.transactions.isEmpty)
              const Text('Ancora nessun movimento')
            else
              ...state.transactions
                  .take(config.size == DashboardWidgetSize.large ? 6 : 3)
                  .map((item) => TransactionListTile(item: item)),
          ],
        );
      case DashboardWidgetType.todayExpense:
        return metric(
          moneyFor(state, state.todayExpense),
          icon: Icons.today_outlined,
        );
      case DashboardWidgetType.weekExpense:
        return metric(
          moneyFor(state, state.weekExpense),
          icon: Icons.date_range_outlined,
        );
      case DashboardWidgetType.previousMonthComparison:
        final delta = previousExpense == 0
            ? null
            : (expense - previousExpense) / previousExpense * 100;
        return metric(
          delta == null
              ? 'Servono più dati'
              : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}%',
          detail: 'rispetto al mese precedente',
          icon: Icons.compare_rounded,
        );
      case DashboardWidgetType.topCategories:
        final top = state.topExpenseCategories(
          limit: config.size == DashboardWidgetSize.large ? 5 : 3,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Categorie principali'),
            if (top.isEmpty)
              const Text('Nessun dato')
            else
              ...top.map(
                (entry) => FlatMetric(
                  label: entry.key.name,
                  value: moneyFor(state, entry.value),
                  icon: categoryIcon(entry.key.iconKey),
                  color: Color(entry.key.colorValue),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CategoryDetailScreen(categoryId: entry.key.id),
                    ),
                  ),
                ),
              ),
          ],
        );
      case DashboardWidgetType.upcomingRecurring:
      case DashboardWidgetType.financeCalendar:
        final items = state.recurring
            .where((item) => item.enabled)
            .take(4)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Prossime scadenze'),
            if (items.isEmpty)
              const Text('Nessuna scadenza configurata')
            else
              ...items.map(
                (item) => FlatMetric(
                  label:
                      '${item.name} · ${DateFormat('dd MMM', 'it_IT').format(item.nextDate)}',
                  value: moneyFor(state, item.amount),
                  icon: Icons.repeat_rounded,
                ),
              ),
          ],
        );
      case DashboardWidgetType.goals:
        final goals = state.goals
            .where((item) => !item.archived && !item.completed)
            .take(3);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Obiettivi'),
            if (goals.isEmpty)
              const Text('Nessun obiettivo attivo')
            else
              ...goals.map(
                (goal) => FlatMetric(
                  label: goal.name,
                  value:
                      '${moneyFor(state, goal.currentAmount)} / ${moneyFor(state, goal.targetAmount)}',
                  icon: Icons.flag_outlined,
                ),
              ),
          ],
        );
      case DashboardWidgetType.netWorthTrend:
        final points = state.netWorthSnapshots;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Andamento patrimonio'),
            SizedBox(
              height: 100,
              child: points.length < 2
                  ? const Center(child: Text('Servono più giorni di storico'))
                  : LineChart(
                      LineChartData(
                        titlesData: const FlTitlesData(show: false),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        lineTouchData: const LineTouchData(enabled: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < points.length; i++)
                                FlSpot(
                                  i.toDouble(),
                                  (points[i]['amount'] as num).toDouble(),
                                ),
                            ],
                            dotData: const FlDotData(show: false),
                            isCurved: true,
                            barWidth: 2,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      case DashboardWidgetType.dailyAverage:
        return metric(
          moneyFor(state, state.dailyAverageExpense),
          detail: 'media spesa giornaliera questo mese',
          icon: Icons.calculate_outlined,
        );
      case DashboardWidgetType.noSpendDays:
        return metric(
          '${state.noSpendDaysThisMonth}',
          detail: 'giorni senza spese questo mese',
          icon: Icons.event_available_outlined,
        );
      case DashboardWidgetType.endMonthForecast:
        return metric(
          state.hideBalance
              ? '••••••'
              : moneyFor(state, state.endOfMonthForecast),
          detail: 'scenario atteso · dati locali',
          icon: Icons.query_stats_rounded,
        );
      case DashboardWidgetType.unassignedTransactions:
        return metric(
          '${state.unassignedCount}',
          detail: state.unassignedCount == 1
              ? 'movimento da assegnare'
              : 'movimenti da assegnare',
          icon: Icons.help_outline_rounded,
        );
    }
  }
}

enum _AnalyticsPeriod { week, month, year, custom }

class CanonicalAnalyticsScreen extends StatefulWidget {
  const CanonicalAnalyticsScreen({super.key});

  @override
  State<CanonicalAnalyticsScreen> createState() =>
      _CanonicalAnalyticsScreenState();
}

class _CanonicalAnalyticsScreenState extends State<CanonicalAnalyticsScreen> {
  _AnalyticsPeriod period = _AnalyticsPeriod.month;
  DateTimeRange? custom;

  (DateTime, DateTime) _bounds(AppState state) {
    final now = DateTime.now();
    switch (period) {
      case _AnalyticsPeriod.week:
        final startWeekday = state.weekStart.clamp(1, 7);
        final offset = (now.weekday - startWeekday) % 7;
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: offset));
        return (start, start.add(const Duration(days: 7)));
      case _AnalyticsPeriod.month:
        final day = state.financialMonthStart.clamp(1, 28);
        var start = DateTime(now.year, now.month, day);
        if (now.isBefore(start)) start = DateTime(now.year, now.month - 1, day);
        return (start, DateTime(start.year, start.month + 1, day));
      case _AnalyticsPeriod.year:
        return (DateTime(now.year), DateTime(now.year + 1));
      case _AnalyticsPeriod.custom:
        final range = custom;
        if (range == null)
          return (
            DateTime(now.year, now.month),
            DateTime(now.year, now.month + 1),
          );
        return (
          DateTime(range.start.year, range.start.month, range.start.day),
          DateTime(range.end.year, range.end.month, range.end.day + 1),
        );
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
    final advanceSettled = state.advanceSettledInPeriodCents(from, to);
    final previousExpense = state.periodTotal(
      TransactionType.expense,
      previousFrom,
      from,
    );
    final savingsRate = income <= 0
        ? null
        : ((income - expense) / income * 100);
    final categories = <MapEntry<Category, double>>[];
    for (final category in state.categoriesFor(TransactionType.expense)) {
      var total = 0.0;
      for (final item
          in state
              .analyticTransactions(from: from, to: to)
              .where((t) => t.type == TransactionType.expense)) {
        final splits = state.splitsFor(item.id);
        if (splits.isNotEmpty) {
          total += splits
              .where((s) => s.categoryId == category.id)
              .fold<double>(
                0,
                (sum, s) => sum + state.analyticsAmountForSplit(item.id, s),
              );
        } else if (item.categoryId == category.id) {
          total += state.effectiveExpense(item);
        }
      }
      if (total > 0) categories.add(MapEntry(category, total));
    }
    categories.sort((a, b) => b.value.compareTo(a.value));
    final delta = previousExpense == 0
        ? null
        : (expense - previousExpense) / previousExpense * 100;
    final recurringMonthly = state.recurring
        .where((item) => item.enabled && item.type == TransactionType.expense)
        .fold<double>(0, (sum, item) {
          return sum +
              switch (item.frequency) {
                'Settimanale' => item.amount * 52 / 12,
                'Quindicinale' => item.amount * 26 / 12,
                'Trimestrale' => item.amount / 3,
                'Annuale' => item.amount / 12,
                _ => item.amount,
              };
        });
    return Scaffold(
      appBar: AppBar(title: const Text('Analisi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
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
                if (next != _AnalyticsPeriod.custom) {
                  setState(() => period = next);
                  return;
                }
                final now = DateTime.now();
                final result = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: now.add(const Duration(days: 3650)),
                  initialDateRange:
                      custom ??
                      DateTimeRange(
                        start: DateTime(now.year, now.month),
                        end: now,
                      ),
                );
                if (result != null && mounted) {
                  setState(() {
                    custom = result;
                    period = _AnalyticsPeriod.custom;
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '${DateFormat('d MMM', 'it_IT').format(from)} – ${DateFormat('d MMM', 'it_IT').format(to.subtract(const Duration(days: 1)))}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Entrate',
                  value: moneyFor(state, income),
                  color: context.financeColors.positive,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _Metric(
                  label: 'Spese',
                  value: moneyFor(state, expense),
                  color: context.financeColors.negative,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _Metric(
                  label: 'Risparmio',
                  value: savingsRate == null
                      ? '—'
                      : '${savingsRate.toStringAsFixed(0)}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _AnalyticsLine(
            icon: delta == null
                ? Icons.horizontal_rule_rounded
                : delta <= 0
                ? Icons.trending_down_rounded
                : Icons.trending_up_rounded,
            text: delta == null
                ? 'Servono più dati per confrontare il periodo precedente.'
                : 'Spese ${delta.abs().toStringAsFixed(0)}% ${delta <= 0 ? 'più basse' : 'più alte'} del periodo precedente.',
          ),
          const SizedBox(height: 10),
          _AnalyticsLine(
            icon: Icons.repeat_rounded,
            text:
                'Ricorrenti di spesa ≈ ${moneyFor(state, recurringMonthly)}/mese.',
          ),
          const SizedBox(height: 32),
          SectionTitle(
            'Anticipi',
            trailing: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdvancesScreen()),
              ),
              child: const Text('Apri'),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Da ricevere',
                  value: moneyFor(
                    state,
                    Money.fromCents(state.advanceReceivableCents),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _Metric(
                  label: 'Da restituire',
                  value: moneyFor(
                    state,
                    Money.fromCents(state.advancePayableCents),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _Metric(
                  label: 'Regolati',
                  value: moneyFor(state, Money.fromCents(advanceSettled)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const SectionTitle('Dove stai spendendo'),
          if (categories.isEmpty)
            const Text('Nessun dato nel periodo')
          else
            ...categories
                .take(8)
                .map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      categoryIcon(entry.key.iconKey),
                      color: Color(entry.key.colorValue),
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
                        builder: (_) =>
                            CategoryDetailScreen(categoryId: entry.key.id),
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 28),
          const SectionTitle('Per conto'),
          ...state.activeAccounts.map(
            (account) => FlatMetric(
              label: account.name,
              value: moneyFor(
                state,
                state.accountMonthTotal(account.id, TransactionType.income) -
                    state.accountMonthTotal(
                      account.id,
                      TransactionType.expense,
                    ),
                signed: true,
              ),
              icon: accountIcon(account.iconKey),
              color: Color(account.colorValue),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SafeAccountDetailScreen(accountId: account.id),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const SectionTitle('Budget'),
          if (state.budgets.where((item) => item.enabled).isEmpty)
            const Text('Nessun budget attivo')
          else
            ...state.budgets
                .where((item) => item.enabled)
                .take(6)
                .map(
                  (budget) => FlatMetric(
                    label: budget.name,
                    value:
                        '${(state.budgetProgressFor(budget) * 100).round()}%',
                    icon: Icons.pie_chart_outline_rounded,
                  ),
                ),
        ],
      ),
    );
  }
}

class _AnalyticsLine extends StatelessWidget {
  const _AnalyticsLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(text)),
    ],
  );
}

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/account_scope_service.dart';
import '../widgets/account_scope_selector.dart';
import '../widgets/ui_helpers.dart';
import 'account_management_screen.dart';

enum _AnalyticsPeriod { week, month, year, custom }

class AccountAnalyticsScreen extends StatefulWidget {
  const AccountAnalyticsScreen({
    required this.selectedAccountId,
    required this.onAccountChanged,
    super.key,
  });

  final int? selectedAccountId;
  final ValueChanged<int?> onAccountChanged;

  @override
  State<AccountAnalyticsScreen> createState() => _AccountAnalyticsScreenState();
}

class _AccountAnalyticsScreenState extends State<AccountAnalyticsScreen> {
  _AnalyticsPeriod period = _AnalyticsPeriod.month;
  DateTime? customFrom;
  DateTime? customTo;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final range = _range();
    final from = range.start;
    final to = range.end;
    final transactions = AccountScopeService.analyticTransactions(
      state,
      widget.selectedAccountId,
      from: from,
      to: to,
    );
    final income = AccountScopeService.periodTotal(
      state,
      widget.selectedAccountId,
      TransactionType.income,
      from,
      to,
    );
    final expense = AccountScopeService.periodTotal(
      state,
      widget.selectedAccountId,
      TransactionType.expense,
      from,
      to,
    );
    final net = income - expense;
    final previous = _previousRange(range);
    final previousExpense = AccountScopeService.periodTotal(
      state,
      widget.selectedAccountId,
      TransactionType.expense,
      previous.start,
      previous.end,
    );
    final change = previousExpense == 0
        ? null
        : (expense - previousExpense) / previousExpense * 100;
    final categoryTotals = _categoryTotals(state, transactions);
    final accountTotals = widget.selectedAccountId == null
        ? _accountTotals(state, transactions)
        : const <(Account, double)>[];
    final dayCount = math.max(1, to.difference(from).inDays);
    final spentDays = transactions
        .where((item) => item.type == TransactionType.expense)
        .map((item) => DateUtils.dateOnly(item.date))
        .toSet()
        .length;
    final largest = transactions.isEmpty
        ? null
        : ([...transactions]..sort((a, b) => b.amount.compareTo(a.amount))).first;

    return Scaffold(
      appBar: AppBar(
        title: AccountScopeSelector(
          selectedAccountId: widget.selectedAccountId,
          onChanged: widget.onAccountChanged,
        ),
      ),
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
              onSelectionChanged: _changePeriod,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Metric(
                  label: 'Entrate',
                  value: moneyFor(state, income),
                  color: context.financeColors.positive,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Metric(
                  label: 'Spese',
                  value: moneyFor(state, expense),
                  color: context.financeColors.negative,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Metric(
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
                    '${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}% spese vs periodo precedente',
                  ),
          ),
          SizedBox(
            height: 220,
            child: _PeriodChart(
              state: state,
              accountId: widget.selectedAccountId,
              from: from,
              to: to,
            ),
          ),
          const SizedBox(height: 30),
          const SectionTitle('Categorie di spesa'),
          if (categoryTotals.isEmpty)
            const Text('Nessun dato')
          else
            ...categoryTotals.take(8).map(
              (entry) => FlatMetric(
                label: entry.$1.name,
                value: moneyFor(state, entry.$2),
                icon: categoryIcon(entry.$1.iconKey),
                color: Color(entry.$1.colorValue),
              ),
            ),
          if (accountTotals.isNotEmpty) ...[
            const SizedBox(height: 28),
            const SectionTitle('Spese per conto'),
            ...accountTotals.take(8).map(
              (entry) => FlatMetric(
                label: entry.$1.name,
                value: moneyFor(state, entry.$2),
                icon: accountIcon(entry.$1.iconKey),
                color: Color(entry.$1.colorValue),
                onTap: () => widget.onAccountChanged(entry.$1.id),
              ),
            ),
          ],
          const SizedBox(height: 28),
          const SectionTitle('Indicatori'),
          FlatMetric(
            label: 'Media spesa giornaliera',
            value: moneyFor(state, expense / dayCount),
            icon: Icons.av_timer_rounded,
          ),
          const Divider(height: 1),
          FlatMetric(
            label: 'Giorni senza spese',
            value: '${math.max(0, dayCount - spentDays)}',
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
          if (widget.selectedAccountId != null) ...[
            const SizedBox(height: 28),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AccountManagementScreen(),
                ),
              ),
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Apri gestione conti'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _changePeriod(Set<_AnalyticsPeriod> values) async {
    final next = values.first;
    if (next == _AnalyticsPeriod.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDateRange: DateTimeRange(
          start: customFrom ?? DateTime(now.year, now.month),
          end: customTo ?? now,
        ),
      );
      if (picked == null || !mounted) return;
      setState(() {
        customFrom = picked.start;
        customTo = picked.end;
        period = next;
      });
      return;
    }
    setState(() => period = next);
  }

  DateTimeRange _range() {
    final now = DateTime.now();
    switch (period) {
      case _AnalyticsPeriod.week:
        final start = DateTime(now.year, now.month, now.day).subtract(
          Duration(days: now.weekday - DateTime.monday),
        );
        return DateTimeRange(
          start: start,
          end: start.add(const Duration(days: 7)),
        );
      case _AnalyticsPeriod.month:
        return DateTimeRange(
          start: DateTime(now.year, now.month),
          end: DateTime(now.year, now.month + 1),
        );
      case _AnalyticsPeriod.year:
        return DateTimeRange(
          start: DateTime(now.year),
          end: DateTime(now.year + 1),
        );
      case _AnalyticsPeriod.custom:
        return DateTimeRange(
          start: customFrom ?? DateTime(now.year, now.month),
          end: (customTo ?? now).add(const Duration(days: 1)),
        );
    }
  }

  DateTimeRange _previousRange(DateTimeRange current) {
    final duration = current.end.difference(current.start);
    return DateTimeRange(
      start: current.start.subtract(duration),
      end: current.start,
    );
  }
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
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: color),
        ),
      ),
    ],
  );
}

class _PeriodChart extends StatelessWidget {
  const _PeriodChart({
    required this.state,
    required this.accountId,
    required this.from,
    required this.to,
  });

  final AppState state;
  final int? accountId;
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
      final income = AccountScopeService.periodTotal(
        state,
        accountId,
        TransactionType.income,
        start,
        end,
      );
      final expense = AccountScopeService.periodTotal(
        state,
        accountId,
        TransactionType.expense,
        start,
        end,
      );
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/account_context_service.dart';
import '../widgets/account_context_selector.dart';
import '../widgets/ui_helpers.dart';
import 'account_management_screen.dart';
import 'transaction_screens.dart';

enum _AnalyticsPeriod { week, month, year, custom }

class AccountContextAnalyticsScreen extends StatefulWidget {
  const AccountContextAnalyticsScreen({
    required this.accountId,
    required this.onAccountChanged,
    super.key,
  });

  final int? accountId;
  final ValueChanged<int?> onAccountChanged;

  @override
  State<AccountContextAnalyticsScreen> createState() =>
      _AccountContextAnalyticsScreenState();
}

class _AccountContextAnalyticsScreenState
    extends State<AccountContextAnalyticsScreen> {
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
        if (range == null) {
          return (
            DateTime(now.year, now.month),
            DateTime(now.year, now.month + 1),
          );
        }
        return (
          DateTime(range.start.year, range.start.month, range.start.day),
          DateTime(range.end.year, range.end.month, range.end.day + 1),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final selected = state.accountById(widget.accountId);
    final effectiveAccountId =
        selected == null || selected.isArchived || selected.isSystem
        ? null
        : selected.id;
    final (from, to) = _bounds(state);
    final duration = to.difference(from);
    final previousFrom = from.subtract(duration);
    final income = AccountContextService.periodTotal(
      state,
      effectiveAccountId,
      TransactionType.income,
      from,
      to,
    );
    final expense = AccountContextService.periodTotal(
      state,
      effectiveAccountId,
      TransactionType.expense,
      from,
      to,
    );
    final previousExpense = AccountContextService.periodTotal(
      state,
      effectiveAccountId,
      TransactionType.expense,
      previousFrom,
      from,
    );
    final savingsRate = income <= 0
        ? null
        : ((income - expense) / income * 100);
    final delta = previousExpense == 0
        ? null
        : (expense - previousExpense) / previousExpense * 100;

    final analytic = AccountContextService.analyticTransactionsFor(
      state,
      effectiveAccountId,
      from: from,
      to: to,
    );
    final categoryTotals = <int, double>{};
    for (final item in analytic.where(
      (t) => t.type == TransactionType.expense,
    )) {
      final splits = state.splitsFor(item.id);
      if (splits.isNotEmpty) {
        for (final split in splits) {
          categoryTotals[split.categoryId] =
              (categoryTotals[split.categoryId] ?? 0) +
              state.analyticsAmountForSplit(item.id, split);
        }
      } else if (item.categoryId != null) {
        categoryTotals[item.categoryId!] =
            (categoryTotals[item.categoryId!] ?? 0) +
            state.effectiveExpense(item);
      }
    }
    final categories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final recurringMonthly =
        AccountContextService.recurringFor(state, effectiveAccountId)
            .where((item) => item.type == TransactionType.expense)
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
      appBar: AppBar(
        title: AccountContextSelector(
          accountId: effectiveAccountId,
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
            '${DateFormat('d MMM', 'it_IT').format(from)} – '
            '${DateFormat('d MMM', 'it_IT').format(to.subtract(const Duration(days: 1)))}',
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
                : 'Spese ${delta.abs().toStringAsFixed(0)}% '
                      '${delta <= 0 ? 'più basse' : 'più alte'} del periodo precedente.',
          ),
          const SizedBox(height: 10),
          _AnalyticsLine(
            icon: Icons.repeat_rounded,
            text:
                'Ricorrenti di spesa ≈ ${moneyFor(state, recurringMonthly)}/mese.',
          ),
          const SizedBox(height: 32),
          const SectionTitle('Dove stai spendendo'),
          if (categories.isEmpty)
            const Text('Nessun dato nel periodo')
          else
            ...categories.take(8).map((entry) {
              final category = state.categoryById(entry.key);
              if (category == null) return const SizedBox.shrink();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  categoryIcon(category.iconKey),
                  color: Color(category.colorValue),
                ),
                title: Text(category.name),
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
                    builder: (_) => _CategoryPeriodPage(
                      title: category.name,
                      accountId: effectiveAccountId,
                      categoryId: category.id,
                      from: from,
                      to: to,
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 28),
          if (effectiveAccountId == null) ...[
            const SectionTitle('Per conto'),
            ...state.activeAccounts.map(
              (account) => FlatMetric(
                label: account.name,
                value: moneyFor(
                  state,
                  AccountContextService.periodTotal(
                        state,
                        account.id,
                        TransactionType.income,
                        from,
                        to,
                      ) -
                      AccountContextService.periodTotal(
                        state,
                        account.id,
                        TransactionType.expense,
                        from,
                        to,
                      ),
                  signed: true,
                ),
                icon: accountIcon(account.iconKey),
                color: Color(account.colorValue),
                onTap: () => widget.onAccountChanged(account.id),
              ),
            ),
          ] else ...[
            const SectionTitle('Conto selezionato'),
            FlatMetric(
              label: selected!.name,
              value: state.hideBalance
                  ? '••••'
                  : moneyFor(state, selected.balance),
              icon: accountIcon(selected.iconKey),
              color: Color(selected.colorValue),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SafeAccountDetailScreen(accountId: selected.id),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryPeriodPage extends StatelessWidget {
  const _CategoryPeriodPage({
    required this.title,
    required this.accountId,
    required this.categoryId,
    required this.from,
    required this.to,
  });

  final String title;
  final int? accountId;
  final int categoryId;
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final items = AccountContextService.transactionsFor(state, accountId).where(
      (item) {
        if (item.date.isBefore(from) || !item.date.isBefore(to)) return false;
        if (item.categoryId == categoryId) return true;
        return state
            .splitsFor(item.id)
            .any((split) => split.categoryId == categoryId);
      },
    ).toList()..sort((a, b) => b.date.compareTo(a.date));
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: color),
        ),
      ),
    ],
  );
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

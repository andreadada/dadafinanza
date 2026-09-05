import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../main.dart';
import '../models/models.dart';
import '../widgets/finance_quick_action.dart';
import '../widgets/ui_helpers.dart';
import 'account_management_screen.dart';
import '../core/money.dart';
import 'account_screens.dart' show showAccountEditor;
import 'advances_screen.dart';
import 'canonical_shell.dart' show CanonicalDashboardWidget;
import 'personal_settings_screen.dart';
import 'planning_screens.dart';
import 'quick_add_page.dart';
import 'root_screen.dart' as advanced;
import 'transaction_screens.dart';

/// Canonical Home: the information density of the original DadaFinanza Home,
/// rebuilt with the current flat design system and the newer dashboard data.
///
/// The advanced dashboard is a secondary customizable workspace, not a second
/// application shell. It is intentionally reachable from the top app bar.
class DadaHomeScreen extends StatelessWidget {
  const DadaHomeScreen({super.key});

  static const _curatedTypes = {
    DashboardWidgetType.totalBalance,
    DashboardWidgetType.monthlyIncome,
    DashboardWidgetType.monthlyExpense,
    DashboardWidgetType.safeToSpend,
    DashboardWidgetType.accounts,
    DashboardWidgetType.recentTransactions,
    DashboardWidgetType.monthlyBudget,
    DashboardWidgetType.closestBudget,
    DashboardWidgetType.upcomingRecurring,
    DashboardWidgetType.unassignedTransactions,
  };

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final income = state.monthTotal(TransactionType.income);
    final expense = state.monthTotal(TransactionType.expense);
    final accounts = state.activeAccounts.take(4).toList();
    final recent = state.transactions.take(5).toList();
    final upcoming = state.recurring.where((item) => item.enabled).toList()
      ..sort((a, b) => a.nextDate.compareTo(b.nextDate));
    final budget = _priorityBudget(state);
    final insight = _smartInsight(state);
    final enabledWidgets = [...state.dashboardWidgets]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final extraWidgets = enabledWidgets
        .where((item) => item.enabled && !_curatedTypes.contains(item.type))
        .toList();

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
            IconButton(
              tooltip: 'Dashboard avanzata',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const advanced.HomeScreen()),
              ),
              icon: const Icon(Icons.dashboard_customize_outlined),
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
          sliver: SliverList.list(
            children: [
              if (state.userAccounts.isEmpty) ...[
                _SetupBlock(
                  onAccount: () => showAccountEditor(context),
                  onMovement: () =>
                      _openQuick(context, TransactionType.expense),
                ),
                const SizedBox(height: 32),
              ],
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'Entrate',
                      value: state.hideBalance
                          ? '••••'
                          : moneyFor(state, income),
                      color: context.financeColors.positive,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Metric(
                      label: 'Spese',
                      value: state.hideBalance
                          ? '••••'
                          : moneyFor(state, expense),
                      color: context.financeColors.negative,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                      onTap: () => _openQuick(context, TransactionType.expense),
                    ),
                  ),
                  Expanded(
                    child: FinanceQuickAction(
                      icon: Icons.arrow_downward_rounded,
                      label: 'Entrata',
                      color: context.financeColors.positive,
                      onTap: () => _openQuick(context, TransactionType.income),
                    ),
                  ),
                  Expanded(
                    child: FinanceQuickAction(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Trasferisci',
                      onTap: () =>
                          _openQuick(context, TransactionType.transfer),
                    ),
                  ),
                ],
              ),
              if (state.unassignedCount > 0) ...[
                const SizedBox(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.rule_folder_outlined,
                    color: context.financeColors.warning,
                  ),
                  title: Text(
                    '${state.unassignedCount} movimenti da assegnare',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Completa il conto per mantenere saldi e analisi ordinati.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const advanced.TransactionsScreen(
                        initialUnassignedOnly: true,
                      ),
                    ),
                  ),
                ),
              ],
              if (state.advanceReceivableCents > 0 ||
                  state.advancePayableCents > 0 ||
                  _smartInsight(state) != null) ...[
                const SizedBox(height: 28),
                const SectionTitle('Per te'),
                if (state.advanceReceivableCents > 0 ||
                    state.advancePayableCents > 0)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.handshake_outlined),
                    title: const Text('Anticipi'),
                    subtitle: Text(
                      '${moneyFor(state, Money.fromCents(state.advanceReceivableCents))} da ricevere · '
                      '${moneyFor(state, Money.fromCents(state.advancePayableCents))} da restituire',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdvancesScreen()),
                    ),
                  ),
                if (_smartInsight(state) case final insight?)
                  _InsightRow(insight: insight),
              ],
              const SizedBox(height: 32),
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
              if (accounts.isEmpty)
                EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Nessun conto',
                  subtitle:
                      'Aggiungi il conto che usi davvero oppure continua con movimenti Non assegnati.',
                  action: TextButton.icon(
                    onPressed: () => showAccountEditor(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Crea conto'),
                  ),
                )
              else
                ...accounts.map((account) => _AccountRow(account: account)),
              if (budget != null) ...[
                const SizedBox(height: 32),
                _BudgetSummary(budget: budget),
              ],
              const SizedBox(height: 32),
              const SectionTitle('Ultimi movimenti'),
              if (recent.isEmpty)
                const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Inizia dal primo movimento',
                  subtitle:
                      'Usa il pulsante + per registrare una spesa o un’entrata: analisi e previsioni nasceranno dai tuoi dati reali.',
                )
              else
                ...recent.map((item) => TransactionListTile(item: item)),
              const SizedBox(height: 32),
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
                  subtitle:
                      'Aggiungi bollette, abbonamenti o stipendio per prevedere il saldo futuro.',
                  action: TextButton.icon(
                    onPressed: () => showRecurringEditor(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Aggiungi ricorrenza'),
                  ),
                )
              else
                ...upcoming
                    .take(3)
                    .map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        minVerticalPadding: 10,
                        leading: Icon(
                          Icons.repeat_rounded,
                          color: transactionColor(context, item.type),
                        ),
                        title: Text(item.name),
                        subtitle: Text(
                          DateFormat(
                            'EEE d MMM',
                            'it_IT',
                          ).format(item.nextDate),
                        ),
                        trailing: Text(
                          state.hideBalance
                              ? '••••'
                              : moneyFor(state, item.amount),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RecurringScreen(),
                          ),
                        ),
                      ),
                    ),
              if (extraWidgets.isNotEmpty) ...[
                const SizedBox(height: 32),
                const SectionTitle('Riepilogo'),
                ...extraWidgets.map(
                  (config) => Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: CanonicalDashboardWidget(config: config),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Budget? _priorityBudget(AppState state) {
    final enabled = state.budgets.where((item) => item.enabled).toList();
    if (enabled.isEmpty) return null;
    enabled.sort(
      (a, b) =>
          state.budgetProgressFor(b).compareTo(state.budgetProgressFor(a)),
    );
    return enabled.first;
  }

  _HomeInsight? _smartInsight(AppState state) {
    if (!state.smartSuggestionsEnabled) return null;

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
            open: (context) => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GoalsScreen()),
            ),
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
        open: (context) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RecurringScreen()),
        ),
      );
    }
    return null;
  }

  Future<void> _openQuick(BuildContext context, TransactionType type) async {
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
}

class _SetupBlock extends StatelessWidget {
  const _SetupBlock({required this.onAccount, required this.onMovement});

  final VoidCallback onAccount;
  final VoidCallback onMovement;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Configura DadaFinanza',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      Text(
        'Parti dal primo conto oppure registra subito un movimento e assegnalo in seguito.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: onAccount,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crea primo conto'),
          ),
          TextButton.icon(
            onPressed: onMovement,
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Registra movimento'),
          ),
        ],
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
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
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
      minVerticalPadding: 10,
      leading: Icon(
        accountIcon(account.iconKey),
        color: Color(account.colorValue),
      ),
      title: Text(
        account.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [
          account.accountType.label,
          if (!account.includeInTotal) 'fuori patrimonio',
          if (account.isLocked) 'bloccato',
        ].join(' · '),
      ),
      trailing: Text(
        state.hideBalance || account.hideBalance
            ? '••••'
            : moneyFor(state, account.balance),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SafeAccountDetailScreen(accountId: account.id),
        ),
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
          SectionTitle(
            'Budget',
            trailing: Text('${(progress * 100).round()}%'),
          ),
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

class _HomeInsight {
  const _HomeInsight({
    required this.icon,
    required this.title,
    required this.detail,
    required this.open,
  });

  final IconData icon;
  final String title;
  final String detail;
  final void Function(BuildContext context) open;
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.insight});

  final _HomeInsight insight;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: 10,
    leading: Icon(insight.icon),
    title: Text(
      insight.title,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    subtitle: Text(insight.detail),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => insight.open(context),
  );
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../core/money.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/account_context_service.dart';
import '../widgets/account_context_selector.dart';
import '../widgets/finance_quick_action.dart';
import '../widgets/home_dashboard_widget.dart';
import '../widgets/ui_helpers.dart';
import 'account_management_screen.dart';
import 'account_screens.dart' show showAccountEditor;
import 'advances_screen.dart';
import 'personal_settings_screen.dart';
import 'planning_screens.dart';
import 'quick_add_page.dart';
import 'root_screen.dart' as advanced;
import 'settings_screen.dart' show DashboardCustomizerScreen;
import 'transaction_screens.dart';

class AccountContextHomeScreen extends StatelessWidget {
  const AccountContextHomeScreen({
    required this.accountId,
    required this.onAccountChanged,
    super.key,
  });

  static const _fallbackTypes = <DashboardWidgetType>[
    DashboardWidgetType.totalBalance,
    DashboardWidgetType.monthlyCashFlow,
    DashboardWidgetType.safeToSpend,
    DashboardWidgetType.accounts,
    DashboardWidgetType.monthlyBudget,
    DashboardWidgetType.recentTransactions,
    DashboardWidgetType.upcomingRecurring,
    DashboardWidgetType.goals,
    DashboardWidgetType.topCategories,
    DashboardWidgetType.endMonthForecast,
    DashboardWidgetType.unassignedTransactions,
  ];

  final int? accountId;
  final ValueChanged<int?> onAccountChanged;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final selectedAccount = state.accountById(accountId);
    final effectiveAccountId =
        selectedAccount == null ||
            selectedAccount.isArchived ||
            selectedAccount.isSystem
        ? null
        : selectedAccount.id;
    final isTotal = effectiveAccountId == null;
    final balance = AccountContextService.balanceFor(state, effectiveAccountId);
    final income = AccountContextService.monthTotal(
      state,
      effectiveAccountId,
      TransactionType.income,
    );
    final expense = AccountContextService.monthTotal(
      state,
      effectiveAccountId,
      TransactionType.expense,
    );
    final recent = AccountContextService.transactionsFor(
      state,
      effectiveAccountId,
    )..sort((a, b) => b.date.compareTo(a.date));
    final upcoming = AccountContextService.recurringFor(
      state,
      effectiveAccountId,
    );
    final smartInsight = isTotal ? _smartInsight(state) : null;
    final dashboardWidgets = isTotal
        ? _visibleDashboardWidgets(state)
        : const <DashboardWidgetConfig>[];

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AccountContextSelector(
                accountId: effectiveAccountId,
                onChanged: onAccountChanged,
              ),
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
                MaterialPageRoute(
                  builder: (_) => const Scaffold(body: advanced.HomeScreen()),
                ),
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
                  onMovement: () => _openQuick(
                    context,
                    TransactionType.expense,
                    effectiveAccountId,
                  ),
                ),
                const SizedBox(height: 32),
              ],
              _QuickActions(
                accountId: effectiveAccountId,
                onOpen: (type) => _openQuick(
                  context,
                  type,
                  effectiveAccountId,
                ),
              ),
              if (isTotal) ...[
                if (state.advanceReceivableCents > 0 ||
                    state.advancePayableCents > 0 ||
                    smartInsight != null) ...[
                  const SizedBox(height: 28),
                  const SectionTitle('Per te'),
                  if (state.advanceReceivableCents > 0 ||
                      state.advancePayableCents > 0)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.handshake_outlined),
                      title: const Text(
                        'Anticipi',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        state.hideBalance
                            ? '•••• da ricevere · •••• da restituire'
                            : '${moneyFor(state, Money.fromCents(state.advanceReceivableCents))} da ricevere · ${moneyFor(state, Money.fromCents(state.advancePayableCents))} da restituire',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdvancesScreen(),
                        ),
                      ),
                    ),
                  if (smartInsight case final insight?)
                    _InsightRow(insight: insight),
                ],
                const SizedBox(height: 30),
                if (dashboardWidgets.isEmpty)
                  EmptyState(
                    icon: Icons.dashboard_customize_outlined,
                    title: 'Home vuota',
                    subtitle:
                        'Hai nascosto tutti i widget. Riattivane almeno uno da Personalizza Home.',
                    action: TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DashboardCustomizerScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Personalizza Home'),
                    ),
                  )
                else
                  ...dashboardWidgets.map(
                    (config) => Padding(
                      key: ValueKey('context-home-${config.type.name}'),
                      padding: EdgeInsets.only(
                        bottom: switch (config.size) {
                          DashboardWidgetSize.small => 20,
                          DashboardWidgetSize.medium => 28,
                          DashboardWidgetSize.large => 36,
                        },
                      ),
                      child: HomeDashboardWidget(config: config),
                    ),
                  ),
              ] else ...[
                const SizedBox(height: 28),
                _SelectedAccountSummary(
                  account: selectedAccount!,
                  balance: balance,
                  income: income,
                  expense: expense,
                ),
                const SizedBox(height: 32),
                SectionTitle(
                  'Ultimi movimenti',
                  trailing: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SafeAccountDetailScreen(
                          accountId: selectedAccount.id,
                        ),
                      ),
                    ),
                    child: const Text('Apri conto'),
                  ),
                ),
                if (recent.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Nessun movimento',
                    subtitle: 'Non ci sono ancora movimenti per questo conto.',
                  )
                else
                  ...recent
                      .take(5)
                      .map((item) => TransactionListTile(item: item)),
                const SizedBox(height: 32),
                SectionTitle(
                  'Prossime scadenze',
                  trailing: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RecurringScreen(),
                      ),
                    ),
                    child: const Text('Apri'),
                  ),
                ),
                if (upcoming.isEmpty)
                  const Text('Nessuna scadenza prevista per questo conto')
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
                        state.hideBalance
                            ? '••••'
                            : moneyFor(state, item.amount),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<DashboardWidgetConfig> _visibleDashboardWidgets(AppState state) {
    if (state.dashboardWidgets.isEmpty) {
      return [
        for (var i = 0; i < _fallbackTypes.length; i++)
          DashboardWidgetConfig(
            type: _fallbackTypes[i],
            enabled: true,
            orderIndex: i,
            size: DashboardWidgetSize.medium,
          ),
      ];
    }
    final items = state.dashboardWidgets
        .where((item) => item.enabled)
        .toList(growable: false);
    return [...items]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
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

  Future<void> _openQuick(
    BuildContext context,
    TransactionType type,
    int? selectedAccountId,
  ) async {
    final state = AppScope.of(context);
    int? account = selectedAccountId;
    if (account == null) {
      final key = switch (type) {
        TransactionType.expense => 'preferred_expense_account',
        TransactionType.income => 'preferred_income_account',
        TransactionType.transfer => 'preferred_transfer_source',
      };
      account = int.tryParse(await state.database.getSetting(key) ?? '');
    }
    var destination = type == TransactionType.transfer
        ? int.tryParse(
            await state.database.getSetting('preferred_transfer_destination') ??
                '',
          )
        : null;
    if (destination == account) destination = null;
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuickAddPage(
          initialTypeName: type.name,
          initialAccountId: account,
          initialToAccountId: destination,
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.accountId, required this.onOpen});

  final int? accountId;
  final ValueChanged<TransactionType> onOpen;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: FinanceQuickAction(
          icon: Icons.arrow_upward_rounded,
          label: 'Spesa',
          color: context.financeColors.negative,
          onTap: () => onOpen(TransactionType.expense),
        ),
      ),
      Expanded(
        child: FinanceQuickAction(
          icon: Icons.arrow_downward_rounded,
          label: 'Entrata',
          color: context.financeColors.positive,
          onTap: () => onOpen(TransactionType.income),
        ),
      ),
      Expanded(
        child: FinanceQuickAction(
          icon: Icons.swap_horiz_rounded,
          label: 'Trasferisci',
          onTap: () => onOpen(TransactionType.transfer),
        ),
      ),
    ],
  );
}

class _SelectedAccountSummary extends StatelessWidget {
  const _SelectedAccountSummary({
    required this.account,
    required this.balance,
    required this.income,
    required this.expense,
  });

  final Account account;
  final double balance;
  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PATRIMONIO', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Text(
          state.hideBalance || account.hideBalance
              ? '••••••'
              : moneyFor(state, balance),
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Metric(
                label: 'Entrate',
                value: state.hideBalance ? '••••' : moneyFor(state, income),
                color: context.financeColors.positive,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Metric(
                label: 'Spese',
                value: state.hideBalance ? '••••' : moneyFor(state, expense),
                color: context.financeColors.negative,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Metric(
                label: 'Disponibile',
                value: state.hideBalance ? '••••' : moneyFor(state, balance),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            accountIcon(account.iconKey),
            color: Color(account.colorValue),
          ),
          title: Text(
            account.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(account.accountType.label),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SafeAccountDetailScreen(accountId: account.id),
            ),
          ),
        ),
      ],
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
      const Text('Parti dal primo conto oppure registra subito un movimento.'),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
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

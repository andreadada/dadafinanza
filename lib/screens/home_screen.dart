import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../core/money.dart';
import '../main.dart';
import '../models/models.dart';
import '../widgets/finance_quick_action.dart';
import '../widgets/home_dashboard_widget.dart';
import '../widgets/ui_helpers.dart';
import 'account_screens.dart' show showAccountEditor;
import 'advances_screen.dart';
import 'personal_settings_screen.dart';
import 'planning_screens.dart';
import 'quick_add_page.dart';
import 'root_screen.dart' as advanced;
import 'settings_screen.dart' show DashboardCustomizerScreen;

/// Canonical Home.
///
/// Quick actions and contextual insights stay fixed because they are actions,
/// while every financial summary below them is driven by dashboardWidgets.
/// This keeps "Personalizza Home" authoritative for visibility, order and size.
class DadaHomeScreen extends StatelessWidget {
  const DadaHomeScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final smartInsight = _smartInsight(state);
    final widgets = _visibleWidgets(state);

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
                  onMovement: () =>
                      _openQuick(context, TransactionType.expense),
                ),
                const SizedBox(height: 28),
              ],
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
                    title: const Text('Anticipi'),
                    subtitle: Text(
                      state.hideBalance
                          ? '•••• da ricevere · •••• da restituire'
                          : '${moneyFor(state, Money.fromCents(state.advanceReceivableCents))} da ricevere · '
                                '${moneyFor(state, Money.fromCents(state.advancePayableCents))} da restituire',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdvancesScreen()),
                    ),
                  ),
                if (smartInsight case final insight?)
                  _InsightRow(insight: insight),
              ],
              const SizedBox(height: 30),
              if (widgets.isEmpty)
                EmptyState(
                  icon: Icons.dashboard_customize_outlined,
                  title: 'Home vuota',
                  subtitle:
                      'Hai nascosto tutti i widget. Riattivane almeno uno dalla personalizzazione Home.',
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
                ...widgets.map(
                  (config) => Padding(
                    key: ValueKey('home-${config.type.name}'),
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
            ],
          ),
        ),
      ],
    );
  }

  List<DashboardWidgetConfig> _visibleWidgets(AppState state) {
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
    return [...items]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
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

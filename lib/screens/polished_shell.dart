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

  Future<void> _openQuick(
    BuildContext context,
    String type, {
    int? accountId,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuickAddPage(
          initialTypeName: type,
          initialAccountId: accountId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final now = DateTime.now();
    final month = DateFormat('MMMM yyyy', 'it_IT').format(now);
    final expense = state.monthTotal(TransactionType.expense);
    final income = state.monthTotal(TransactionType.income);
    final accounts = state.activeAccounts.take(4).toList();
    final recent = state.transactions.take(5).toList();
    final upcoming = state.recurring.where((item) => item.enabled).toList()
      ..sort((a, b) => a.nextDate.compareTo(b.nextDate));
    final activeBudget = state.budgets.where((item) => item.enabled).firstOrNull;

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
            PopupMenuButton<String>(
              tooltip: 'Altre opzioni',
              onSelected: (value) {
                if (value == 'widgets') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AndroidWidgetsScreen()),
                  );
                }
                if (value == 'dashboard') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const advanced.HomeScreen()),
                  );
                }
                if (value == 'settings') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'widgets',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.add_to_home_screen_rounded),
                    title: Text('Widget Android'),
                  ),
                ),
                PopupMenuItem(
                  value: 'dashboard',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.dashboard_customize_outlined),
                    title: Text('Dashboard avanzata'),
                  ),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.settings_outlined),
                    title: Text('Impostazioni'),
                  ),
                ),
              ],
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
          sliver: SliverList.list(
            children: [
              if (state.userAccounts.isEmpty) ...[
                _OnboardingBlock(
                  onCreateAccount: () => showAccountEditor(context),
                  onQuickAdd: () => _openQuick(context, 'expense'),
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
              const SizedBox(height: 5),
              Semantics(
                label: state.hideBalance
                    ? 'Patrimonio nascosto'
                    : 'Patrimonio ${moneyFor(state, state.totalBalance)}',
                child: Text(
                  state.hideBalance ? '••••••' : moneyFor(state, state.totalBalance),
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              const SizedBox(height: 18),
              _CashFlowStrip(
                income: income,
                expense: expense,
                safe: state.safeToSpend,
                hidden: state.hideBalance,
              ),
              const SizedBox(height: 26),
              _QuickActions(
                onExpense: () => _openQuick(context, 'expense'),
                onIncome: () => _openQuick(context, 'income'),
                onTransfer: () => _openQuick(context, 'transfer'),
              ),
              if (state.unassignedCount > 0) ...[
                const SizedBox(height: 24),
                _AttentionRow(
                  icon: Icons.rule_folder_outlined,
                  title: '${state.unassignedCount} movimenti da assegnare',
                  subtitle: 'Completa i dati per mantenere i saldi coerenti.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                  ),
                ),
              ],
              const SizedBox(height: 34),
              SectionTitle(
                'Conti',
                trailing: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PolishedAccountsScreen()),
                  ),
                  child: const Text('Tutti'),
                ),
              ),
              if (accounts.isEmpty)
                EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Nessun conto ancora',
                  subtitle: 'Aggiungi il conto che usi davvero; puoi sempre registrare prima un movimento come Non assegnato.',
                  action: FilledButton.icon(
                    onPressed: () => showAccountEditor(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Crea conto'),
                  ),
                )
              else
                ...accounts.map(
                  (account) => _HomeAccountRow(account: account),
                ),
              if (activeBudget != null) ...[
                const SizedBox(height: 32),
                _BudgetAtGlance(budget: activeBudget),
              ],
              const SizedBox(height: 32),
              SectionTitle(
                'Ultimi movimenti',
                trailing: recent.isEmpty ? null : Text('${state.transactions.length}'),
              ),
              if (recent.isEmpty)
                EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Inizia dal primo movimento',
                  subtitle: 'Registra una spesa o un’entrata. DadaFinanza costruirà analisi e previsioni dai tuoi dati reali.',
                  action: FilledButton.icon(
                    onPressed: () => _openQuick(context, 'expense'),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Registra movimento'),
                  ),
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
                  child: const Text('Pianifica'),
                ),
              ),
              if (upcoming.isEmpty)
                EmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'Nessuna scadenza prevista',
                  subtitle: 'Aggiungi bollette, abbonamenti o entrate ricorrenti per prevedere il saldo futuro.',
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
                        minVerticalPadding: 10,
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
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
              const SizedBox(height: 28),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.dashboard_customize_outlined),
                title: const Text('Dashboard avanzata'),
                subtitle: const Text('Grafici, widget aggiuntivi e personalizzazione completa.'),
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

class _CashFlowStrip extends StatelessWidget {
  const _CashFlowStrip({
    required this.income,
    required this.expense,
    required this.safe,
    required this.hidden,
  });

  final double income;
  final double expense;
  final double safe;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _MiniMetric(
            label: 'Entrate',
            value: hidden ? '••••' : moneyFor(state, income),
            color: context.financeColors.positive,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _MiniMetric(
            label: 'Spese',
            value: hidden ? '••••' : moneyFor(state, expense),
            color: context.financeColors.negative,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _MiniMetric(
            label: 'Disponibile',
            value: hidden ? '••••' : moneyFor(state, safe),
          ),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onExpense,
    required this.onIncome,
    required this.onTransfer,
  });
  final VoidCallback onExpense;
  final VoidCallback onIncome;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.arrow_upward_rounded,
              label: 'Spesa',
              onTap: onExpense,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              icon: Icons.arrow_downward_rounded,
              label: 'Entrata',
              onTap: onIncome,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              icon: Icons.swap_horiz_rounded,
              label: 'Trasferisci',
              onTap: onTransfer,
            ),
          ),
        ],
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});
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

class _OnboardingBlock extends StatelessWidget {
  const _OnboardingBlock({required this.onCreateAccount, required this.onQuickAdd});
  final VoidCallback onCreateAccount;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Configura DadaFinanza', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          const Text('Parti dal tuo primo conto oppure registra subito una spesa e assegnala in seguito.'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onCreateAccount,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crea primo conto'),
              ),
              OutlinedButton.icon(
                onPressed: onQuickAdd,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Registra movimento'),
              ),
            ],
          ),
        ],
      );
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        minVerticalPadding: 10,
        leading: Icon(icon, color: context.financeColors.warning),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}

class _HomeAccountRow extends StatelessWidget {
  const _HomeAccountRow({required this.account});
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
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Tooltip(
                message: 'Conto bloccato',
                child: Icon(Icons.lock_outline_rounded, size: 16),
              ),
            ),
          if (!account.includeInTotal)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Tooltip(
                message: 'Escluso dal patrimonio',
                child: Icon(Icons.visibility_off_outlined, size: 16),
              ),
            ),
        ],
      ),
      subtitle: Text(account.accountType.label),
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

class _BudgetAtGlance extends StatelessWidget {
  const _BudgetAtGlance({required this.budget});
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

class PolishedAccountsScreen extends StatelessWidget {
  const PolishedAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final active = state.activeAccounts;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conti'),
        actions: [
          IconButton(
            tooltip: 'Nuovo conto',
            onPressed: () => showAccountEditor(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Text('PATRIMONIO', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            state.hideBalance ? '••••••' : moneyFor(state, state.totalBalance),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Bloccato impedisce nuovi movimenti. Archiviato nasconde il conto dai flussi normali. Escluso dal patrimonio mantiene comunque lo storico.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 26),
          if (active.isEmpty)
            EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Nessun conto attivo',
              subtitle: 'Crea il conto che usi o continua con movimenti Non assegnati.',
              action: FilledButton.icon(
                onPressed: () => showAccountEditor(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crea conto'),
              ),
            )
          else
            ...active.map((account) => _AccountManagementRow(account: account)),
          if (state.archivedAccounts.isNotEmpty) ...[
            const SizedBox(height: 30),
            SectionTitle('Archiviati', trailing: Text('${state.archivedAccounts.length}')),
            ...state.archivedAccounts.map(
              (account) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(accountIcon(account.iconKey)),
                title: Text(account.name),
                subtitle: const Text('Fuori dai selettori normali'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AccountDetailPage(accountId: account.id)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountManagementRow extends StatelessWidget {
  const _AccountManagementRow({required this.account});
  final Account account;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: 12,
          leading: CircleAvatar(
            backgroundColor: Color(account.colorValue).withValues(alpha: .12),
            child: Icon(accountIcon(account.iconKey), color: Color(account.colorValue)),
          ),
          title: Text(account.name, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(account.accountType.label),
              if (account.isLocked) const _StatusText(icon: Icons.lock_outline_rounded, label: 'Bloccato'),
              if (!account.includeInTotal) const _StatusText(icon: Icons.remove_red_eye_outlined, label: 'Fuori patrimonio'),
              if (!account.includeInAnalytics) const _StatusText(icon: Icons.bar_chart_outlined, label: 'Fuori analisi'),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.hideBalance || account.hideBalance
                    ? '••••'
                    : moneyFor(state, account.balance),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              PopupMenuButton<String>(
                tooltip: 'Azioni rapide conto',
                onSelected: (value) async {
                  if (value == 'edit') await showAccountEditor(context, existing: account);
                  if (value == 'lock') {
                    await state.updateAccount(account.copyWith(isLocked: !account.isLocked));
                  }
                  if (value == 'archive') {
                    await state.updateAccount(account.copyWith(isArchived: true));
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Modifica')),
                  PopupMenuItem(
                    value: 'lock',
                    child: Text(account.isLocked ? 'Sblocca' : 'Blocca'),
                  ),
                  const PopupMenuItem(value: 'archive', child: Text('Archivia')),
                ],
              ),
            ],
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AccountDetailPage(accountId: account.id)),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13),
            const SizedBox(width: 2),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      );
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
            'Guarda avanti senza trasformare la pianificazione in un secondo gestionale.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          _PlanningEntry(
            icon: Icons.pie_chart_outline_rounded,
            title: 'Budget del periodo',
            value: budgets.isEmpty
                ? 'Nessun limite'
                : '${budgets.length} ${budgets.length == 1 ? 'budget attivo' : 'budget attivi'}',
            detail: budgets.isEmpty
                ? 'Imposta un limite per sapere quanto puoi ancora spendere.'
                : 'Controlla residuo, ritmo di spesa e budget più vicino al limite.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BudgetsScreen()),
            ),
          ),
          const Divider(height: 28),
          _PlanningEntry(
            icon: Icons.event_repeat_rounded,
            title: 'Prossime scadenze',
            value: recurring.isEmpty
                ? 'Nessuna scadenza'
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
          _PlanningEntry(
            icon: Icons.flag_outlined,
            title: 'Obiettivi',
            value: goals.isEmpty
                ? 'Nessun obiettivo'
                : '${goals.length} ${goals.length == 1 ? 'obiettivo attivo' : 'obiettivi attivi'}',
            detail: goals.isEmpty
                ? 'Dai un nome ai risparmi che vuoi costruire.'
                : '${goals.first.name}: ${moneyFor(state, goals.first.currentAmount)} / ${moneyFor(state, goals.first.targetAmount)}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GoalsScreen()),
            ),
          ),
          const SizedBox(height: 34),
          SectionTitle('Viste'),
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
            subtitle: const Text('Tutte le funzioni e viste avanzate in una sola schermata.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const advanced.PlanningScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanningEntry extends StatelessWidget {
  const _PlanningEntry({
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
        leading: Icon(icon, size: 27),
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

enum _AnalyticsPeriod { week, month, year, custom }

class PolishedAnalyticsScreen extends StatefulWidget {
  const PolishedAnalyticsScreen({super.key});

  @override
  State<PolishedAnalyticsScreen> createState() => _PolishedAnalyticsScreenState();
}

class _PolishedAnalyticsScreenState extends State<PolishedAnalyticsScreen> {
  _AnalyticsPeriod period = _AnalyticsPeriod.month;
  DateTimeRange? customRange;

  (DateTime, DateTime) _bounds(AppState state) {
    final now = DateTime.now();
    switch (period) {
      case _AnalyticsPeriod.week:
        final startWeekday = state.weekStart.clamp(1, 7);
        final offset = (now.weekday - startWeekday) % 7;
        final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: offset));
        return (start, start.add(const Duration(days: 7)));
      case _AnalyticsPeriod.month:
        final startDay = state.financialMonthStart.clamp(1, 28);
        var start = DateTime(now.year, now.month, startDay);
        if (now.isBefore(start)) start = DateTime(now.year, now.month - 1, startDay);
        return (start, DateTime(start.year, start.month + 1, startDay));
      case _AnalyticsPeriod.year:
        return (DateTime(now.year), DateTime(now.year + 1));
      case _AnalyticsPeriod.custom:
        final range = customRange;
        if (range == null) return (DateTime(now.year, now.month), DateTime(now.year, now.month + 1));
        return (
          DateTime(range.start.year, range.start.month, range.start.day),
          DateTime(range.end.year, range.end.month, range.end.day + 1),
        );
    }
  }

  Map<Category, double> _categoryTotals(AppState state, DateTime from, DateTime to) {
    final totals = <Category, double>{};
    for (final t in state
        .analyticTransactions(from: from, to: to)
        .where((item) => item.type == TransactionType.expense)) {
      final splits = state.splitsFor(t.id);
      if (splits.isNotEmpty) {
        for (final split in splits) {
          final category = state.categoryById(split.categoryId);
          if (category != null) {
            totals[category] = (totals[category] ?? 0) + split.amount;
          }
        }
      } else {
        final category = state.categoryById(t.categoryId);
        if (category != null) {
          totals[category] = (totals[category] ?? 0) + state.effectiveExpense(t);
        }
      }
    }
    return totals;
  }

  Future<void> _chooseCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 3650)),
      initialDateRange: customRange ?? DateTimeRange(start: DateTime(now.year, now.month), end: now),
    );
    if (picked != null && mounted) {
      setState(() {
        customRange = picked;
        period = _AnalyticsPeriod.custom;
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
    final previousExpense = state.periodTotal(TransactionType.expense, previousFrom, from);
    final delta = previousExpense == 0 ? null : (expense - previousExpense) / previousExpense * 100;
    final categoryTotals = _categoryTotals(state, from, to).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final count = state.analyticTransactions(from: from, to: to).length;
    final days = math.max(1, duration.inDays);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analisi'),
        actions: [
          IconButton(
            tooltip: 'Analisi avanzata',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const advanced.AnalyticsScreen()),
            ),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<_AnalyticsPeriod>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _AnalyticsPeriod.week, label: Text('Settimana')),
                ButtonSegment(value: _AnalyticsPeriod.month, label: Text('Mese')),
                ButtonSegment(value: _AnalyticsPeriod.year, label: Text('Anno')),
                ButtonSegment(value: _AnalyticsPeriod.custom, label: Text('Custom')),
              ],
              selected: {period},
              onSelectionChanged: (value) {
                if (value.first == _AnalyticsPeriod.custom) {
                  _chooseCustom();
                } else {
                  setState(() => period = value.first);
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '${DateFormat('d MMM', 'it_IT').format(from)} – ${DateFormat('d MMM', 'it_IT').format(to.subtract(const Duration(days: 1)))}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _AnalyticsMetric(
                  label: 'Entrate',
                  value: moneyFor(state, income),
                  color: context.financeColors.positive,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _AnalyticsMetric(
                  label: 'Spese',
                  value: moneyFor(state, expense),
                  color: context.financeColors.negative,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _InsightSentence(
            icon: delta == null
                ? Icons.horizontal_rule_rounded
                : delta <= 0
                    ? Icons.trending_down_rounded
                    : Icons.trending_up_rounded,
            text: delta == null
                ? 'Non ci sono ancora abbastanza dati per confrontare il periodo precedente.'
                : 'Hai speso ${delta.abs().toStringAsFixed(0)}% ${delta <= 0 ? 'in meno' : 'in più'} rispetto al periodo precedente.',
            color: delta == null
                ? null
                : delta <= 0
                    ? context.financeColors.positive
                    : context.financeColors.negative,
          ),
          const SizedBox(height: 10),
          _InsightSentence(
            icon: Icons.calculate_outlined,
            text: '$count movimenti · media spese ${moneyFor(state, expense / days)} al giorno.',
          ),
          const SizedBox(height: 32),
          const SectionTitle('Dove stai spendendo'),
          if (categoryTotals.isEmpty)
            const EmptyState(
              icon: Icons.donut_small_outlined,
              title: 'Nessun dato nel periodo',
              subtitle: 'Le categorie compariranno qui quando registri movimenti.',
            )
          else
            ...categoryTotals.take(6).map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    minVerticalPadding: 10,
                    leading: CircleAvatar(
                      backgroundColor: Color(entry.key.colorValue).withValues(alpha: .12),
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
          const SizedBox(height: 28),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.query_stats_rounded),
            title: const Text('Analisi avanzata'),
            subtitle: const Text('Grafici, patrimonio, trend e viste aggiuntive.'),
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

class _AnalyticsMetric extends StatelessWidget {
  const _AnalyticsMetric({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

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
                  .headlineSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      );
}

class _InsightSentence extends StatelessWidget {
  const _InsightSentence({required this.icon, required this.text, this.color});
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
        .where((item) {
          if (item.categoryId == categoryId) return true;
          return state.splitsFor(item.id).any((split) => split.categoryId == categoryId);
        })
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(category?.name ?? 'Categoria')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 60),
        children: [
          Text(
            '${items.length} ${items.length == 1 ? 'movimento' : 'movimenti'} nel periodo',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          if (items.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Nessun movimento',
              subtitle: 'Non risultano movimenti per questa categoria nel periodo selezionato.',
            )
          else
            ...items.map((item) => TransactionListTile(item: item)),
        ],
      ),
    );
  }
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../main.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_helpers.dart';
import 'account_screens.dart';
import 'planning_screens.dart';
import 'quick_add_page.dart';
import 'settings_screen.dart';
import 'transaction_screens.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});
  @override State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    const pages = [HomeScreen(), TransactionsScreen(), AnalyticsScreen(), PlanningScreen()];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      floatingActionButton: FloatingActionButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickAddPage())), tooltip: 'Nuovo movimento', child: const Icon(Icons.add_rounded)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Movimenti'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: 'Analisi'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note_rounded), label: 'Pianifica'),
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
    final widgets = state.dashboardWidgets.where((w) => w.enabled).toList()..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final month = DateFormat('MMMM yyyy', 'it_IT').format(DateTime.now());
    return CustomScrollView(slivers: [
      SliverAppBar(
        floating: true,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('DadaFinanza'), Text(month, style: Theme.of(context).textTheme.bodySmall)]),
        actions: [
          IconButton(tooltip: state.hideBalance ? 'Mostra saldi' : 'Nascondi saldi', onPressed: () => state.setHideBalance(!state.hideBalance), icon: Icon(state.hideBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined)),
          IconButton(tooltip: 'Personalizza dashboard', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardCustomizerScreen())), icon: const Icon(Icons.dashboard_customize_outlined)),
          IconButton(tooltip: 'Impostazioni', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())), icon: const Icon(Icons.settings_outlined)),
        ],
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        sliver: SliverList.list(children: [
          if (state.userAccounts.isEmpty) ...[const _SetupGuide(), const SizedBox(height: 24)],
          ...widgets.map((config) => Padding(padding: const EdgeInsets.only(bottom: 22), child: _DashboardWidget(config: config))),
          if (widgets.isEmpty) EmptyState(icon: Icons.dashboard_customize_outlined, title: 'Dashboard vuota', subtitle: 'Scegli i widget che vuoi vedere.', action: FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardCustomizerScreen())), child: const Text('Personalizza'))),
        ]),
      ),
    ]);
  }
}

class _SetupGuide extends StatelessWidget {
  const _SetupGuide();
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Configura DadaFinanza', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 6), Text('Puoi partire creando un conto oppure registrare subito un movimento come Non assegnato.', style: Theme.of(context).textTheme.bodyMedium),
    const SizedBox(height: 14), Wrap(spacing: 10, runSpacing: 10, children: [FilledButton.icon(onPressed: () => showAccountEditor(context), icon: const Icon(Icons.add_rounded), label: const Text('Crea primo conto')), OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickAddPage())), icon: const Icon(Icons.receipt_long_outlined), label: const Text('Registra movimento'))]),
  ]);
}

class _DashboardWidget extends StatelessWidget {
  const _DashboardWidget({required this.config});
  final DashboardWidgetConfig config;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final type = config.type;
    final title = type.label;
    final now = DateTime.now();
    final previous = DateTime(now.year, now.month - 1);
    final currentExpense = state.monthTotal(TransactionType.expense);
    final previousExpense = state.monthTotal(TransactionType.expense, month: previous);

    Widget metric(String value, {String? subtitle, IconData? icon, VoidCallback? onTap, Color? valueColor}) => _FlatDashboardBlock(
      title: title, value: value, subtitle: subtitle, icon: icon, onTap: onTap, valueColor: valueColor, large: config.size == DashboardWidgetSize.large,
    );

    switch (type) {
      case DashboardWidgetType.totalBalance:
        return metric(state.hideBalance ? '••••••' : moneyFor(state, state.totalBalance), subtitle: 'Patrimonio incluso nel totale', icon: Icons.account_balance_wallet_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen())));
      case DashboardWidgetType.monthlyCashFlow:
        return metric(moneyFor(state, state.monthlyCashFlow, signed: true), subtitle: '${moneyFor(state, state.monthTotal(TransactionType.income))} entrate · ${moneyFor(state, currentExpense)} spese', icon: Icons.compare_arrows_rounded, valueColor: state.monthlyCashFlow >= 0 ? context.financeColors.positive : context.financeColors.negative);
      case DashboardWidgetType.monthlyIncome:
        return metric(moneyFor(state, state.monthTotal(TransactionType.income)), icon: Icons.arrow_downward_rounded, valueColor: context.financeColors.positive);
      case DashboardWidgetType.monthlyExpense:
        return metric(moneyFor(state, currentExpense), icon: Icons.arrow_upward_rounded, valueColor: context.financeColors.negative);
      case DashboardWidgetType.monthlyBudget:
        final budget = state.budgets.where((b) => b.enabled).firstOrNull;
        if (budget == null) return metric('Nessun budget', subtitle: 'Crea un limite in Pianifica', icon: Icons.pie_chart_outline_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetsScreen())));
        final spent = state.budgetSpent(budget); final progress = state.budgetProgressFor(budget);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SectionTitle(title, trailing: Text('${(progress * 100).round()}%')), Text('${moneyFor(state, spent)} / ${moneyFor(state, budget.limit)}', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 10), LinearProgressIndicator(value: progress.clamp(0.0, 1.0).toDouble(), minHeight: 7, borderRadius: BorderRadius.circular(99), color: progress >= 1 ? context.financeColors.negative : progress >= .8 ? context.financeColors.warning : null)]);
      case DashboardWidgetType.safeToSpend:
        return metric(moneyFor(state, state.safeToSpend), subtitle: 'Stima fino a fine mese: saldo meno uscite previste e una riserva per gli obiettivi', icon: Icons.safety_check_outlined, onTap: () => _showSafeToSpendInfo(context));
      case DashboardWidgetType.netWorth:
        return metric(state.hideBalance ? '••••••' : moneyFor(state, state.totalBalance), subtitle: 'Andamento storico disponibile', icon: Icons.show_chart_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NetWorthScreen())));
      case DashboardWidgetType.accounts:
        final visible = state.activeAccounts.take(config.size == DashboardWidgetSize.large ? 5 : 3).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SectionTitle(title, trailing: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen())), child: const Text('Tutti'))), if (visible.isEmpty) const Text('Nessun conto') else ...visible.map((a) => FlatMetric(label: a.name, value: state.hideBalance || a.hideBalance ? '••••' : moneyFor(state, a.balance), icon: accountIcon(a.iconKey), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountDetailPage(accountId: a.id))))]);
      case DashboardWidgetType.recentTransactions:
        final recent = state.transactions.take(config.size == DashboardWidgetSize.large ? 6 : 3).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SectionTitle(title), if (recent.isEmpty) const Text('Ancora nessun movimento') else ...recent.map((t) => TransactionListTile(item: t))]);
      case DashboardWidgetType.todayExpense:
        return metric(moneyFor(state, state.todayExpense), icon: Icons.today_outlined, valueColor: context.financeColors.negative);
      case DashboardWidgetType.weekExpense:
        return metric(moneyFor(state, state.weekExpense), icon: Icons.date_range_outlined, valueColor: context.financeColors.negative);
      case DashboardWidgetType.previousMonthComparison:
        final delta = previousExpense == 0 ? 0.0 : ((currentExpense - previousExpense) / previousExpense * 100);
        return metric(previousExpense == 0 ? 'Nessun confronto' : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}%', subtitle: '${moneyFor(state, currentExpense)} questo mese · ${moneyFor(state, previousExpense)} precedente', icon: Icons.compare_rounded, valueColor: delta <= 0 ? context.financeColors.positive : context.financeColors.negative);
      case DashboardWidgetType.topCategories:
        final top = state.topExpenseCategories(limit: config.size == DashboardWidgetSize.large ? 5 : 3);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SectionTitle(title), if (top.isEmpty) const Text('Nessun dato') else ...top.map((e) => FlatMetric(label: e.key.name, value: moneyFor(state, e.value), icon: categoryIcon(e.key.iconKey), color: Color(e.key.colorValue)))]);
      case DashboardWidgetType.closestBudget:
        final active = state.budgets.where((b) => b.enabled).toList()..sort((a, b) => state.budgetProgressFor(b).compareTo(state.budgetProgressFor(a)));
        final budget = active.firstOrNull;
        return metric(budget == null ? 'Nessun budget' : '${(state.budgetProgressFor(budget) * 100).round()}%', subtitle: budget?.name, icon: Icons.warning_amber_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetsScreen())));
      case DashboardWidgetType.upcomingRecurring:
        final upcoming = state.recurring.where((r) => r.enabled).take(config.size == DashboardWidgetSize.large ? 5 : 3).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SectionTitle(title, trailing: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringScreen())), child: const Text('Apri'))), if (upcoming.isEmpty) const Text('Nessun pagamento previsto') else ...upcoming.map((r) => FlatMetric(label: '${r.name} · ${DateFormat('dd MMM', 'it_IT').format(r.nextDate)}', value: '${r.type == TransactionType.expense ? '-' : '+'}${moneyFor(state, r.amount)}', icon: Icons.repeat_rounded, color: transactionColor(context, r.type)))]);
      case DashboardWidgetType.financeCalendar:
        final next = state.recurring.where((r) => r.enabled).firstOrNull;
        return metric(next == null ? 'Nessuna scadenza' : DateFormat('dd MMM', 'it_IT').format(next.nextDate), subtitle: next?.name, icon: Icons.calendar_month_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceCalendarScreen())));
      case DashboardWidgetType.goals:
        final active = state.goals.where((g) => !g.archived && !g.completed).firstOrNull;
        return metric(active == null ? 'Nessun obiettivo' : '${((active.currentAmount / active.targetAmount) * 100).clamp(0, 100).round()}%', subtitle: active == null ? 'Crea un obiettivo in Pianifica' : '${active.name} · ${moneyFor(state, active.currentAmount)} / ${moneyFor(state, active.targetAmount)}', icon: Icons.flag_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen())));
      case DashboardWidgetType.netWorthTrend:
        final snaps = state.netWorthSnapshots;
        final delta = snaps.length < 2 ? 0.0 : (snaps.last['amount'] as num).toDouble() - (snaps.first['amount'] as num).toDouble();
        return metric(snaps.length < 2 ? 'In raccolta' : moneyFor(state, delta, signed: true), subtitle: '${snaps.length} snapshot locali', icon: Icons.timeline_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NetWorthScreen())));
      case DashboardWidgetType.dailyAverage:
        return metric(moneyFor(state, state.dailyAverageExpense), subtitle: 'Media giornaliera del mese', icon: Icons.av_timer_rounded);
      case DashboardWidgetType.noSpendDays:
        return metric('${state.noSpendDaysThisMonth}', subtitle: 'Giorni senza spese questo mese', icon: Icons.event_available_outlined);
      case DashboardWidgetType.endMonthForecast:
        return metric(state.hideBalance ? '••••••' : moneyFor(state, state.endOfMonthForecast), subtitle: 'Previsione basata sui ricorrenti attivi', icon: Icons.auto_graph_rounded);
      case DashboardWidgetType.unassignedTransactions:
        return metric('${state.unassignedCount}', subtitle: state.unassignedCount == 1 ? 'movimento da assegnare' : 'movimenti da assegnare', icon: Icons.help_outline_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionsScreen(initialUnassignedOnly: true))));
    }
  }

  void _showSafeToSpendInfo(BuildContext context) => showModalBottomSheet<void>(context: context, useSafeArea: true, builder: (context) => const Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Disponibile da spendere', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), SizedBox(height: 10), Text('È una stima: parte dal patrimonio spendibile, sottrae le uscite ricorrenti previste fino a fine mese e conserva una riserva prudenziale per gli obiettivi. Non è un saldo bancario garantito.'), SizedBox(height: 14)])));
}

class _FlatDashboardBlock extends StatelessWidget {
  const _FlatDashboardBlock({required this.title, required this.value, this.subtitle, this.icon, this.onTap, this.valueColor, this.large = false});
  final String title; final String value; final String? subtitle; final IconData? icon; final VoidCallback? onTap; final Color? valueColor; final bool large;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (icon != null) ...[Padding(padding: const EdgeInsets.only(top: 4), child: Icon(icon, size: 22)), const SizedBox(width: 14)],
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.bodyMedium), const SizedBox(height: 4), Text(value, style: (large ? Theme.of(context).textTheme.headlineLarge : Theme.of(context).textTheme.headlineMedium)?.copyWith(color: valueColor)), if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)]])),
        if (onTap != null) const Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.chevron_right_rounded)),
      ]),
    ),
  );
}

enum TransactionSort { newest, oldest, amountAsc, amountDesc }

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({this.initialUnassignedOnly = false, super.key});
  final bool initialUnassignedOnly;
  @override State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final search = TextEditingController();
  String query = '';
  TransactionType? type;
  TransactionSort sort = TransactionSort.newest;
  double? minAmount;
  double? maxAmount;
  DateTime? from;
  DateTime? to;
  bool? hasReceipt;
  late bool unassignedOnly;
  final selected = <int>{};

  @override void initState() { super.initState(); unassignedOnly = widget.initialUnassignedOnly; }
  @override void dispose() { search.dispose(); super.dispose(); }

  List<FinanceTransaction> _filtered(AppState state) {
    var result = state.transactions.where((t) {
      if (type != null && t.type != type) return false;
      if (minAmount != null && t.amount < minAmount!) return false;
      if (maxAmount != null && t.amount > maxAmount!) return false;
      if (from != null && t.date.isBefore(from!)) return false;
      if (to != null && t.date.isAfter(to!)) return false;
      if (hasReceipt != null && (t.receiptPath != null) != hasReceipt) return false;
      if (unassignedOnly && t.accountId != state.unassignedAccount?.id) return false;
      if (query.isNotEmpty) {
        final category = state.categoryById(t.categoryId)?.name ?? '';
        final account = state.accountById(t.accountId)?.name ?? '';
        final haystack = '${t.note ?? ''} $category $account ${t.tags.join(' ')} ${t.amount}'.toLowerCase();
        if (!haystack.contains(query.toLowerCase())) return false;
      }
      return true;
    }).toList();
    switch (sort) {
      case TransactionSort.newest:
        result.sort((a, b) => b.date.compareTo(a.date));
        break;
      case TransactionSort.oldest:
        result.sort((a, b) => a.date.compareTo(b.date));
        break;
      case TransactionSort.amountAsc:
        result.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case TransactionSort.amountDesc:
        result.sort((a, b) => b.amount.compareTo(a.amount));
        break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context); final items = _filtered(state); final selecting = selected.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: selecting ? Text('${selected.length} selezionati') : const Text('Movimenti'),
        leading: selecting ? IconButton(tooltip: 'Annulla selezione', onPressed: () => setState(selected.clear), icon: const Icon(Icons.close_rounded)) : null,
        actions: selecting ? [PopupMenuButton<String>(onSelected: (value) => _bulkAction(context, value), itemBuilder: (context) => [const PopupMenuItem(value: 'category', child: Text('Cambia categoria')), const PopupMenuItem(value: 'account', child: Text('Cambia conto')), const PopupMenuItem(value: 'tag', child: Text('Aggiungi tag')), const PopupMenuItem(value: 'analytics', child: Text('Escludi dalle statistiche')), PopupMenuItem(value: 'delete', child: Text('Elimina', style: TextStyle(color: Theme.of(context).colorScheme.error)))])] : [IconButton(tooltip: 'Filtri', onPressed: () => _showFilters(context), icon: const Icon(Icons.tune_rounded))],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: TextField(controller: search, decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: 'Cerca nota, categoria, conto, tag…', suffixIcon: query.isEmpty ? null : IconButton(onPressed: () { search.clear(); setState(() => query = ''); }, icon: const Icon(Icons.close_rounded))), onChanged: (value) => setState(() => query = value))),
        if (type != null || unassignedOnly || minAmount != null || maxAmount != null || from != null || hasReceipt != null)
          SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [if (type != null) Padding(padding: const EdgeInsets.only(right: 6), child: InputChip(label: Text(type!.label), onDeleted: () => setState(() => type = null))), if (unassignedOnly) Padding(padding: const EdgeInsets.only(right: 6), child: InputChip(label: const Text('Non assegnati'), onDeleted: () => setState(() => unassignedOnly = false))), if (minAmount != null || maxAmount != null) Padding(padding: const EdgeInsets.only(right: 6), child: InputChip(label: Text('${minAmount ?? 0}–${maxAmount ?? '∞'} €'), onDeleted: () => setState(() { minAmount = null; maxAmount = null; }))), if (from != null) Padding(padding: const EdgeInsets.only(right: 6), child: InputChip(label: const Text('Intervallo date'), onDeleted: () => setState(() { from = null; to = null; }))), if (hasReceipt != null) InputChip(label: Text(hasReceipt! ? 'Con ricevuta' : 'Senza ricevuta'), onDeleted: () => setState(() => hasReceipt = null))])),
        Expanded(child: items.isEmpty ? const EmptyState(icon: Icons.search_off_rounded, title: 'Nessun movimento', subtitle: 'Prova a modificare ricerca o filtri.') : ListView.builder(padding: const EdgeInsets.fromLTRB(20, 0, 20, 120), itemCount: items.length, itemBuilder: (context, index) {
          final item = items[index];
          return Column(children: [TransactionListTile(item: item, selected: selected.contains(item.id), onLongPress: () => setState(() => selected.add(item.id))), if (index != items.length - 1) const Divider(height: 1)]);
        })),
      ]),
    );
  }

  Future<void> _showFilters(BuildContext context) async {
    final min = TextEditingController(text: minAmount?.toString() ?? ''); final max = TextEditingController(text: maxAmount?.toString() ?? '');
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, builder: (context) => StatefulBuilder(builder: (context, setSheetState) => Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 20), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Filtri e ordinamento', style: Theme.of(context).textTheme.titleLarge),
        DropdownButtonFormField<TransactionType?>(initialValue: type, decoration: const InputDecoration(labelText: 'Tipologia'), items: const [DropdownMenuItem<TransactionType?>(value: null, child: Text('Tutte')), DropdownMenuItem(value: TransactionType.expense, child: Text('Spese')), DropdownMenuItem(value: TransactionType.income, child: Text('Entrate')), DropdownMenuItem(value: TransactionType.transfer, child: Text('Trasferimenti'))], onChanged: (value) => setSheetState(() => type = value)),
        DropdownButtonFormField<TransactionSort>(initialValue: sort, decoration: const InputDecoration(labelText: 'Ordina'), items: const [DropdownMenuItem(value: TransactionSort.newest, child: Text('Più recenti')), DropdownMenuItem(value: TransactionSort.oldest, child: Text('Più vecchi')), DropdownMenuItem(value: TransactionSort.amountAsc, child: Text('Importo crescente')), DropdownMenuItem(value: TransactionSort.amountDesc, child: Text('Importo decrescente'))], onChanged: (value) => setSheetState(() => sort = value ?? sort)),
        Row(children: [Expanded(child: TextField(controller: min, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Importo minimo'))), const SizedBox(width: 16), Expanded(child: TextField(controller: max, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Importo massimo')))]),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Solo Non assegnati'), value: unassignedOnly, onChanged: (v) => setSheetState(() => unassignedOnly = v)),
        DropdownButtonFormField<bool?>(initialValue: hasReceipt, decoration: const InputDecoration(labelText: 'Ricevuta'), items: const [DropdownMenuItem<bool?>(value: null, child: Text('Qualsiasi')), DropdownMenuItem<bool?>(value: true, child: Text('Con ricevuta')), DropdownMenuItem<bool?>(value: false, child: Text('Senza ricevuta'))], onChanged: (value) => setSheetState(() => hasReceipt = value)),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.date_range_outlined), title: const Text('Intervallo date'), subtitle: Text(from == null ? 'Qualsiasi data' : '${DateFormat('dd/MM/yyyy').format(from!)} – ${DateFormat('dd/MM/yyyy').format(to!)}'), onTap: () async { final range = await showDateRangePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 3650)), initialDateRange: from == null ? null : DateTimeRange(start: from!, end: to!)); if (range != null) setSheetState(() { from = range.start; to = range.end.add(const Duration(days: 1)); }); }),
        const SizedBox(height: 16), SizedBox(width: double.infinity, child: FilledButton(onPressed: () { minAmount = double.tryParse(min.text.replaceAll(',', '.')); maxAmount = double.tryParse(max.text.replaceAll(',', '.')); setState(() {}); Navigator.pop(context); }, child: const Text('Applica filtri'))),
      ])),
    )));
    min.dispose(); max.dispose();
  }

  Future<void> _bulkAction(BuildContext context, String action) async {
    final state = AppScope.of(context); final items = state.transactions.where((t) => selected.contains(t.id)).toList();
    if (action == 'delete') {
      if (!await confirmDestructiveAction(context, title: 'Eliminare ${items.length} movimenti?', message: 'I saldi verranno ricalcolati automaticamente.')) return;
      for (final item in items) { await state.deleteTransaction(item); }
    } else if (action == 'analytics') {
      for (final item in items) { await state.updateTransaction(item, item.copyWith(includeInAnalytics: false, updatedAt: DateTime.now())); }
    } else if (action == 'category') {
      final candidates = state.categoriesFor(TransactionType.expense);
      final id = await showModalBottomSheet<int>(context: context, builder: (context) => ListView(shrinkWrap: true, padding: const EdgeInsets.all(20), children: candidates.map((c) => ListTile(title: Text(c.name), leading: Icon(categoryIcon(c.iconKey)), onTap: () => Navigator.pop(context, c.id))).toList()));
      if (id != null) for (final item in items.where((t) => t.type != TransactionType.transfer)) { await state.updateTransaction(item, item.copyWith(categoryId: id, updatedAt: DateTime.now())); }
    } else if (action == 'account') {
      final id = await showModalBottomSheet<int>(context: context, builder: (context) => ListView(shrinkWrap: true, padding: const EdgeInsets.all(20), children: state.activeAccounts.where((a) => !a.isLocked).map((a) => ListTile(title: Text(a.name), leading: Icon(accountIcon(a.iconKey)), onTap: () => Navigator.pop(context, a.id))).toList()));
      if (id != null) for (final item in items.where((t) => t.type != TransactionType.transfer)) { await state.updateTransaction(item, item.copyWith(accountId: id, updatedAt: DateTime.now())); }
    } else if (action == 'tag') {
      final controller = TextEditingController();
      final tag = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: const Text('Aggiungi tag'), content: TextField(controller: controller, autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Aggiungi'))]));
      controller.dispose();
      if (tag?.isNotEmpty == true) for (final item in items) { await state.updateTransaction(item, item.copyWith(tags: {...item.tags, tag!}.toList(), updatedAt: DateTime.now())); }
    }
    if (mounted) setState(selected.clear);
  }
}

enum AnalyticsPeriod { week, month, year }

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  AnalyticsPeriod period = AnalyticsPeriod.month;

  DateTimeRange _range() {
    final now = DateTime.now();
    return switch (period) {
      AnalyticsPeriod.week => DateTimeRange(start: DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1)), end: DateTime(now.year, now.month, now.day).add(Duration(days: 8 - now.weekday))),
      AnalyticsPeriod.month => DateTimeRange(start: DateTime(now.year, now.month), end: DateTime(now.year, now.month + 1)),
      AnalyticsPeriod.year => DateTimeRange(start: DateTime(now.year), end: DateTime(now.year + 1)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context); final range = _range();
    final income = state.periodTotal(TransactionType.income, range.start, range.end); final expense = state.periodTotal(TransactionType.expense, range.start, range.end); final net = income - expense;
    final filtered = state.analyticTransactions(from: range.start, to: range.end).toList();
    final topAccounts = <Account, double>{};
    final tagTotals = <String, double>{};
    for (final t in filtered.where((t) => t.type == TransactionType.expense)) {
      final account = state.accountById(t.accountId); if (account != null && !account.isSystem) topAccounts[account] = (topAccounts[account] ?? 0) + t.amount;
      for (final tag in t.tags) { tagTotals[tag] = (tagTotals[tag] ?? 0) + t.amount; }
    }
    final accounts = topAccounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final tags = tagTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = state.topExpenseCategories();
    return Scaffold(
      appBar: AppBar(title: const Text('Analisi')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 120), children: [
        SegmentedButton<AnalyticsPeriod>(showSelectedIcon: false, segments: const [ButtonSegment(value: AnalyticsPeriod.week, label: Text('Settimana')), ButtonSegment(value: AnalyticsPeriod.month, label: Text('Mese')), ButtonSegment(value: AnalyticsPeriod.year, label: Text('Anno'))], selected: {period}, onSelectionChanged: (value) => setState(() => period = value.first)),
        const SizedBox(height: 28),
        Row(children: [Expanded(child: _AnalyticsMetric(label: 'Entrate', value: moneyFor(state, income), color: context.financeColors.positive)), const SizedBox(width: 20), Expanded(child: _AnalyticsMetric(label: 'Spese', value: moneyFor(state, expense), color: context.financeColors.negative))]),
        const SizedBox(height: 18), _AnalyticsMetric(label: 'Netto', value: moneyFor(state, net, signed: true), color: net >= 0 ? context.financeColors.positive : context.financeColors.negative),
        const SizedBox(height: 34), const SectionTitle('Ultimi 6 mesi'), SizedBox(height: 210, child: _SixMonthChart(state: state)),
        const SizedBox(height: 34), const SectionTitle('Categorie principali'), if (top.isEmpty) const Text('Nessun dato') else ...top.map((e) => FlatMetric(label: e.key.name, value: moneyFor(state, e.value), icon: categoryIcon(e.key.iconKey), color: Color(e.key.colorValue))),
        if (tags.isNotEmpty) ...[const SizedBox(height: 30), const SectionTitle('Top tag'), ...tags.take(5).map((e) => FlatMetric(label: '#${e.key}', value: moneyFor(state, e.value), icon: Icons.tag_rounded))],
        if (accounts.isNotEmpty) ...[const SizedBox(height: 30), const SectionTitle('Top conti per spesa'), ...accounts.take(5).map((e) => FlatMetric(label: e.key.name, value: moneyFor(state, e.value), icon: accountIcon(e.key.iconKey), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountDetailPage(accountId: e.key.id)))))],
        const SizedBox(height: 30), const SectionTitle('Indicatori'), FlatMetric(label: 'Media giornaliera', value: moneyFor(state, state.dailyAverageExpense), icon: Icons.av_timer_rounded), const Divider(height: 1), FlatMetric(label: 'Giorni senza spese', value: '${state.noSpendDaysThisMonth}', icon: Icons.event_available_outlined), const Divider(height: 1), FlatMetric(label: 'Numero movimenti', value: '${filtered.length}', icon: Icons.receipt_long_outlined),
      ]),
    );
  }
}

class _AnalyticsMetric extends StatelessWidget {
  const _AnalyticsMetric({required this.label, required this.value, required this.color});
  final String label; final String value; final Color color;
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.bodyMedium), const SizedBox(height: 4), Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color))]);
}

class _SixMonthChart extends StatelessWidget {
  const _SixMonthChart({required this.state});
  final AppState state;
  @override Widget build(BuildContext context) {
    final months = List.generate(6, (i) { final now = DateTime.now(); return DateTime(now.year, now.month - (5 - i)); });
    return BarChart(BarChartData(
      gridData: const FlGridData(show: false), borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) { final i = value.toInt(); if (i < 0 || i >= months.length) return const SizedBox.shrink(); return Padding(padding: const EdgeInsets.only(top: 8), child: Text(DateFormat('MMM', 'it_IT').format(months[i]), style: Theme.of(context).textTheme.bodySmall)); }))),
      barGroups: List.generate(months.length, (i) => BarChartGroupData(x: i, barsSpace: 3, barRods: [BarChartRodData(toY: state.monthTotal(TransactionType.income, month: months[i]), width: 9, borderRadius: BorderRadius.circular(5), color: context.financeColors.positive), BarChartRodData(toY: state.monthTotal(TransactionType.expense, month: months[i]), width: 9, borderRadius: BorderRadius.circular(5), color: context.financeColors.negative)])),
    ));
  }
}

class NetWorthScreen extends StatelessWidget {
  const NetWorthScreen({super.key});
  @override Widget build(BuildContext context) {
    final state = AppScope.of(context); final snapshots = state.netWorthSnapshots;
    final spots = <FlSpot>[];
    for (var i = 0; i < snapshots.length; i++) { spots.add(FlSpot(i.toDouble(), (snapshots[i]['amount'] as num).toDouble())); }
    return Scaffold(appBar: AppBar(title: const Text('Patrimonio netto')), body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 80), children: [
      Text(state.hideBalance ? '••••••' : moneyFor(state, state.totalBalance), style: Theme.of(context).textTheme.displaySmall), const SizedBox(height: 8), Text('${state.activeAccounts.where((a) => a.includeInTotal).length} conti inclusi', style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 30), if (spots.length < 2) const EmptyState(icon: Icons.show_chart_rounded, title: 'Storico in costruzione', subtitle: 'DadaFinanza salva snapshot locali del patrimonio mentre usi l’app.') else SizedBox(height: 260, child: LineChart(LineChartData(gridData: const FlGridData(show: false), borderData: FlBorderData(show: false), titlesData: const FlTitlesData(leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))), lineBarsData: [LineChartBarData(spots: spots, isCurved: true, dotData: const FlDotData(show: false), barWidth: 3, color: Theme.of(context).colorScheme.primary)]))),
      const SizedBox(height: 28), const SectionTitle('Conti inclusi'), ...state.activeAccounts.where((a) => a.includeInTotal).map((a) => FlatMetric(label: a.name, value: state.hideBalance || a.hideBalance ? '••••' : moneyFor(state, a.balance), icon: accountIcon(a.iconKey), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountDetailPage(accountId: a.id))))),
    ]));
  }
}

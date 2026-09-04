import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../main.dart';
import '../models/models.dart';
import '../models/smart_models.dart';
import '../services/goal_planning_service.dart';
import '../services/smart_finance_engine.dart';
import '../widgets/ui_helpers.dart';
import 'quick_add_page.dart';

class PlanningScreen extends StatelessWidget {
  const PlanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final forecast = state.forecastForDays(30);
    return Scaffold(
      appBar: AppBar(title: const Text('Pianificazione')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          const SectionTitle('Prossimi 30 giorni'),
          _ForecastSummary(forecast: forecast),
          const SizedBox(height: 32),
          _PlanningLink(
            icon: Icons.pie_chart_outline_rounded,
            title: 'Budget',
            subtitle: state.budgets.isEmpty
                ? 'Imposta limiti giornalieri, settimanali, mensili o annuali.'
                : '${state.budgets.where((item) => item.enabled).length} budget attivi',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BudgetsScreen()),
            ),
          ),
          const Divider(height: 1),
          _PlanningLink(
            icon: Icons.repeat_rounded,
            title: 'Ricorrenti',
            subtitle: state.detectedRecurringPatterns.isEmpty
                ? '${state.recurring.where((item) => item.enabled).length} ricorrenze configurate'
                : '${state.recurring.where((item) => item.enabled).length} configurate · ${state.detectedRecurringPatterns.length} rilevate',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecurringScreen()),
            ),
          ),
          const Divider(height: 1),
          _PlanningLink(
            icon: Icons.flag_outlined,
            title: 'Obiettivi',
            subtitle: state.goals.isEmpty
                ? 'Crea un obiettivo di risparmio realistico.'
                : '${state.goals.where((item) => !item.archived && !item.completed).length} obiettivi attivi',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GoalsScreen()),
            ),
          ),
          const Divider(height: 1),
          _PlanningLink(
            icon: Icons.calendar_month_outlined,
            title: 'Previsioni e calendario',
            subtitle: '7, 30 o 90 giorni · confermato, previsto e stimato',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FinanceCalendarScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanningLink extends StatelessWidget {
  const _PlanningLink({
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
        minVerticalPadding: 12,
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}

class _ForecastSummary extends StatelessWidget {
  const _ForecastSummary({required this.forecast});
  final ForecastSummary forecast;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.hideBalance ? '••••••' : moneyFor(state, forecast.endingBalance),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Saldo stimato tra ${forecast.days} giorni · ${forecast.historyWeeks} settimane di storico utile',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        _ForecastLine(
          label: 'Confermato',
          value: forecast.confirmedIncome - forecast.confirmedExpense,
        ),
        _ForecastLine(
          label: 'Previsto da abitudini',
          value: forecast.predictedIncome - forecast.predictedExpense,
        ),
        _ForecastLine(
          label: 'Spesa comportamentale stimata',
          value: -forecast.estimatedExpense,
        ),
      ],
    );
  }
}

class _ForecastLine extends StatelessWidget {
  const _ForecastLine({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            state.hideBalance
                ? '••••'
                : '${value >= 0 ? '+' : '−'}${moneyFor(state, value.abs())}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: value > 0
                  ? context.financeColors.positive
                  : value < 0
                      ? context.financeColors.negative
                      : null,
            ),
          ),
        ],
      ),
    );
  }
}

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  Future<void> _delete(
    BuildContext context,
    AppState state,
    Budget budget,
  ) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Eliminare “${budget.name}”?',
      message: 'Il budget verrà eliminato. I movimenti non saranno modificati.',
    );
    if (confirmed) await state.deleteBudget(budget);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        actions: [
          IconButton(
            tooltip: 'Nuovo budget',
            onPressed: () => showBudgetEditor(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          if (state.budgets.isEmpty)
            EmptyState(
              icon: Icons.pie_chart_outline_rounded,
              title: 'Nessun budget',
              subtitle:
                  'Imposta un limite per sapere quanto puoi ancora spendere nel periodo.',
              action: FilledButton.icon(
                onPressed: () => showBudgetEditor(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crea budget'),
              ),
            )
          else
            ...state.budgets.map((budget) {
              final spent = state.budgetSpent(budget);
              final progress = state.budgetProgressFor(budget);
              final category = state.categoryById(budget.categoryId);
              final statusColor = progress >= 1
                  ? context.financeColors.negative
                  : progress >= .8
                      ? context.financeColors.warning
                      : null;
              return Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minVerticalPadding: 12,
                    leading: Icon(
                      category == null
                          ? Icons.account_balance_wallet_outlined
                          : categoryIcon(category.iconKey),
                      color: category == null ? null : Color(category.colorValue),
                    ),
                    title: Text(
                      budget.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '${_budgetPeriodLabel(budget.period)} · ${category?.name ?? 'Tutte le spese'}',
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0).toDouble(),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(99),
                          color: statusColor,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${moneyFor(state, spent)} / ${moneyFor(state, budget.limit)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Azioni budget',
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await showBudgetEditor(context, existing: budget);
                        } else if (value == 'duplicate') {
                          await state.addBudget(
                            name: '${budget.name} copia',
                            categoryId: budget.categoryId,
                            limit: budget.limit,
                            period: budget.period,
                            startDate: budget.startDate,
                            endDate: budget.endDate,
                          );
                        } else if (value == 'toggle') {
                          await state.updateBudget(
                            Budget(
                              id: budget.id,
                              name: budget.name,
                              limit: budget.limit,
                              period: budget.period,
                              startDate: budget.startDate,
                              enabled: !budget.enabled,
                              categoryId: budget.categoryId,
                              endDate: budget.endDate,
                            ),
                          );
                        } else if (value == 'delete' && context.mounted) {
                          await _delete(context, state, budget);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Modifica')),
                        const PopupMenuItem(
                          value: 'duplicate',
                          child: Text('Duplica'),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(budget.enabled ? 'Disattiva' : 'Attiva'),
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
                    onTap: () => showBudgetEditor(context, existing: budget),
                  ),
                  const Divider(height: 1),
                ],
              );
            }),
        ],
      ),
    );
  }
}

String _budgetPeriodLabel(BudgetPeriod period) => switch (period) {
      BudgetPeriod.daily => 'Giornaliero',
      BudgetPeriod.weekly => 'Settimanale',
      BudgetPeriod.monthly => 'Mensile',
      BudgetPeriod.yearly => 'Annuale',
      BudgetPeriod.custom => 'Personalizzato',
    };

Future<void> showBudgetEditor(BuildContext context, {Budget? existing}) async {
  final state = AppScope.of(context);
  final name = TextEditingController(text: existing?.name ?? '');
  final limit = TextEditingController(
    text: existing?.limit.toStringAsFixed(2) ?? '',
  );
  var period = existing?.period ?? BudgetPeriod.monthly;
  int? categoryId = existing?.categoryId;
  var startDate = existing?.startDate ?? DateTime.now();
  DateTime? endDate = existing?.endDate;
  var enabled = existing?.enabled ?? true;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
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
                existing == null ? 'Nuovo budget' : 'Modifica budget',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextField(
                controller: name,
                autofocus: existing == null,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              TextField(
                controller: limit,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Limite',
                  suffixText: '€',
                ),
              ),
              DropdownButtonFormField<BudgetPeriod>(
                initialValue: period,
                decoration: const InputDecoration(labelText: 'Periodo'),
                items: BudgetPeriod.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(_budgetPeriodLabel(item)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setSheetState(() => period = value);
                },
              ),
              DropdownButtonFormField<int?>(
                initialValue: categoryId,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Tutte le spese'),
                  ),
                  ...state.categoriesFor(TransactionType.expense).map(
                        (item) => DropdownMenuItem<int?>(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      ),
                ],
                onChanged: (value) => categoryId = value,
              ),
              if (period == BudgetPeriod.custom) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.date_range_outlined),
                  title: const Text('Inizio'),
                  trailing: Text(DateFormat('dd/MM/yyyy').format(startDate)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDate: startDate,
                    );
                    if (picked != null) {
                      setSheetState(() => startDate = picked);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_available_outlined),
                  title: const Text('Fine inclusa'),
                  trailing: Text(
                    endDate == null
                        ? 'Scegli'
                        : DateFormat('dd/MM/yyyy').format(endDate!),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: startDate,
                      lastDate: DateTime(2100),
                      initialDate: endDate ?? startDate,
                    );
                    if (picked != null) setSheetState(() => endDate = picked);
                  },
                ),
              ],
              if (existing != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Budget attivo'),
                  value: enabled,
                  onChanged: (value) => setSheetState(() => enabled = value),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final parsed =
                        double.tryParse(limit.text.replaceAll(',', '.'));
                    if (name.text.trim().isEmpty ||
                        parsed == null ||
                        parsed <= 0 ||
                        (period == BudgetPeriod.custom && endDate == null)) {
                      return;
                    }
                    if (existing == null) {
                      await state.addBudget(
                        name: name.text.trim(),
                        categoryId: categoryId,
                        limit: parsed,
                        period: period,
                        startDate: startDate,
                        endDate: period == BudgetPeriod.custom ? endDate : null,
                      );
                    } else {
                      await state.updateBudget(
                        Budget(
                          id: existing.id,
                          name: name.text.trim(),
                          limit: parsed,
                          period: period,
                          startDate: startDate,
                          enabled: enabled,
                          categoryId: categoryId,
                          endDate:
                              period == BudgetPeriod.custom ? endDate : null,
                        ),
                      );
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(existing == null ? 'Crea budget' : 'Salva modifiche'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  name.dispose();
  limit.dispose();
}

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  Future<void> _changeProgress(
    BuildContext context,
    AppState state,
    Goal goal,
  ) async {
    final controller = TextEditingController();
    var direction = 1.0;
    final result = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Aggiorna obiettivo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<double>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 1, label: Text('Aggiungi')),
                  ButtonSegment(value: -1, label: Text('Ritira')),
                ],
                selected: {direction},
                onSelectionChanged: (value) =>
                    setDialogState(() => direction = value.first),
              ),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Importo',
                  suffixText: '€',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                final parsed =
                    double.tryParse(controller.text.replaceAll(',', '.'));
                if (parsed != null && parsed > 0) {
                  Navigator.pop(context, parsed * direction);
                }
              },
              child: const Text('Conferma'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result != null) await state.contributeGoal(goal, result);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final visible = state.goals.where((item) => !item.archived).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Obiettivi'),
        actions: [
          IconButton(
            tooltip: 'Nuovo obiettivo',
            onPressed: () => showGoalEditor(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          if (visible.isEmpty)
            EmptyState(
              icon: Icons.flag_outlined,
              title: 'Nessun obiettivo',
              subtitle:
                  'Definisci una cifra e, se vuoi, una data: DadaFinanza stimerà un ritmo sostenibile.',
              action: FilledButton.icon(
                onPressed: () => showGoalEditor(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crea obiettivo'),
              ),
            )
          else
            ...visible.map((goal) {
              final progress = goal.targetAmount <= 0
                  ? 0.0
                  : goal.currentAmount / goal.targetAmount;
              final plan = GoalPlanningService.plan(state, goal);
              final budgetReserve = GoalPlanningService.weeklyBudgetReserve(state);
              final source = state.suggestedGoalTransferSource(goal);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minVerticalPadding: 12,
                    leading: CircleAvatar(
                      backgroundColor:
                          Color(goal.colorValue).withValues(alpha: .12),
                      child: Icon(
                        categoryIcon(goal.iconKey),
                        color: Color(goal.colorValue),
                      ),
                    ),
                    title: Text(
                      goal.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${moneyFor(state, goal.currentAmount)} / ${moneyFor(state, goal.targetAmount)}${goal.targetDate == null ? '' : ' · ${DateFormat('d MMM yyyy', 'it_IT').format(goal.targetDate!)}'}',
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Azioni obiettivo',
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await showGoalEditor(context, existing: goal);
                        } else if (value == 'progress') {
                          await _changeProgress(context, state, goal);
                        } else if (value == 'archive') {
                          await state.updateGoal(
                            Goal(
                              id: goal.id,
                              name: goal.name,
                              iconKey: goal.iconKey,
                              colorValue: goal.colorValue,
                              targetAmount: goal.targetAmount,
                              currentAmount: goal.currentAmount,
                              targetDate: goal.targetDate,
                              linkedAccountId: goal.linkedAccountId,
                              archived: true,
                              completed: goal.completed,
                            ),
                          );
                        } else if (value == 'delete' && context.mounted) {
                          final confirmed = await confirmDestructiveAction(
                            context,
                            title: 'Eliminare “${goal.name}”?',
                            message:
                                'L’obiettivo verrà eliminato. Conti e movimenti non saranno modificati.',
                          );
                          if (confirmed) await state.deleteGoal(goal);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Modifica')),
                        const PopupMenuItem(
                          value: 'progress',
                          child: Text('Aggiorna progresso'),
                        ),
                        const PopupMenuItem(
                          value: 'archive',
                          child: Text('Archivia'),
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
                  ),
                  LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0).toDouble(),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(99),
                    color: Color(goal.colorValue),
                  ),
                  const SizedBox(height: 10),
                  _GoalPlanText(plan: plan, budgetReserve: budgetReserve),
                  if (state.smartGoalSuggestions &&
                      goal.linkedAccountId != null &&
                      source != null &&
                      plan.realisticWeekly > 0) ...[
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuickAddPage(
                            initialTypeName: 'transfer',
                            initialAccountId: source.id,
                            initialToAccountId: goal.linkedAccountId,
                            initialAmount: plan.realisticWeekly,
                            initialGoalId: goal.id,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: Text(
                        'Prepara trasferimento · ${moneyFor(state, plan.realisticWeekly)}',
                      ),
                    ),
                  ],
                  const Divider(height: 32),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _GoalPlanText extends StatelessWidget {
  const _GoalPlanText({required this.plan, required this.budgetReserve});
  final GoalPlan plan;
  final double budgetReserve;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final text = switch (plan.status) {
      GoalPlanStatus.insufficientData =>
        'Servono almeno 3 settimane di storico utile per un consiglio realistico.',
      GoalPlanStatus.ahead =>
        'In anticipo · ritmo realistico ${moneyFor(state, plan.realisticWeekly)}/settimana',
      GoalPlanStatus.onTrack =>
        'In linea · circa ${moneyFor(state, plan.realisticWeekly)}/settimana è sostenibile',
      GoalPlanStatus.slightlyBehind =>
        'Leggermente indietro · sostenibili ${moneyFor(state, plan.realisticWeekly)}/settimana, richiesti ${moneyFor(state, plan.mathematicalWeekly)}/settimana',
      GoalPlanStatus.unrealistic =>
        'Con il cash-flow attuale la data è difficile: sostenibili circa ${moneyFor(state, plan.realisticWeekly)}/settimana.',
    };
    final estimated = plan.estimatedCompletion == null
        ? null
        : 'Stima completamento: ${DateFormat('MMM yyyy', 'it_IT').format(plan.estimatedCompletion!)}.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: Theme.of(context).textTheme.bodySmall),
        if (estimated != null)
          Text(estimated, style: Theme.of(context).textTheme.bodySmall),
        if (budgetReserve > .5)
          Text(
            'Margine prudenziale budget: ${moneyFor(state, budgetReserve)}/settimana.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

Future<void> showGoalEditor(BuildContext context, {Goal? existing}) async {
  final state = AppScope.of(context);
  final name = TextEditingController(text: existing?.name ?? '');
  final target = TextEditingController(
    text: existing?.targetAmount.toStringAsFixed(2) ?? '',
  );
  var iconKey = existing?.iconKey ?? 'savings';
  var color = Color(existing?.colorValue ?? categoryPalette.first.toARGB32());
  DateTime? targetDate = existing?.targetDate;
  int? linkedAccountId = existing?.linkedAccountId;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
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
                existing == null ? 'Nuovo obiettivo' : 'Modifica obiettivo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextField(
                controller: name,
                autofocus: existing == null,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              TextField(
                controller: target,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Importo obiettivo',
                  suffixText: '€',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(categoryIcon(iconKey), color: color),
                title: const Text('Icona'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final selected = await showIconPicker(
                    context,
                    options: categoryIconOptions,
                    selected: iconKey,
                  );
                  if (selected != null) {
                    setSheetState(() => iconKey = selected);
                  }
                },
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categoryPalette
                    .map(
                      (item) => InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setSheetState(() => color = item),
                        child: SizedBox.square(
                          dimension: 44,
                          child: Center(
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: item,
                                shape: BoxShape.circle,
                              ),
                              child: item == color
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 17,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              DropdownButtonFormField<int?>(
                initialValue: linkedAccountId,
                decoration: const InputDecoration(
                  labelText: 'Conto risparmio collegato',
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Nessun conto collegato'),
                  ),
                  ...state.activeAccounts.map(
                    (item) => DropdownMenuItem<int?>(
                      value: item.id,
                      child: Text(item.name),
                    ),
                  ),
                ],
                onChanged: (value) => linkedAccountId = value,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Data obiettivo'),
                subtitle: Text(
                  targetDate == null
                      ? 'Nessuna scadenza'
                      : DateFormat('dd/MM/yyyy').format(targetDate!),
                ),
                trailing: targetDate == null
                    ? const Icon(Icons.chevron_right_rounded)
                    : IconButton(
                        tooltip: 'Rimuovi data',
                        onPressed: () =>
                            setSheetState(() => targetDate = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                    initialDate: targetDate ??
                        DateTime.now().add(const Duration(days: 180)),
                  );
                  if (picked != null) setSheetState(() => targetDate = picked);
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final parsed =
                        double.tryParse(target.text.replaceAll(',', '.'));
                    if (name.text.trim().isEmpty || parsed == null || parsed <= 0) {
                      return;
                    }
                    if (existing == null) {
                      await state.addGoal(
                        name: name.text.trim(),
                        targetAmount: parsed,
                        iconKey: iconKey,
                        colorValue: color.toARGB32(),
                        targetDate: targetDate,
                        linkedAccountId: linkedAccountId,
                      );
                    } else {
                      final current =
                          math.min(existing.currentAmount, parsed).toDouble();
                      await state.updateGoal(
                        Goal(
                          id: existing.id,
                          name: name.text.trim(),
                          iconKey: iconKey,
                          colorValue: color.toARGB32(),
                          targetAmount: parsed,
                          currentAmount: current,
                          targetDate: targetDate,
                          linkedAccountId: linkedAccountId,
                          archived: existing.archived,
                          completed: current >= parsed,
                        ),
                      );
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(
                    existing == null ? 'Crea obiettivo' : 'Salva modifiche',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  name.dispose();
  target.dispose();
}

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  bool _alreadyExplicit(
    AppState state,
    DetectedRecurringPattern detected,
  ) =>
      state.recurring.any(
        (item) =>
            item.enabled &&
            SmartFinanceEngine.textSimilarity(
                  SmartFinanceEngine.normalizeText(
                    item.note?.isNotEmpty == true ? item.note : item.name,
                  ),
                  detected.normalizedText,
                ) >=
                .8,
      );

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final detected = state.detectedRecurringPatterns
        .where((item) => item.enabled && !_alreadyExplicit(state, item))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ricorrenti'),
        actions: [
          IconButton(
            tooltip: 'Nuova ricorrenza',
            onPressed: state.activeAccounts.isEmpty
                ? null
                : () => showRecurringEditor(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          if (detected.isNotEmpty) ...[
            const SectionTitle('Rilevate dalle tue abitudini'),
            ...detected.take(5).map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: Text(item.normalizedText),
                    subtitle: Text(
                      '${item.frequency} · ${moneyFor(state, item.amountMedian)} · ${(item.confidence * 100).round()}% confidenza',
                    ),
                    trailing: TextButton(
                      onPressed: () => showRecurringEditor(
                        context,
                        detected: item,
                      ),
                      child: const Text('Configura'),
                    ),
                  ),
                ),
            const SizedBox(height: 24),
          ],
          const SectionTitle('Configurate'),
          if (state.recurring.isEmpty)
            EmptyState(
              icon: Icons.repeat_rounded,
              title: 'Nessuna ricorrenza',
              subtitle: state.activeAccounts.isEmpty
                  ? 'Crea prima un conto per programmare movimenti ricorrenti.'
                  : 'Aggiungi bollette, abbonamenti, rate o entrate regolari.',
              action: state.activeAccounts.isEmpty
                  ? null
                  : FilledButton.icon(
                      onPressed: () => showRecurringEditor(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nuova ricorrenza'),
                    ),
            )
          else
            ...state.recurring.map((item) {
              final account = state.accountById(item.accountId);
              final invalid = account == null ||
                  account.isLocked ||
                  account.isArchived ||
                  account.isSystem;
              return Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.repeat_rounded,
                      color: transactionColor(context, item.type),
                    ),
                    title: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${DateFormat('d MMM yyyy', 'it_IT').format(item.nextDate)} · ${item.frequency}${invalid ? ' · Conto non disponibile' : ''}',
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Azioni ricorrenza',
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await showRecurringEditor(context, existing: item);
                        } else if (value == 'toggle') {
                          await state.updateRecurring(
                            RecurringPayment(
                              id: item.id,
                              name: item.name,
                              amount: item.amount,
                              type: item.type,
                              accountId: item.accountId,
                              frequency: item.frequency,
                              nextDate: item.nextDate,
                              enabled: !item.enabled,
                              autoCreate: item.autoCreate,
                              categoryId: item.categoryId,
                              note: item.note,
                              endDate: item.endDate,
                            ),
                          );
                        } else if (value == 'duplicate' && !invalid) {
                          await state.addRecurring(
                            name: '${item.name} copia',
                            amount: item.amount,
                            type: item.type,
                            accountId: item.accountId,
                            categoryId: item.categoryId,
                            frequency: item.frequency,
                            nextDate: item.nextDate,
                            note: item.note,
                            endDate: item.endDate,
                            autoCreate: item.autoCreate,
                          );
                        } else if (value == 'delete' && context.mounted) {
                          final confirmed = await confirmDestructiveAction(
                            context,
                            title: 'Eliminare “${item.name}”?',
                            message:
                                'I movimenti già registrati resteranno invariati.',
                          );
                          if (confirmed) await state.deleteRecurring(item);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Modifica')),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(item.enabled ? 'Disattiva' : 'Attiva'),
                        ),
                        const PopupMenuItem(
                          value: 'duplicate',
                          child: Text('Duplica'),
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
                  ),
                  const Divider(height: 1),
                ],
              );
            }),
        ],
      ),
    );
  }
}

Future<void> showRecurringEditor(
  BuildContext context, {
  RecurringPayment? existing,
  DetectedRecurringPattern? detected,
}) async {
  final state = AppScope.of(context);
  final usableAccounts =
      state.activeAccounts.where((item) => !item.isLocked).toList();
  if (usableAccounts.isEmpty) return;

  final name = TextEditingController(
    text: existing?.name ?? detected?.normalizedText ?? '',
  );
  final amount = TextEditingController(
    text: existing?.amount.toStringAsFixed(2) ??
        detected?.amountMedian.toStringAsFixed(2) ??
        '',
  );
  final note = TextEditingController(
    text: existing?.note ?? detected?.normalizedText ?? '',
  );
  var type = existing?.type ?? detected?.type ?? TransactionType.expense;
  if (type == TransactionType.transfer) type = TransactionType.expense;
  int accountId = existing?.accountId ??
      detected?.accountId ??
      usableAccounts.first.id;
  if (usableAccounts.every((item) => item.id != accountId)) {
    accountId = usableAccounts.first.id;
  }
  int? categoryId = existing?.categoryId ?? detected?.categoryId;
  var frequency = existing?.frequency ?? detected?.frequency ?? 'Mensile';
  var nextDate = existing?.nextDate ??
      detected?.nextExpected ??
      DateTime.now().add(const Duration(days: 30));
  DateTime? endDate = existing?.endDate;
  var enabled = existing?.enabled ?? true;
  var autoCreate = existing?.autoCreate ?? false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) {
        final availableCategories = state.categoriesFor(type);
        if (categoryId != null &&
            availableCategories.every((item) => item.id != categoryId)) {
          categoryId = null;
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
                  existing == null ? 'Nuova ricorrenza' : 'Modifica ricorrenza',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (detected != null && existing == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Precompilata da ${detected.sampleCount} movimenti simili. Controlla e conferma.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                TextField(
                  controller: name,
                  autofocus: existing == null && detected == null,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Importo',
                    suffixText: '€',
                  ),
                ),
                SegmentedButton<TransactionType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: Text('Spesa'),
                    ),
                    ButtonSegment(
                      value: TransactionType.income,
                      label: Text('Entrata'),
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged: (value) => setSheetState(() {
                    type = value.first;
                    categoryId = null;
                  }),
                ),
                DropdownButtonFormField<int>(
                  initialValue: accountId,
                  decoration: const InputDecoration(labelText: 'Conto'),
                  items: usableAccounts
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) accountId = value;
                  },
                ),
                DropdownButtonFormField<int?>(
                  key: ValueKey('recurring-category-$type-$categoryId'),
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Nessuna categoria'),
                    ),
                    ...availableCategories.map(
                      (item) => DropdownMenuItem<int?>(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => categoryId = value,
                ),
                DropdownButtonFormField<String>(
                  initialValue: frequency,
                  decoration: const InputDecoration(labelText: 'Frequenza'),
                  items: const [
                    'Settimanale',
                    'Quindicinale',
                    'Mensile',
                    'Trimestrale',
                    'Annuale',
                  ]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) frequency = value;
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Prossima data'),
                  trailing: Text(DateFormat('dd/MM/yyyy').format(nextDate)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
                      lastDate: DateTime(2100),
                      initialDate: nextDate,
                    );
                    if (picked != null) setSheetState(() => nextDate = picked);
                  },
                ),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Descrizione'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Crea automaticamente alla scadenza'),
                  subtitle: const Text(
                    'Attivalo solo per importi sufficientemente stabili.',
                  ),
                  value: autoCreate,
                  onChanged: (value) =>
                      setSheetState(() => autoCreate = value),
                ),
                if (existing != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ricorrenza attiva'),
                    value: enabled,
                    onChanged: (value) => setSheetState(() => enabled = value),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_busy_outlined),
                  title: const Text('Data fine opzionale'),
                  subtitle: Text(
                    endDate == null
                        ? 'Nessuna'
                        : DateFormat('dd/MM/yyyy').format(endDate!),
                  ),
                  trailing: endDate == null
                      ? const Icon(Icons.chevron_right_rounded)
                      : IconButton(
                          tooltip: 'Rimuovi data fine',
                          onPressed: () => setSheetState(() => endDate = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: nextDate,
                      lastDate: DateTime(2100),
                      initialDate: endDate ?? nextDate,
                    );
                    if (picked != null) setSheetState(() => endDate = picked);
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final parsed =
                          double.tryParse(amount.text.replaceAll(',', '.'));
                      if (name.text.trim().isEmpty || parsed == null || parsed <= 0) {
                        return;
                      }
                      if (existing == null) {
                        await state.addRecurring(
                          name: name.text.trim(),
                          amount: parsed,
                          type: type,
                          accountId: accountId,
                          categoryId: categoryId,
                          frequency: frequency,
                          nextDate: nextDate,
                          note: note.text.trim().isEmpty ? null : note.text.trim(),
                          endDate: endDate,
                          autoCreate: autoCreate,
                        );
                      } else {
                        await state.updateRecurring(
                          RecurringPayment(
                            id: existing.id,
                            name: name.text.trim(),
                            amount: parsed,
                            type: type,
                            accountId: accountId,
                            categoryId: categoryId,
                            frequency: frequency,
                            nextDate: nextDate,
                            enabled: enabled,
                            autoCreate: autoCreate,
                            note: note.text.trim().isEmpty ? null : note.text.trim(),
                            endDate: endDate,
                          ),
                        );
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(
                      existing == null ? 'Crea ricorrenza' : 'Salva modifiche',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  name.dispose();
  amount.dispose();
  note.dispose();
}

class FinanceCalendarScreen extends StatefulWidget {
  const FinanceCalendarScreen({super.key});

  @override
  State<FinanceCalendarScreen> createState() => _FinanceCalendarScreenState();
}

class _FinanceCalendarScreenState extends State<FinanceCalendarScreen> {
  int horizon = 30;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final forecast = state.forecastForDays(horizon);
    final now = DateTime.now();
    final end = now.add(Duration(days: horizon));
    final events = <_ForecastEvent>[];

    for (final item in state.recurring.where((item) => item.enabled)) {
      if (!item.nextDate.isBefore(now) && !item.nextDate.isAfter(end)) {
        events.add(
          _ForecastEvent(
            date: item.nextDate,
            label: item.name,
            amount: item.amount,
            type: item.type,
            source: 'Confermato',
          ),
        );
      }
    }
    for (final item in state.detectedRecurringPatterns.where(
      (item) => item.enabled && item.confidence >= .72,
    )) {
      if (!item.nextExpected.isBefore(now) && !item.nextExpected.isAfter(end)) {
        events.add(
          _ForecastEvent(
            date: item.nextExpected,
            label: item.normalizedText,
            amount: item.amountMedian,
            type: item.type,
            source: 'Previsto',
          ),
        );
      }
    }
    events.sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      appBar: AppBar(title: const Text('Previsioni')), 
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 7, label: Text('7 giorni')),
              ButtonSegment(value: 30, label: Text('30 giorni')),
              ButtonSegment(value: 90, label: Text('90 giorni')),
            ],
            selected: {horizon},
            onSelectionChanged: (value) => setState(() => horizon = value.first),
          ),
          const SizedBox(height: 24),
          _ForecastSummary(forecast: forecast),
          const SizedBox(height: 32),
          const SectionTitle('Calendario'),
          if (events.isEmpty)
            const EmptyState(
              icon: Icons.event_available_outlined,
              title: 'Nessun evento puntuale',
              subtitle:
                  'La stima comportamentale è comunque inclusa nel saldo previsto sopra.',
            )
          else
            ...events.map(
              (event) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  event.source == 'Confermato'
                      ? Icons.event_available_outlined
                      : Icons.auto_awesome_outlined,
                ),
                title: Text(event.label),
                subtitle: Text(
                  '${event.source} · ${DateFormat('EEE d MMM', 'it_IT').format(event.date)}',
                ),
                trailing: Text(
                  '${event.type == TransactionType.expense ? '−' : event.type == TransactionType.income ? '+' : ''}${moneyFor(state, event.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: transactionColor(context, event.type),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Confermato = ricorrenza configurata. Previsto = pattern storico ad alta confidenza. Stimato = comportamento aggregato, non un evento certo.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ForecastEvent {
  const _ForecastEvent({
    required this.date,
    required this.label,
    required this.amount,
    required this.type,
    required this.source,
  });

  final DateTime date;
  final String label;
  final double amount;
  final TransactionType type;
  final String source;
}

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../main.dart';
import '../models/models.dart';
import '../widgets/ui_helpers.dart';

class PlanningScreen extends StatelessWidget {
  const PlanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final activeBudgets = state.budgets.where((item) => item.enabled).length;
    final activeRecurring = state.recurring.where((item) => item.enabled).length;
    final activeGoals = state.goals.where((item) => !item.archived && !item.completed).length;
    final next = state.recurring.where((item) => item.enabled).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Pianifica')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Text(
            'Organizza il futuro senza appesantire la registrazione quotidiana.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 26),
          _PlanningTile(
            icon: Icons.pie_chart_outline_rounded,
            title: 'Budget',
            subtitle: activeBudgets == 0
                ? 'Crea limiti globali o per categoria'
                : '$activeBudgets budget attivi',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BudgetsScreen()),
            ),
          ),
          const Divider(height: 1),
          _PlanningTile(
            icon: Icons.repeat_rounded,
            title: 'Ricorrenti',
            subtitle: activeRecurring == 0
                ? 'Abbonamenti, rate, bollette e accrediti'
                : '$activeRecurring ricorrenti attivi',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecurringScreen()),
            ),
          ),
          const Divider(height: 1),
          _PlanningTile(
            icon: Icons.flag_outlined,
            title: 'Obiettivi',
            subtitle: activeGoals == 0
                ? 'Pianifica i tuoi risparmi'
                : '$activeGoals obiettivi in corso',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GoalsScreen()),
            ),
          ),
          const Divider(height: 1),
          _PlanningTile(
            icon: Icons.calendar_month_outlined,
            title: 'Calendario finanziario',
            subtitle: next == null
                ? 'Nessuna scadenza prevista'
                : 'Prossimo: ${next.name} · ${DateFormat('dd MMM', 'it_IT').format(next.nextDate)}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FinanceCalendarScreen()),
            ),
          ),
          const SizedBox(height: 32),
          const SectionTitle('Previsione'),
          _ForecastSummary(state: state),
        ],
      ),
    );
  }
}

class _PlanningTile extends StatelessWidget {
  const _PlanningTile({
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
        minVerticalPadding: 14,
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}

class _ForecastSummary extends StatelessWidget {
  const _ForecastSummary({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          FlatMetric(
            label: 'Saldo previsto a fine mese',
            value: state.hideBalance ? '••••••' : moneyFor(state, state.endOfMonthForecast),
            icon: Icons.auto_graph_rounded,
          ),
          const Divider(height: 1),
          FlatMetric(
            label: 'Disponibile da spendere',
            value: state.hideBalance ? '••••••' : moneyFor(state, state.safeToSpend),
            icon: Icons.safety_check_outlined,
          ),
        ],
      );
}

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  Future<void> _delete(BuildContext context, AppState state, Budget item) async {
    final ok = await confirmDestructiveAction(
      context,
      title: 'Eliminare “${item.name}”?',
      message: 'Il budget verrà eliminato. I movimenti e le categorie non verranno modificati.',
    );
    if (ok) await state.deleteBudget(item);
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
              subtitle: 'Imposta un limite generale o dedicato a una categoria.',
              action: FilledButton.icon(
                onPressed: () => showBudgetEditor(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crea budget'),
              ),
            )
          else
            ...state.budgets.map((item) {
              final spent = state.budgetSpent(item);
              final progress = state.budgetProgressFor(item);
              final remaining = math.max(0, item.limit - spent).toDouble();
              final category = state.categoryById(item.categoryId);
              final statusColor = progress >= 1
                  ? context.financeColors.negative
                  : progress >= .8
                      ? context.financeColors.warning
                      : Theme.of(context).colorScheme.primary;
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (category != null) ...[
                          Icon(
                            categoryIcon(category.iconKey),
                            color: Color(category.colorValue),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                              Text(
                                '${_budgetPeriodLabel(item.period)}${category == null ? ' · Tutte le categorie' : ' · ${category.name}'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: item.enabled,
                          onChanged: (value) => state.updateBudget(
                            Budget(
                              id: item.id,
                              name: item.name,
                              limit: item.limit,
                              period: item.period,
                              startDate: item.startDate,
                              enabled: value,
                              categoryId: item.categoryId,
                              endDate: item.endDate,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Azioni budget',
                          onSelected: (value) async {
                            if (value == 'edit') await showBudgetEditor(context, existing: item);
                            if (value == 'duplicate') {
                              await state.addBudget(
                                name: '${item.name} copia',
                                categoryId: item.categoryId,
                                limit: item.limit,
                                period: item.period,
                                startDate: item.startDate,
                                endDate: item.endDate,
                              );
                            }
                            if (value == 'delete' && context.mounted) {
                              await _delete(context, state, item);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Modifica')),
                            const PopupMenuItem(value: 'duplicate', child: Text('Duplica')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Elimina',
                                style: TextStyle(color: Theme.of(context).colorScheme.error),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${moneyFor(state, spent)} / ${moneyFor(state, item.limit)}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text('${(progress * 100).round()}%'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0).toDouble(),
                      minHeight: 7,
                      color: statusColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      progress >= 1
                          ? 'Superato di ${moneyFor(state, spent - item.limit)}'
                          : '${moneyFor(state, remaining)} disponibili',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

String _budgetPeriodLabel(BudgetPeriod period) => switch (period) {
      BudgetPeriod.weekly => 'Settimanale',
      BudgetPeriod.monthly => 'Mensile',
      BudgetPeriod.custom => 'Personalizzato',
    };

Future<void> showBudgetEditor(BuildContext context, {Budget? existing}) async {
  final state = AppScope.of(context);
  final name = TextEditingController(text: existing?.name ?? '');
  final limit = TextEditingController(text: existing?.limit.toStringAsFixed(2) ?? '');
  var period = existing?.period ?? BudgetPeriod.monthly;
  int? categoryId = existing?.categoryId;
  var startDate = existing?.startDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? endDate = existing?.endDate;
  var enabled = existing?.enabled ?? true;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Limite', suffixText: '€'),
              ),
              DropdownButtonFormField<BudgetPeriod>(
                initialValue: period,
                decoration: const InputDecoration(labelText: 'Periodo'),
                items: BudgetPeriod.values
                    .map((item) => DropdownMenuItem(value: item, child: Text(_budgetPeriodLabel(item))))
                    .toList(),
                onChanged: (value) => setSheetState(() => period = value ?? period),
              ),
              DropdownButtonFormField<int?>(
                initialValue: categoryId,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Tutte le categorie')),
                  ...state.categoriesFor(TransactionType.expense).map(
                        (item) => DropdownMenuItem<int?>(value: item.id, child: Text(item.name)),
                      ),
                ],
                onChanged: (value) => setSheetState(() => categoryId = value),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Data di inizio'),
                trailing: Text(DateFormat('dd/MM/yyyy').format(startDate)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDate: startDate,
                  );
                  if (picked != null) setSheetState(() => startDate = picked);
                },
              ),
              if (period == BudgetPeriod.custom)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_available_outlined),
                  title: const Text('Data di fine'),
                  trailing: Text(endDate == null ? 'Scegli' : DateFormat('dd/MM/yyyy').format(endDate!)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: startDate,
                      lastDate: DateTime(2100),
                      initialDate: endDate ?? startDate.add(const Duration(days: 30)),
                    );
                    if (picked != null) setSheetState(() => endDate = picked);
                  },
                ),
              if (existing != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Budget attivo'),
                  value: enabled,
                  onChanged: (value) => setSheetState(() => enabled = value),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final parsed = double.tryParse(limit.text.replaceAll(',', '.'));
                    if (name.text.trim().isEmpty || parsed == null || parsed <= 0) return;
                    if (period == BudgetPeriod.custom && (endDate == null || endDate!.isBefore(startDate))) return;
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
                          endDate: period == BudgetPeriod.custom ? endDate : null,
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

  Future<void> _changeProgress(BuildContext context, AppState state, Goal item, bool positive) async {
    final controller = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(positive ? 'Contribuisci' : 'Preleva dall’obiettivo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Importo', suffixText: '€'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.replaceAll(',', '.'));
              if (value != null && value > 0) Navigator.pop(context, positive ? value : -value);
            },
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) await state.contributeGoal(item, result);
  }

  Future<void> _delete(BuildContext context, AppState state, Goal item) async {
    final ok = await confirmDestructiveAction(
      context,
      title: 'Eliminare “${item.name}”?',
      message: 'L’obiettivo verrà eliminato. I saldi dei conti non verranno modificati.',
    );
    if (ok) await state.deleteGoal(item);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
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
          if (state.goals.isEmpty)
            EmptyState(
              icon: Icons.flag_outlined,
              title: 'Nessun obiettivo',
              subtitle: 'Crea un obiettivo di risparmio e segui i progressi.',
              action: FilledButton.icon(
                onPressed: () => showGoalEditor(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crea obiettivo'),
              ),
            )
          else
            ...state.goals.map((item) {
              final progress = item.targetAmount <= 0 ? 0.0 : item.currentAmount / item.targetAmount;
              final remaining = math.max(0, item.targetAmount - item.currentAmount).toDouble();
              final monthly = _monthlyGoalContribution(item, remaining);
              return Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Opacity(
                  opacity: item.archived ? .6 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Color(item.colorValue).withValues(alpha: .14),
                            child: Icon(categoryIcon(item.iconKey), color: Color(item.colorValue)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                                Text(
                                  item.completed
                                      ? 'Completato'
                                      : item.archived
                                          ? 'Archiviato'
                                          : '${moneyFor(state, remaining)} mancanti',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Azioni obiettivo',
                            onSelected: (value) async {
                              if (value == 'edit') await showGoalEditor(context, existing: item);
                              if (value == 'add') await _changeProgress(context, state, item, true);
                              if (value == 'remove') await _changeProgress(context, state, item, false);
                              if (value == 'complete') {
                                await state.updateGoal(
                                  Goal(
                                    id: item.id,
                                    name: item.name,
                                    iconKey: item.iconKey,
                                    colorValue: item.colorValue,
                                    targetAmount: item.targetAmount,
                                    currentAmount: item.targetAmount,
                                    targetDate: item.targetDate,
                                    linkedAccountId: item.linkedAccountId,
                                    archived: item.archived,
                                    completed: true,
                                  ),
                                );
                              }
                              if (value == 'archive') {
                                await state.updateGoal(
                                  Goal(
                                    id: item.id,
                                    name: item.name,
                                    iconKey: item.iconKey,
                                    colorValue: item.colorValue,
                                    targetAmount: item.targetAmount,
                                    currentAmount: item.currentAmount,
                                    targetDate: item.targetDate,
                                    linkedAccountId: item.linkedAccountId,
                                    archived: !item.archived,
                                    completed: item.completed,
                                  ),
                                );
                              }
                              if (value == 'delete' && context.mounted) await _delete(context, state, item);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('Modifica')),
                              if (!item.completed && !item.archived) ...[
                                const PopupMenuItem(value: 'add', child: Text('Contribuisci')),
                                if (item.currentAmount > 0) const PopupMenuItem(value: 'remove', child: Text('Preleva')),
                                const PopupMenuItem(value: 'complete', child: Text('Segna completato')),
                              ],
                              PopupMenuItem(value: 'archive', child: Text(item.archived ? 'Ripristina' : 'Archivia')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Elimina', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${moneyFor(state, item.currentAmount)} / ${moneyFor(state, item.targetAmount)}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text('${(progress * 100).clamp(0, 100).round()}%'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0).toDouble(),
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(99),
                        color: Color(item.colorValue),
                      ),
                      if (monthly != null && !item.completed) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Per arrivare entro ${DateFormat('MMM yyyy', 'it_IT').format(item.targetDate!)}: circa ${moneyFor(state, monthly)}/mese',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

double? _monthlyGoalContribution(Goal item, double remaining) {
  if (item.targetDate == null || remaining <= 0) return null;
  final now = DateTime.now();
  if (!item.targetDate!.isAfter(now)) return remaining;
  final months = (item.targetDate!.year - now.year) * 12 + item.targetDate!.month - now.month;
  return remaining / math.max(1, months);
}

Future<void> showGoalEditor(BuildContext context, {Goal? existing}) async {
  final state = AppScope.of(context);
  final name = TextEditingController(text: existing?.name ?? '');
  final target = TextEditingController(text: existing?.targetAmount.toStringAsFixed(2) ?? '');
  var iconKey = existing?.iconKey ?? 'savings';
  var color = Color(existing?.colorValue ?? categoryPalette.first.toARGB32());
  DateTime? targetDate = existing?.targetDate;
  int? linkedAccountId = existing?.linkedAccountId;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? 'Nuovo obiettivo' : 'Modifica obiettivo', style: Theme.of(context).textTheme.titleLarge),
              TextField(controller: name, autofocus: existing == null, decoration: const InputDecoration(labelText: 'Nome')),
              TextField(
                controller: target,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Importo obiettivo', suffixText: '€'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(categoryIcon(iconKey), color: color),
                title: const Text('Icona'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final selected = await showIconPicker(context, options: categoryIconOptions, selected: iconKey);
                  if (selected != null) setSheetState(() => iconKey = selected);
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
                              decoration: BoxDecoration(color: item, shape: BoxShape.circle),
                              child: item == color ? const Icon(Icons.check_rounded, size: 17, color: Colors.white) : null,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              DropdownButtonFormField<int?>(
                initialValue: linkedAccountId,
                decoration: const InputDecoration(labelText: 'Conto collegato opzionale'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Nessun conto collegato')),
                  ...state.activeAccounts.map(
                    (item) => DropdownMenuItem<int?>(value: item.id, child: Text(item.name)),
                  ),
                ],
                onChanged: (value) => linkedAccountId = value,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Data obiettivo'),
                subtitle: Text(targetDate == null ? 'Nessuna scadenza' : DateFormat('dd/MM/yyyy').format(targetDate!)),
                trailing: targetDate == null
                    ? const Icon(Icons.chevron_right_rounded)
                    : IconButton(
                        tooltip: 'Rimuovi data',
                        onPressed: () => setSheetState(() => targetDate = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                    initialDate: targetDate ?? DateTime.now().add(const Duration(days: 180)),
                  );
                  if (picked != null) setSheetState(() => targetDate = picked);
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final parsed = double.tryParse(target.text.replaceAll(',', '.'));
                    if (name.text.trim().isEmpty || parsed == null || parsed <= 0) return;
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
                      final current = math.min(existing.currentAmount, parsed).toDouble();
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
                  child: Text(existing == null ? 'Crea obiettivo' : 'Salva modifiche'),
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

  Future<void> _delete(BuildContext context, AppState state, RecurringPayment item) async {
    final ok = await confirmDestructiveAction(
      context,
      title: 'Eliminare “${item.name}”?',
      message: 'La ricorrenza verrà eliminata. I movimenti già registrati resteranno invariati.',
    );
    if (ok) await state.deleteRecurring(item);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ricorrenti'),
        actions: [
          IconButton(
            tooltip: 'Nuova ricorrenza',
            onPressed: state.activeAccounts.isEmpty ? null : () => showRecurringEditor(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          if (state.recurring.isEmpty)
            EmptyState(
              icon: Icons.repeat_rounded,
              title: 'Nessuna ricorrenza',
              subtitle: state.activeAccounts.isEmpty
                  ? 'Crea prima un conto per programmare movimenti ricorrenti.'
                  : 'Aggiungi abbonamenti, bollette, rate o entrate regolari.',
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
              final invalidAccount = account == null || account.isLocked || account.isArchived || account.isSystem;
              return Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minVerticalPadding: 12,
                    leading: Icon(Icons.repeat_rounded, color: transactionColor(context, item.type)),
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      '${DateFormat('dd MMM yyyy', 'it_IT').format(item.nextDate)} · ${item.frequency}${invalidAccount ? ' · Conto non disponibile' : ''}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${item.type == TransactionType.expense ? '-' : item.type == TransactionType.income ? '+' : ''}${moneyFor(state, item.amount)}',
                          style: TextStyle(fontWeight: FontWeight.w800, color: transactionColor(context, item.type)),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Azioni ricorrenza',
                          onSelected: (value) async {
                            if (value == 'edit') await showRecurringEditor(context, existing: item);
                            if (value == 'toggle') {
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
                            }
                            if (value == 'duplicate') {
                              if (!invalidAccount) {
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
                              }
                            }
                            if (value == 'delete' && context.mounted) await _delete(context, state, item);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Modifica')),
                            PopupMenuItem(value: 'toggle', child: Text(item.enabled ? 'Disattiva' : 'Attiva')),
                            const PopupMenuItem(value: 'duplicate', child: Text('Duplica')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Elimina', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                            ),
                          ],
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

Future<void> showRecurringEditor(BuildContext context, {RecurringPayment? existing}) async {
  final state = AppScope.of(context);
  final validAccounts = state.activeAccounts.where((item) => !item.isLocked).toList();
  if (validAccounts.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Non ci sono conti attivi disponibili.')));
    return;
  }

  final name = TextEditingController(text: existing?.name ?? '');
  final amount = TextEditingController(text: existing?.amount.toStringAsFixed(2) ?? '');
  final note = TextEditingController(text: existing?.note ?? '');
  var type = existing?.type ?? TransactionType.expense;
  if (type == TransactionType.transfer) type = TransactionType.expense;
  var accountId = validAccounts.any((item) => item.id == existing?.accountId)
      ? existing!.accountId
      : validAccounts.first.id;
  int? categoryId = existing?.categoryId;
  var frequency = existing?.frequency ?? 'Mensile';
  var nextDate = existing?.nextDate ?? DateTime.now().add(const Duration(days: 30));
  DateTime? endDate = existing?.endDate;
  var enabled = existing?.enabled ?? true;
  var autoCreate = existing?.autoCreate ?? false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) {
        final categories = state.categoriesFor(type);
        if (categoryId != null && !categories.any((item) => item.id == categoryId)) categoryId = null;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing == null ? 'Nuova ricorrenza' : 'Modifica ricorrenza', style: Theme.of(context).textTheme.titleLarge),
                TextField(controller: name, autofocus: existing == null, decoration: const InputDecoration(labelText: 'Nome')),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Importo', suffixText: '€'),
                ),
                SegmentedButton<TransactionType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: TransactionType.expense, label: Text('Spesa')),
                    ButtonSegment(value: TransactionType.income, label: Text('Entrata')),
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
                  items: validAccounts.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
                  onChanged: (value) => accountId = value ?? accountId,
                ),
                DropdownButtonFormField<int?>(
                  key: ValueKey('category-$type-$categoryId'),
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Senza categoria')),
                    ...categories.map((item) => DropdownMenuItem<int?>(value: item.id, child: Text(item.name))),
                  ],
                  onChanged: (value) => categoryId = value,
                ),
                DropdownButtonFormField<String>(
                  initialValue: frequency,
                  decoration: const InputDecoration(labelText: 'Frequenza'),
                  items: const ['Settimanale', 'Mensile', 'Trimestrale', 'Annuale']
                      .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) => frequency = value ?? frequency,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_busy_outlined),
                  title: const Text('Data fine opzionale'),
                  subtitle: Text(endDate == null ? 'Nessuna' : DateFormat('dd/MM/yyyy').format(endDate!)),
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
                      initialDate: endDate ?? nextDate.add(const Duration(days: 365)),
                    );
                    if (picked != null) setSheetState(() => endDate = picked);
                  },
                ),
                TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Nota opzionale')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Crea automaticamente il movimento'),
                  subtitle: const Text('Se disattivo, la ricorrenza resta solo come promemoria/previsione.'),
                  value: autoCreate,
                  onChanged: (value) => setSheetState(() => autoCreate = value),
                ),
                if (existing != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ricorrenza attiva'),
                    value: enabled,
                    onChanged: (value) => setSheetState(() => enabled = value),
                  ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final parsed = double.tryParse(amount.text.replaceAll(',', '.'));
                      if (name.text.trim().isEmpty || parsed == null || parsed <= 0) return;
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
                            frequency: frequency,
                            nextDate: nextDate,
                            enabled: enabled,
                            autoCreate: autoCreate,
                            categoryId: categoryId,
                            note: note.text.trim().isEmpty ? null : note.text.trim(),
                            endDate: endDate,
                          ),
                        );
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(existing == null ? 'Crea ricorrenza' : 'Salva modifiche'),
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
  int horizonDays = 30;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final now = DateTime.now();
    final end = now.add(Duration(days: horizonDays));
    final events = state.recurring
        .where((item) => item.enabled && !item.nextDate.isBefore(now) && item.nextDate.isBefore(end))
        .toList()
      ..sort((a, b) => a.nextDate.compareTo(b.nextDate));
    final points = _forecastPoints(state, horizonDays);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario finanziario')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 7, label: Text('7g')),
              ButtonSegment(value: 30, label: Text('30g')),
              ButtonSegment(value: 90, label: Text('3 mesi')),
            ],
            selected: {horizonDays},
            onSelectionChanged: (value) => setState(() => horizonDays = value.first),
          ),
          const SizedBox(height: 28),
          const SectionTitle('Saldo previsto'),
          SizedBox(
            height: 210,
            child: points.length < 2
                ? const Center(child: Text('Aggiungi ricorrenti per costruire la previsione.'))
                : LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: points,
                          isCurved: false,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 28),
          SectionTitle('Prossime scadenze', trailing: Text('${events.length}')),
          if (events.isEmpty)
            const EmptyState(
              icon: Icons.event_available_outlined,
              title: 'Nessuna scadenza',
              subtitle: 'Nel periodo selezionato non risultano ricorrenti attivi.',
            )
          else
            ...events.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.event_outlined, color: transactionColor(context, item.type)),
                title: Text(item.name),
                subtitle: Text(DateFormat('EEEE d MMMM', 'it_IT').format(item.nextDate)),
                trailing: Text(
                  '${item.type == TransactionType.expense ? '-' : item.type == TransactionType.income ? '+' : ''}${moneyFor(state, item.amount)}',
                  style: TextStyle(fontWeight: FontWeight.w800, color: transactionColor(context, item.type)),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'La previsione usa il saldo attuale e le ricorrenze attive. È una stima, non un saldo bancario garantito.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

List<FlSpot> _forecastPoints(AppState state, int horizonDays) {
  final now = DateTime.now();
  var balance = state.totalBalance;
  final result = <FlSpot>[FlSpot(0, balance)];
  final events = state.recurring.where((item) => item.enabled).toList();
  for (var day = 1; day <= horizonDays; day++) {
    final date = DateTime(now.year, now.month, now.day + day);
    for (final event in events) {
      if (event.nextDate.year == date.year && event.nextDate.month == date.month && event.nextDate.day == date.day) {
        if (event.type == TransactionType.expense) balance -= event.amount;
        if (event.type == TransactionType.income) balance += event.amount;
      }
    }
    result.add(FlSpot(day.toDouble(), balance));
  }
  return result;
}

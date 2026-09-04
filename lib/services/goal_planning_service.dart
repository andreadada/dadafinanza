import 'dart:math' as math;

import '../app_state.dart';
import '../models/models.dart';
import '../models/smart_models.dart';
import 'smart_finance_engine.dart';

/// Applies budget guardrails to the adaptive goal planner.
///
/// A budget is a spending ceiling, not a certain future expense. Only
/// the portion of current budget allowance above normal historical
/// spending is reserved before suggesting a goal contribution.
class GoalPlanningService {
  static double weeklyBudgetReserve(AppState state, {DateTime? now}) {
    final target = now ?? DateTime.now();
    final active = state.budgets.where((budget) {
      if (!budget.enabled) return false;
      final (from, to) = state.budgetRange(budget, now: target);
      return !target.isBefore(from) && target.isBefore(to);
    }).toList();
    if (active.isEmpty) return 0;

    final totalBudgets =
        active.where((item) => item.categoryId == null).toList();
    final selected = totalBudgets.isNotEmpty ? totalBudgets : active;
    final allowances = selected
        .map((budget) => _remainingWeeklyAllowance(state, budget, target))
        .where((value) => value > 0)
        .toList();
    if (allowances.isEmpty) return 0;

    final budgetAllowance = totalBudgets.isNotEmpty
        ? allowances.reduce(math.min)
        : allowances.fold<double>(0, (sum, value) => sum + value);
    final history = SmartFinanceEngine.weeklyTotals(
      state.analyticTransactions().toList(),
      TransactionType.expense,
      now: target,
    );
    final historicalWeekly = SmartFinanceEngine.median(
      history.where((value) => value > 0),
    );
    if (historicalWeekly <= 0) return 0;

    final guardedAllowance = math.min(
      budgetAllowance,
      historicalWeekly * 1.5,
    );
    return math.max(0, guardedAllowance - historicalWeekly).toDouble();
  }

  static double _remainingWeeklyAllowance(
    AppState state,
    Budget budget,
    DateTime now,
  ) {
    final (_, to) = state.budgetRange(budget, now: now);
    if (to.year >= 9999) return 0;
    final remaining = math.max(
      0,
      budget.limit - state.budgetSpent(budget, now: now),
    );
    final daysLeft = math.max(1, to.difference(now).inDays);
    return remaining / daysLeft * 7;
  }

  static GoalPlan plan(AppState state, Goal goal, {DateTime? now}) {
    final target = now ?? DateTime.now();
    final activeGoals = state.goals
        .where((item) => !item.archived && !item.completed)
        .length;
    final base = SmartFinanceEngine.planGoal(
      goal: goal,
      currentAmount: goal.currentAmount,
      totalBalance: state.totalBalance,
      transactions: state.analyticTransactions().toList(),
      recurring: state.recurring,
      competingGoals: activeGoals,
      now: target,
    );
    if (base.status == GoalPlanStatus.insufficientData ||
        base.remaining <= 0) {
      return base;
    }

    final reserve = weeklyBudgetReserve(state, now: target);
    final realistic = math.max(0, base.realisticWeekly - reserve).toDouble();
    final status = goal.targetDate == null
        ? GoalPlanStatus.onTrack
        : realistic >= base.mathematicalWeekly * 1.15
            ? GoalPlanStatus.ahead
            : realistic >= base.mathematicalWeekly * .9
                ? GoalPlanStatus.onTrack
                : realistic >= base.mathematicalWeekly * .55
                    ? GoalPlanStatus.slightlyBehind
                    : GoalPlanStatus.unrealistic;
    final estimated = realistic <= 0
        ? null
        : target.add(
            Duration(days: ((base.remaining / realistic) * 7).ceil()),
          );
    return GoalPlan(
      goalId: base.goalId,
      remaining: base.remaining,
      mathematicalWeekly: base.mathematicalWeekly,
      realisticWeekly: realistic,
      status: status,
      historyWeeks: base.historyWeeks,
      safetyBuffer: base.safetyBuffer,
      estimatedCompletion: estimated,
    );
  }
}

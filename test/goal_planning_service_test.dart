import 'package:dadafinanza/app_state.dart';
import 'package:dadafinanza/data/app_database.dart';
import 'package:dadafinanza/models/models.dart';
import 'package:dadafinanza/services/goal_ledger_service.dart';
import 'package:dadafinanza/services/goal_planning_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual goal ledger deltas stay within zero and target', () {
    expect(
      GoalLedgerService.clampManualDelta(
        current: 80,
        target: 100,
        delta: 50,
      ),
      20,
    );
    expect(
      GoalLedgerService.clampManualDelta(
        current: 30,
        target: 100,
        delta: -80,
      ),
      -30,
    );
  });

  test('budget guardrail reduces aggressive saving suggestions', () {
    final now = DateTime(2026, 9, 15, 12);
    final state = AppState(AppDatabase());
    state.accounts = [_account(now, balance: 5000)];
    state.transactions = [
      for (var week = 1; week <= 4; week++) ...[
        _transaction(
          id: week * 10,
          type: TransactionType.income,
          amount: 300,
          date: now.subtract(Duration(days: week * 7)),
          now: now,
        ),
        _transaction(
          id: week * 10 + 1,
          type: TransactionType.expense,
          amount: 100,
          date: now.subtract(Duration(days: week * 7)),
          now: now,
        ),
      ],
    ];
    state.budgets = [
      Budget(
        id: 1,
        name: 'Spese mese',
        limit: 2000,
        period: BudgetPeriod.monthly,
        startDate: DateTime(2026, 9),
        enabled: true,
      ),
    ];
    final goal = Goal(
      id: 1,
      name: 'Viaggio',
      iconKey: 'savings',
      colorValue: 0xFF777777,
      targetAmount: 1000,
      currentAmount: 0,
      targetDate: now.add(const Duration(days: 140)),
      archived: false,
      completed: false,
    );
    state.goals = [goal];

    final base = state.goalPlan(goal, now: now);
    final reserve = GoalPlanningService.weeklyBudgetReserve(
      state,
      now: now,
    );
    final guarded = GoalPlanningService.plan(state, goal, now: now);

    expect(reserve, greaterThan(0));
    expect(guarded.realisticWeekly, lessThan(base.realisticWeekly));
    expect(guarded.realisticWeekly, greaterThanOrEqualTo(0));
  });

  test('strict budget below historical spend adds no duplicate reserve', () {
    final now = DateTime(2026, 9, 15, 12);
    final state = AppState(AppDatabase());
    state.accounts = [_account(now, balance: 1000)];
    state.transactions = [
      for (var week = 1; week <= 4; week++)
        _transaction(
          id: week,
          type: TransactionType.expense,
          amount: 250,
          date: now.subtract(Duration(days: week * 7)),
          now: now,
        ),
    ];
    state.budgets = [
      Budget(
        id: 1,
        name: 'Budget prudente',
        limit: 300,
        period: BudgetPeriod.monthly,
        startDate: DateTime(2026, 9),
        enabled: true,
      ),
    ];

    expect(
      GoalPlanningService.weeklyBudgetReserve(state, now: now),
      0,
    );
  });
}

Account _account(DateTime now, {required double balance}) => Account(
      id: 1,
      name: 'Principale',
      balance: balance,
      colorValue: 0xFF777777,
      iconKey: 'bank',
      accountType: AccountType.checking,
      includeInTotal: true,
      includeInAnalytics: true,
      isLocked: false,
      isArchived: false,
      hideBalance: false,
      isSystem: false,
      createdAt: now,
      updatedAt: now,
    );

FinanceTransaction _transaction({
  required int id,
  required TransactionType type,
  required double amount,
  required DateTime date,
  required DateTime now,
}) =>
    FinanceTransaction(
      id: id,
      type: type,
      amount: amount,
      accountId: 1,
      date: date,
      includeInAnalytics: true,
      createdAt: now,
      updatedAt: now,
    );

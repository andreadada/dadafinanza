import 'package:dadafinanza/app_state.dart';
import 'package:dadafinanza/data/app_database.dart';
import 'package:dadafinanza/models/models.dart';
import 'package:dadafinanza/models/smart_models.dart';
import 'package:dadafinanza/services/smart_finance_engine.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceTransaction transaction({
  required int id,
  required String note,
  required double amount,
  required DateTime date,
  TransactionType type = TransactionType.expense,
  int accountId = 1,
  int? categoryId = 1,
}) => FinanceTransaction(
  id: id,
  type: type,
  amount: amount,
  accountId: accountId,
  categoryId: type == TransactionType.transfer ? null : categoryId,
  date: date,
  note: note,
  includeInAnalytics: true,
  createdAt: date,
  updatedAt: date,
);

LearnedPattern pattern({
  int id = 1,
  String text = 'lidl',
  int categoryId = 1,
  int accountId = 1,
  int samples = 3,
  int accepted = 0,
  int rejected = 0,
  double amount = 30,
  DateTime? date,
}) {
  final target = date ?? DateTime(2026, 9, 4, 12);
  return LearnedPattern(
    id: id,
    signature: '$text|expense|$categoryId|$accountId|0',
    normalizedText: text,
    type: TransactionType.expense,
    categoryId: categoryId,
    accountId: accountId,
    tags: const [],
    sampleCount: samples,
    acceptedCount: accepted,
    rejectedCount: rejected,
    amountMedian: amount,
    amountMin: amount * .95,
    amountMax: amount * 1.05,
    weekdayMask: 1 << (target.weekday - 1),
    hourBucket: SmartFinanceEngine.hourBucket(target),
    firstSeen: target.subtract(const Duration(days: 28)),
    lastSeen: target,
    enabled: true,
  );
}

Goal goal({DateTime? targetDate}) => Goal(
  id: 1,
  name: 'Console',
  iconKey: 'savings',
  colorValue: 0xFF888888,
  targetAmount: 300,
  currentAmount: 0,
  targetDate: targetDate,
  archived: false,
  completed: false,
);

void main() {
  group('text normalization', () {
    test('normalizes noisy merchant descriptions deterministically', () {
      expect(
        SmartFinanceEngine.normalizeText('LIDL 1234 - Carta, Pavia'),
        'lidl',
      );
      expect(SmartFinanceEngine.normalizeText('  Lidl Pavia  '), 'lidl');
    });

    test('token similarity recognizes related descriptions', () {
      expect(
        SmartFinanceEngine.textSimilarity('LIDL centro', 'Lidl centro Pavia'),
        greaterThan(.8),
      );
      expect(
        SmartFinanceEngine.textSimilarity('Netflix', 'benzina Q8'),
        lessThan(.3),
      );
    });
  });

  group('confidence engine', () {
    final date = DateTime(2026, 9, 4, 12);

    test('balanced mode requires at least three samples', () {
      final result = SmartFinanceEngine.suggest(
        note: 'LIDL',
        type: TransactionType.expense,
        amount: 30,
        date: date,
        patterns: [pattern(samples: 2, date: date)],
        rules: const [],
        suppressedTexts: const {},
        sensitivity: SmartSensitivity.balanced,
      );
      expect(result, isNull);
    });

    test(
      'coherent repeated merchant produces a high-confidence suggestion',
      () {
        final result = SmartFinanceEngine.suggest(
          note: 'LIDL',
          type: TransactionType.expense,
          amount: 30,
          date: date,
          patterns: [pattern(samples: 5, date: date)],
          rules: const [],
          suppressedTexts: const {},
          sensitivity: SmartSensitivity.balanced,
        );
        expect(result, isNotNull);
        expect(result!.categoryId, 1);
        expect(result.shouldSurface, isTrue);
        expect(result.score, greaterThanOrEqualTo(.74));
      },
    );

    test('competing categories suppress ambiguous suggestions', () {
      final result = SmartFinanceEngine.suggest(
        note: 'Amazon',
        type: TransactionType.expense,
        amount: 30,
        date: date,
        patterns: [
          pattern(id: 1, text: 'amazon', categoryId: 1, samples: 4, date: date),
          pattern(id: 2, text: 'amazon', categoryId: 2, samples: 4, date: date),
        ],
        rules: const [],
        suppressedTexts: const {},
        sensitivity: SmartSensitivity.balanced,
      );
      expect(result, isNull);
    });

    test('negative feedback lowers confidence below surface threshold', () {
      final result = SmartFinanceEngine.suggest(
        note: 'LIDL',
        type: TransactionType.expense,
        amount: 30,
        date: date,
        patterns: [pattern(samples: 3, rejected: 3, date: date)],
        rules: const [],
        suppressedTexts: const {},
        sensitivity: SmartSensitivity.balanced,
      );
      expect(result, isNull);
    });

    test('suppression always wins for learned suggestions', () {
      final result = SmartFinanceEngine.suggest(
        note: 'LIDL',
        type: TransactionType.expense,
        amount: 30,
        date: date,
        patterns: [pattern(samples: 8, accepted: 8, date: date)],
        rules: const [],
        suppressedTexts: const {'lidl'},
        sensitivity: SmartSensitivity.proactive,
      );
      expect(result, isNull);
    });

    test('manual rule has precedence over learned patterns', () {
      const rule = AutomationRule(
        id: 9,
        name: 'LIDL manuale',
        enabled: true,
        containsText: 'LIDL',
        type: TransactionType.expense,
        categoryId: 2,
      );
      final result = SmartFinanceEngine.suggest(
        note: 'LIDL centro',
        type: TransactionType.expense,
        amount: 30,
        date: date,
        patterns: [pattern(samples: 8, accepted: 8, date: date)],
        rules: const [rule],
        suppressedTexts: const {},
        sensitivity: SmartSensitivity.balanced,
      );
      expect(result, isNotNull);
      expect(result!.source, SuggestionSource.manualRule);
      expect(result.categoryId, 2);
      expect(result.score, 1);
    });
  });

  group('recurring detection', () {
    test('detects a stable weekly sequence', () {
      final values = [
        transaction(
          id: 1,
          note: 'Spotify',
          amount: 10.99,
          date: DateTime(2026, 1, 1),
        ),
        transaction(
          id: 2,
          note: 'Spotify',
          amount: 10.99,
          date: DateTime(2026, 1, 8),
        ),
        transaction(
          id: 3,
          note: 'Spotify',
          amount: 10.99,
          date: DateTime(2026, 1, 15),
        ),
      ];
      final result = SmartFinanceEngine.detectRecurring(values);
      expect(result, hasLength(1));
      expect(result.first.frequency, 'Settimanale');
      expect(result.first.confidence, greaterThan(.9));
    });

    test('detects a stable monthly sequence', () {
      final values = [
        transaction(
          id: 1,
          note: 'Palestra',
          amount: 30,
          date: DateTime(2026, 1, 3),
        ),
        transaction(
          id: 2,
          note: 'Palestra',
          amount: 30,
          date: DateTime(2026, 2, 3),
        ),
        transaction(
          id: 3,
          note: 'Palestra',
          amount: 30,
          date: DateTime(2026, 3, 3),
        ),
      ];
      final result = SmartFinanceEngine.detectRecurring(values);
      expect(result, hasLength(1));
      expect(result.first.frequency, 'Mensile');
    });
  });

  group('forecast and adaptive goals', () {
    test('forecast separates explicit and learned recurring cash flows', () {
      final now = DateTime(2026, 9, 4);
      final forecast = SmartFinanceEngine.forecast(
        days: 30,
        startingBalance: 1000,
        transactions: const [],
        recurring: [
          RecurringPayment(
            id: 1,
            name: 'Affitto',
            amount: 100,
            type: TransactionType.expense,
            accountId: 1,
            frequency: 'Mensile',
            nextDate: DateTime(2026, 9, 10),
            enabled: true,
            autoCreate: false,
          ),
        ],
        detectedRecurring: [
          DetectedRecurringPattern(
            id: 1,
            signature: 'spotify',
            normalizedText: 'spotify',
            type: TransactionType.expense,
            categoryId: 1,
            accountId: 1,
            frequency: 'Mensile',
            amountMedian: 10.99,
            confidence: .95,
            sampleCount: 5,
            lastSeen: DateTime(2026, 8, 20),
            nextExpected: DateTime(2026, 9, 20),
            enabled: true,
          ),
        ],
        now: now,
      );
      expect(forecast.confirmedExpense, 100);
      expect(forecast.predictedExpense, closeTo(10.99, .001));
      expect(forecast.endingBalance, lessThan(1000));
    });

    test('goal planner waits for enough history', () {
      final now = DateTime(2026, 9, 4);
      final plan = SmartFinanceEngine.planGoal(
        goal: goal(targetDate: now.add(const Duration(days: 90))),
        currentAmount: 0,
        totalBalance: 1000,
        transactions: [
          transaction(
            id: 1,
            note: 'spesa',
            amount: 50,
            date: DateTime(2026, 8, 24),
          ),
        ],
        recurring: const [],
        competingGoals: 1,
        now: now,
      );
      expect(plan.status, GoalPlanStatus.insufficientData);
      expect(plan.realisticWeekly, 0);
    });

    test(
      'one unusually large income does not create an aggressive saving target',
      () {
        final now = DateTime(2026, 9, 4);
        final start = DateTime(2026, 8, 31);
        final values = <FinanceTransaction>[];
        var id = 1;
        for (var week = 1; week <= 6; week++) {
          final date = start.subtract(Duration(days: week * 7));
          values.add(
            transaction(
              id: id++,
              note: 'Entrata regolare',
              amount: week == 1 ? 5000 : 100,
              date: date,
              type: TransactionType.income,
            ),
          );
          values.add(
            transaction(
              id: id++,
              note: 'Spese settimana',
              amount: 90,
              date: date.add(const Duration(days: 1)),
            ),
          );
        }
        final plan = SmartFinanceEngine.planGoal(
          goal: goal(targetDate: now.add(const Duration(days: 140))),
          currentAmount: 0,
          totalBalance: 5500,
          transactions: values,
          recurring: const [],
          competingGoals: 1,
          now: now,
        );
        expect(plan.historyWeeks, greaterThanOrEqualTo(5));
        expect(plan.realisticWeekly, lessThan(20));
      },
    );
  });

  group('budget periods', () {
    test('daily budget uses the selected calendar day', () {
      final state = AppState(AppDatabase());
      final target = DateTime(2026, 9, 4, 18);
      final range = state.budgetRange(
        Budget(
          id: 1,
          name: 'Oggi',
          limit: 20,
          period: BudgetPeriod.daily,
          startDate: target,
          enabled: true,
        ),
        now: target,
      );
      expect(range.$1, DateTime(2026, 9, 4));
      expect(range.$2, DateTime(2026, 9, 5));
    });

    test('yearly budget spans January through next January', () {
      final state = AppState(AppDatabase());
      final target = DateTime(2026, 9, 4);
      final range = state.budgetRange(
        Budget(
          id: 1,
          name: 'Tecnologia',
          limit: 1200,
          period: BudgetPeriod.yearly,
          startDate: target,
          enabled: true,
        ),
        now: target,
      );
      expect(range.$1, DateTime(2026, 1, 1));
      expect(range.$2, DateTime(2027, 1, 1));
    });
  });
}

import 'models.dart';

enum SmartSensitivity { conservative, balanced, proactive }

enum SuggestionConfidence { low, medium, high, veryHigh }

enum SuggestionSource { manualRule, learnedPattern, recurringPattern }

enum GoalPlanStatus {
  ahead,
  onTrack,
  slightlyBehind,
  unrealistic,
  insufficientData,
}

class LearnedPattern {
  const LearnedPattern({
    required this.id,
    required this.signature,
    required this.normalizedText,
    required this.type,
    required this.sampleCount,
    required this.acceptedCount,
    required this.rejectedCount,
    required this.amountMedian,
    required this.amountMin,
    required this.amountMax,
    required this.weekdayMask,
    required this.hourBucket,
    required this.firstSeen,
    required this.lastSeen,
    required this.enabled,
    this.categoryId,
    this.accountId,
    this.toAccountId,
    this.tags = const [],
  });

  final int id;
  final String signature;
  final String normalizedText;
  final TransactionType type;
  final int? categoryId;
  final int? accountId;
  final int? toAccountId;
  final List<String> tags;
  final int sampleCount;
  final int acceptedCount;
  final int rejectedCount;
  final double amountMedian;
  final double amountMin;
  final double amountMax;
  final int weekdayMask;
  final int hourBucket;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final bool enabled;

  factory LearnedPattern.fromMap(Map<String, Object?> map) => LearnedPattern(
    id: map['id'] as int,
    signature: map['signature'] as String,
    normalizedText: map['normalized_text'] as String,
    type: TransactionTypeX.fromDb(map['type'] as String),
    categoryId: map['category_id'] as int?,
    accountId: map['account_id'] as int?,
    toAccountId: map['to_account_id'] as int?,
    tags: ((map['tags'] as String?) ?? '')
        .split('|')
        .where((item) => item.isNotEmpty)
        .toList(),
    sampleCount: map['sample_count'] as int? ?? 0,
    acceptedCount: map['accepted_count'] as int? ?? 0,
    rejectedCount: map['rejected_count'] as int? ?? 0,
    amountMedian: (map['amount_median'] as num? ?? 0).toDouble(),
    amountMin: (map['amount_min'] as num? ?? 0).toDouble(),
    amountMax: (map['amount_max'] as num? ?? 0).toDouble(),
    weekdayMask: map['weekday_mask'] as int? ?? 0,
    hourBucket: map['hour_bucket'] as int? ?? -1,
    firstSeen: DateTime.fromMillisecondsSinceEpoch(map['first_seen'] as int),
    lastSeen: DateTime.fromMillisecondsSinceEpoch(map['last_seen'] as int),
    enabled: (map['enabled'] as int? ?? 1) == 1,
  );
}

class DetectedRecurringPattern {
  const DetectedRecurringPattern({
    required this.id,
    required this.signature,
    required this.normalizedText,
    required this.type,
    required this.frequency,
    required this.amountMedian,
    required this.confidence,
    required this.sampleCount,
    required this.lastSeen,
    required this.nextExpected,
    required this.enabled,
    this.categoryId,
    this.accountId,
  });

  final int id;
  final String signature;
  final String normalizedText;
  final TransactionType type;
  final int? categoryId;
  final int? accountId;
  final String frequency;
  final double amountMedian;
  final double confidence;
  final int sampleCount;
  final DateTime lastSeen;
  final DateTime nextExpected;
  final bool enabled;

  factory DetectedRecurringPattern.fromMap(Map<String, Object?> map) =>
      DetectedRecurringPattern(
        id: map['id'] as int,
        signature: map['signature'] as String,
        normalizedText: map['normalized_text'] as String,
        type: TransactionTypeX.fromDb(map['type'] as String),
        categoryId: map['category_id'] as int?,
        accountId: map['account_id'] as int?,
        frequency: map['frequency'] as String,
        amountMedian: (map['amount_median'] as num).toDouble(),
        confidence: (map['confidence'] as num).toDouble(),
        sampleCount: map['sample_count'] as int,
        lastSeen: DateTime.fromMillisecondsSinceEpoch(map['last_seen'] as int),
        nextExpected: DateTime.fromMillisecondsSinceEpoch(
          map['next_expected'] as int,
        ),
        enabled: (map['enabled'] as int? ?? 1) == 1,
      );
}

class SmartSuggestion {
  const SmartSuggestion({
    required this.source,
    required this.confidence,
    required this.score,
    required this.type,
    required this.explanation,
    this.patternId,
    this.ruleId,
    this.categoryId,
    this.accountId,
    this.toAccountId,
    this.tags = const [],
    this.amount,
  });

  final SuggestionSource source;
  final SuggestionConfidence confidence;
  final double score;
  final int? patternId;
  final int? ruleId;
  final TransactionType type;
  final int? categoryId;
  final int? accountId;
  final int? toAccountId;
  final List<String> tags;
  final double? amount;
  final String explanation;

  bool get shouldSurface =>
      confidence == SuggestionConfidence.high ||
      confidence == SuggestionConfidence.veryHigh;
}

class ForecastSummary {
  const ForecastSummary({
    required this.days,
    required this.startingBalance,
    required this.confirmedIncome,
    required this.confirmedExpense,
    required this.predictedIncome,
    required this.predictedExpense,
    required this.estimatedExpense,
    required this.endingBalance,
    required this.historyWeeks,
  });

  final int days;
  final double startingBalance;
  final double confirmedIncome;
  final double confirmedExpense;
  final double predictedIncome;
  final double predictedExpense;
  final double estimatedExpense;
  final double endingBalance;
  final int historyWeeks;
}

class GoalPlan {
  const GoalPlan({
    required this.goalId,
    required this.remaining,
    required this.mathematicalWeekly,
    required this.realisticWeekly,
    required this.status,
    required this.historyWeeks,
    required this.safetyBuffer,
    this.estimatedCompletion,
  });

  final int goalId;
  final double remaining;
  final double mathematicalWeekly;
  final double realisticWeekly;
  final GoalPlanStatus status;
  final int historyWeeks;
  final double safetyBuffer;
  final DateTime? estimatedCompletion;
}

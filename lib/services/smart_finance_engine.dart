import 'dart:math' as math;

import '../models/models.dart';
import '../models/smart_models.dart';

class SmartFinanceEngine {
  static const _genericTokens = <String>{
    'pagamento',
    'carta',
    'pos',
    'acquisto',
    'spesa',
    'bonifico',
    'addebito',
    'credito',
    'eur',
    'euro',
    'pavia',
    'milano',
  };

  static String normalizeText(String? input) {
    if (input == null || input.trim().isEmpty) return '';
    var text = input.toLowerCase().trim();
    text = text.replaceAll(RegExp(r'[^a-zàèéìòù0-9]+', unicode: true), ' ');
    text = text.replaceAll(RegExp(r'\b\d{3,}\b'), ' ');
    final values = text
        .split(RegExp(r'\s+'))
        .where((token) => token.length > 1 && !_genericTokens.contains(token))
        .toList();
    return values.join(' ').trim();
  }

  static Set<String> tokens(String? input) =>
      normalizeText(input).split(' ').where((item) => item.isNotEmpty).toSet();

  static double textSimilarity(String a, String b) {
    final left = normalizeText(a);
    final right = normalizeText(b);
    if (left.isEmpty || right.isEmpty) return 0;
    if (left == right) return 1;
    if (left.contains(right) || right.contains(left)) return .9;
    if (left.startsWith(right) || right.startsWith(left)) return .94;
    final leftTokens = tokens(left);
    final rightTokens = tokens(right);
    final union = leftTokens.union(rightTokens).length;
    if (union == 0) return 0;
    final overlap = leftTokens.intersection(rightTokens).length / union;
    return overlap.clamp(0.0, 1.0);
  }

  static double median(Iterable<double> input) {
    final values = input.toList()..sort();
    if (values.isEmpty) return 0;
    final middle = values.length ~/ 2;
    if (values.length.isOdd) return values[middle];
    return (values[middle - 1] + values[middle]) / 2;
  }

  static int hourBucket(DateTime date) => date.hour ~/ 4;

  static String patternSignature({
    required String normalizedText,
    required TransactionType type,
    int? categoryId,
    int? accountId,
    int? toAccountId,
  }) =>
      '$normalizedText|${type.name}|${categoryId ?? 0}|${accountId ?? 0}|${toAccountId ?? 0}';

  static List<LearnedPattern> buildPatterns(
    List<FinanceTransaction> transactions, {
    Map<String, LearnedPattern> previous = const {},
  }) {
    final groups = <String, List<FinanceTransaction>>{};
    for (final item in transactions) {
      if (item.refundOfTransactionId != null) continue;
      final normalized = normalizeText(item.note);
      if (normalized.isEmpty) continue;
      final signature = patternSignature(
        normalizedText: normalized,
        type: item.type,
        categoryId: item.categoryId,
        accountId: item.accountId,
        toAccountId: item.toAccountId,
      );
      groups.putIfAbsent(signature, () => []).add(item);
    }

    final result = <LearnedPattern>[];
    for (final entry in groups.entries) {
      final items = entry.value..sort((a, b) => a.date.compareTo(b.date));
      final sample = items.first;
      final normalized = normalizeText(sample.note);
      final old = previous[entry.key];
      final tagCounts = <String, int>{};
      for (final item in items) {
        for (final tag in item.tags) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }
      final dominantTags = tagCounts.entries
          .where(
            (entry) => entry.value >= math.max(2, (items.length * .6).ceil()),
          )
          .map((entry) => entry.key)
          .take(3)
          .toList();
      var weekdayMask = 0;
      final buckets = <int, int>{};
      for (final item in items) {
        weekdayMask |= 1 << (item.date.weekday - 1);
        final bucket = hourBucket(item.date);
        buckets[bucket] = (buckets[bucket] ?? 0) + 1;
      }
      final dominantBucket = buckets.entries.isEmpty
          ? -1
          : (buckets.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .first
                .key;
      result.add(
        LearnedPattern(
          id: old?.id ?? 0,
          signature: entry.key,
          normalizedText: normalized,
          type: sample.type,
          categoryId: sample.categoryId,
          accountId: sample.accountId,
          toAccountId: sample.toAccountId,
          tags: dominantTags,
          sampleCount: items.length,
          acceptedCount: old?.acceptedCount ?? 0,
          rejectedCount: old?.rejectedCount ?? 0,
          amountMedian: median(items.map((item) => item.amount)),
          amountMin: items.map((item) => item.amount).reduce(math.min),
          amountMax: items.map((item) => item.amount).reduce(math.max),
          weekdayMask: weekdayMask,
          hourBucket: dominantBucket,
          firstSeen: items.first.date,
          lastSeen: items.last.date,
          enabled: old?.enabled ?? true,
        ),
      );
    }
    return result;
  }

  static SmartSuggestion? suggest({
    required String? note,
    required TransactionType type,
    required double? amount,
    required DateTime date,
    required List<LearnedPattern> patterns,
    required List<AutomationRule> rules,
    required Set<String> suppressedTexts,
    required SmartSensitivity sensitivity,
    bool useDescription = true,
    bool useAmount = true,
    bool useTime = true,
  }) {
    final normalized = normalizeText(note);

    for (final rule in rules.where((item) => item.enabled)) {
      if (rule.type != null && rule.type != type) continue;
      if (amount != null && rule.minAmount != null && amount < rule.minAmount!)
        continue;
      if (amount != null && rule.maxAmount != null && amount > rule.maxAmount!)
        continue;
      if (rule.containsText?.isNotEmpty == true) {
        if (normalized.isEmpty ||
            !normalizeText(note).contains(normalizeText(rule.containsText))) {
          continue;
        }
      }
      if (rule.categoryId == null &&
          rule.accountId == null &&
          rule.addTag == null) {
        continue;
      }
      return SmartSuggestion(
        source: SuggestionSource.manualRule,
        confidence: SuggestionConfidence.veryHigh,
        score: 1,
        ruleId: rule.id,
        type: type,
        categoryId: rule.categoryId,
        accountId: rule.accountId,
        tags: rule.addTag == null ? const [] : [rule.addTag!],
        explanation: 'Corrisponde alla regola manuale “${rule.name}”.',
      );
    }

    if (normalized.isEmpty || suppressedTexts.contains(normalized)) return null;

    final minSamples = switch (sensitivity) {
      SmartSensitivity.conservative => 4,
      SmartSensitivity.balanced => 3,
      SmartSensitivity.proactive => 2,
    };
    final highThreshold = switch (sensitivity) {
      SmartSensitivity.conservative => .82,
      SmartSensitivity.balanced => .74,
      SmartSensitivity.proactive => .66,
    };

    final matching = patterns
        .where(
          (pattern) =>
              pattern.enabled &&
              pattern.type == type &&
              pattern.sampleCount >= minSamples &&
              (!useDescription ||
                  textSimilarity(normalized, pattern.normalizedText) >= .45),
        )
        .toList();
    if (matching.isEmpty) return null;

    final totalMatchingSamples = matching.fold<int>(
      0,
      (sum, item) => sum + item.sampleCount,
    );
    LearnedPattern? best;
    var bestScore = 0.0;
    var secondScore = 0.0;

    for (final pattern in matching) {
      final similarity = useDescription
          ? textSimilarity(normalized, pattern.normalizedText)
          : 0.0;
      final frequency = math.min(1.0, pattern.sampleCount / 8.0);
      final dominance = totalMatchingSamples == 0
          ? 0.0
          : pattern.sampleCount / totalMatchingSamples;
      var amountScore = 0.0;
      if (useAmount && amount != null && pattern.amountMedian > 0) {
        final relative =
            (amount - pattern.amountMedian).abs() /
            math.max(1, pattern.amountMedian);
        amountScore = (1 - relative).clamp(0.0, 1.0);
      }
      var weekdayScore = 0.0;
      var timeScore = 0.0;
      if (useTime) {
        weekdayScore = (pattern.weekdayMask & (1 << (date.weekday - 1))) != 0
            ? 1
            : 0;
        timeScore = pattern.hourBucket == hourBucket(date) ? 1 : 0;
      }
      final feedbackTotal = pattern.acceptedCount + pattern.rejectedCount;
      final feedback = feedbackTotal == 0
          ? 0.5
          : pattern.acceptedCount / feedbackTotal;
      final rejectionPenalty = feedbackTotal == 0
          ? 0.0
          : pattern.rejectedCount / feedbackTotal;
      var score =
          similarity * .5 +
          frequency * .12 +
          dominance * .18 +
          amountScore * .08 +
          weekdayScore * .025 +
          timeScore * .025 +
          feedback * .10 -
          rejectionPenalty * .12;
      score = score.clamp(0.0, 1.0);
      if (score > bestScore) {
        secondScore = bestScore;
        bestScore = score;
        best = pattern;
      } else if (score > secondScore) {
        secondScore = score;
      }
    }

    if (best == null) return null;
    final margin = bestScore - secondScore;
    if (bestScore < highThreshold || margin < .08) return null;

    final confidence = bestScore >= .9 && margin >= .15
        ? SuggestionConfidence.veryHigh
        : SuggestionConfidence.high;
    final amountHint =
        useAmount &&
            best.sampleCount >= 4 &&
            (best.amountMax - best.amountMin) /
                    math.max(1, best.amountMedian) <=
                .12
        ? best.amountMedian
        : null;
    return SmartSuggestion(
      source: SuggestionSource.learnedPattern,
      confidence: confidence,
      score: bestScore,
      patternId: best.id,
      type: best.type,
      categoryId: best.categoryId,
      accountId: best.accountId,
      toAccountId: best.toAccountId,
      tags: best.tags,
      amount: amountHint,
      explanation:
          'Hai registrato ${best.sampleCount} movimenti simili a “${best.normalizedText}” con la stessa combinazione principale.',
    );
  }

  static List<DetectedRecurringPattern> detectRecurring(
    List<FinanceTransaction> transactions,
  ) {
    final groups = <String, List<FinanceTransaction>>{};
    for (final item in transactions) {
      if (item.refundOfTransactionId != null) continue;
      final normalized = normalizeText(item.note);
      if (normalized.isEmpty) continue;
      final key =
          '$normalized|${item.type.name}|${item.accountId}|${item.categoryId ?? 0}';
      groups.putIfAbsent(key, () => []).add(item);
    }
    final output = <DetectedRecurringPattern>[];
    for (final entry in groups.entries) {
      final items = entry.value..sort((a, b) => a.date.compareTo(b.date));
      if (items.length < 3) continue;
      final intervals = <double>[];
      for (var i = 1; i < items.length; i++) {
        intervals.add(
          items[i].date.difference(items[i - 1].date).inHours / 24.0,
        );
      }
      final interval = median(intervals);
      String? frequency;
      var nextDays = 0;
      if ((interval - 7).abs() <= 2) {
        frequency = 'Settimanale';
        nextDays = 7;
      } else if ((interval - 14).abs() <= 3) {
        frequency = 'Quindicinale';
        nextDays = 14;
      } else if (interval >= 27 && interval <= 33) {
        frequency = 'Mensile';
        nextDays = interval.round();
      } else if (interval >= 350 && interval <= 380) {
        frequency = 'Annuale';
        nextDays = 365;
      }
      if (frequency == null) continue;
      final amountMedian = median(items.map((item) => item.amount));
      final amountSpread =
          items
              .map((item) => (item.amount - amountMedian).abs())
              .reduce(math.max) /
          math.max(1, amountMedian);
      final intervalSpread =
          intervals.map((value) => (value - interval).abs()).reduce(math.max) /
          math.max(1, interval);
      final confidence =
          (1 -
                  amountSpread * .45 -
                  intervalSpread * .55 +
                  math.min(.12, (items.length - 3) * .03))
              .clamp(0.0, 1.0);
      if (confidence < .65) continue;
      final sample = items.last;
      output.add(
        DetectedRecurringPattern(
          id: 0,
          signature: entry.key,
          normalizedText: normalizeText(sample.note),
          type: sample.type,
          categoryId: sample.categoryId,
          accountId: sample.accountId,
          frequency: frequency,
          amountMedian: amountMedian,
          confidence: confidence,
          sampleCount: items.length,
          lastSeen: sample.date,
          nextExpected: sample.date.add(Duration(days: nextDays)),
          enabled: true,
        ),
      );
    }
    output.sort((a, b) => b.confidence.compareTo(a.confidence));
    return output;
  }

  static List<double> weeklyTotals(
    List<FinanceTransaction> transactions,
    TransactionType type, {
    DateTime? now,
    int weeks = 12,
  }) {
    final target = now ?? DateTime.now();
    final startOfThisWeek = DateTime(
      target.year,
      target.month,
      target.day,
    ).subtract(Duration(days: target.weekday - DateTime.monday));
    final result = <double>[];
    for (var index = weeks; index > 0; index--) {
      final from = startOfThisWeek.subtract(Duration(days: index * 7));
      final to = from.add(const Duration(days: 7));
      final total = transactions
          .where(
            (item) =>
                item.type == type &&
                item.refundOfTransactionId == null &&
                !item.date.isBefore(from) &&
                item.date.isBefore(to),
          )
          .fold<double>(0, (sum, item) => sum + item.amount);
      result.add(total);
    }
    return result;
  }

  static ForecastSummary forecast({
    required int days,
    required double startingBalance,
    required List<FinanceTransaction> transactions,
    required List<RecurringPayment> recurring,
    required List<DetectedRecurringPattern> detectedRecurring,
    DateTime? now,
  }) {
    final target = now ?? DateTime.now();
    final end = target.add(Duration(days: days));
    var confirmedIncome = 0.0;
    var confirmedExpense = 0.0;
    for (final item in recurring.where((item) => item.enabled)) {
      var date = item.nextDate;
      var guard = 0;
      while (!date.isAfter(end) && guard < 64) {
        if (!date.isBefore(target)) {
          if (item.type == TransactionType.income)
            confirmedIncome += item.amount;
          if (item.type == TransactionType.expense)
            confirmedExpense += item.amount;
        }
        date = _advance(date, item.frequency);
        guard++;
      }
    }

    final explicitNames = recurring
        .where((item) => item.enabled)
        .map((item) => normalizeText(item.name.isEmpty ? item.note : item.name))
        .where((item) => item.isNotEmpty)
        .toSet();
    var predictedIncome = 0.0;
    var predictedExpense = 0.0;
    for (final item in detectedRecurring.where(
      (item) => item.enabled && item.confidence >= .72,
    )) {
      if (explicitNames.any(
        (name) => textSimilarity(name, item.normalizedText) >= .8,
      )) {
        continue;
      }
      var date = item.nextExpected;
      var guard = 0;
      while (!date.isAfter(end) && guard < 32) {
        if (!date.isBefore(target)) {
          if (item.type == TransactionType.income) {
            predictedIncome += item.amountMedian;
          }
          if (item.type == TransactionType.expense) {
            predictedExpense += item.amountMedian;
          }
        }
        date = _advance(date, item.frequency);
        guard++;
      }
    }

    final expenseWeeks = weeklyTotals(
      transactions,
      TransactionType.expense,
      now: target,
    );
    final nonZeroWeeks = expenseWeeks.where((value) => value > 0).toList();
    final historyWeeks = nonZeroWeeks.length;
    final weeklyMedianExpense = median(nonZeroWeeks);
    final recurringWeeklyEquivalent =
        (confirmedExpense + predictedExpense) / math.max(1, days) * 7;
    final variableWeekly = math.max(
      0,
      weeklyMedianExpense - recurringWeeklyEquivalent,
    );
    final estimatedExpense = variableWeekly * (days / 7.0);
    final ending =
        startingBalance +
        confirmedIncome -
        confirmedExpense +
        predictedIncome -
        predictedExpense -
        estimatedExpense;
    return ForecastSummary(
      days: days,
      startingBalance: startingBalance,
      confirmedIncome: confirmedIncome,
      confirmedExpense: confirmedExpense,
      predictedIncome: predictedIncome,
      predictedExpense: predictedExpense,
      estimatedExpense: estimatedExpense,
      endingBalance: ending,
      historyWeeks: historyWeeks,
    );
  }

  static GoalPlan planGoal({
    required Goal goal,
    required double currentAmount,
    required double totalBalance,
    required List<FinanceTransaction> transactions,
    required List<RecurringPayment> recurring,
    required int competingGoals,
    DateTime? now,
  }) {
    final target = now ?? DateTime.now();
    final remaining = math.max(0, goal.targetAmount - currentAmount).toDouble();
    final expenseWeeks = weeklyTotals(
      transactions,
      TransactionType.expense,
      now: target,
    );
    final incomeWeeks = weeklyTotals(
      transactions,
      TransactionType.income,
      now: target,
    );
    final completedWeeks = <double>[];
    for (
      var index = 0;
      index < math.min(expenseWeeks.length, incomeWeeks.length);
      index++
    ) {
      if (expenseWeeks[index] > 0 || incomeWeeks[index] > 0) {
        completedWeeks.add(incomeWeeks[index] - expenseWeeks[index]);
      }
    }
    final historyWeeks = completedWeeks.length;
    final medianExpense = median(expenseWeeks.where((value) => value > 0));
    final medianSurplus = median(completedWeeks);
    final safetyBuffer = math
        .max(totalBalance * .15, medianExpense * 2)
        .toDouble();
    final liquidReserve = math.max(0, totalBalance - safetyBuffer).toDouble();
    final recurringNetWeekly = recurring
        .where((item) => item.enabled)
        .fold<double>(0, (sum, item) {
          final sign = item.type == TransactionType.income
              ? 1.0
              : item.type == TransactionType.expense
              ? -1.0
              : 0.0;
          final factor = switch (item.frequency) {
            'Settimanale' => 1.0,
            'Quindicinale' => .5,
            'Trimestrale' => 1 / 13,
            'Annuale' => 1 / 52,
            _ => 1 / 4.345,
          };
          return sum + item.amount * sign * factor;
        });
    final stableWeeklyCapacity = math.max(
      0,
      medianSurplus * .55 + math.max(0, recurringNetWeekly) * .25,
    );
    final share = math.max(1, competingGoals);
    final realisticWeekly = historyWeeks < 3
        ? 0.0
        : math
              .max(
                0,
                math.min(
                  stableWeeklyCapacity / share,
                  liquidReserve / math.max(8, share * 4),
                ),
              )
              .toDouble();

    var mathematicalWeekly = 0.0;
    var weeksLeft = 0.0;
    if (goal.targetDate != null && goal.targetDate!.isAfter(target)) {
      weeksLeft = math.max(1, goal.targetDate!.difference(target).inDays / 7.0);
      mathematicalWeekly = remaining / weeksLeft;
    }

    DateTime? estimatedCompletion;
    if (realisticWeekly > 0 && remaining > 0) {
      estimatedCompletion = target.add(
        Duration(days: ((remaining / realisticWeekly) * 7).ceil()),
      );
    }

    final status = historyWeeks < 3
        ? GoalPlanStatus.insufficientData
        : remaining <= 0
        ? GoalPlanStatus.ahead
        : goal.targetDate == null
        ? GoalPlanStatus.onTrack
        : realisticWeekly >= mathematicalWeekly * 1.15
        ? GoalPlanStatus.ahead
        : realisticWeekly >= mathematicalWeekly * .9
        ? GoalPlanStatus.onTrack
        : realisticWeekly >= mathematicalWeekly * .55
        ? GoalPlanStatus.slightlyBehind
        : GoalPlanStatus.unrealistic;

    return GoalPlan(
      goalId: goal.id,
      remaining: remaining,
      mathematicalWeekly: mathematicalWeekly,
      realisticWeekly: realisticWeekly,
      status: status,
      historyWeeks: historyWeeks,
      safetyBuffer: safetyBuffer,
      estimatedCompletion: estimatedCompletion,
    );
  }

  static DateTime _advance(DateTime date, String frequency) =>
      switch (frequency) {
        'Settimanale' => date.add(const Duration(days: 7)),
        'Quindicinale' => date.add(const Duration(days: 14)),
        'Trimestrale' => DateTime(date.year, date.month + 3, date.day),
        'Annuale' => DateTime(date.year + 1, date.month, date.day),
        _ => DateTime(date.year, date.month + 1, date.day),
      };
}

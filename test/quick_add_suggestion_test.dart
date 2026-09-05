import 'package:dadafinanza/app_state.dart';
import 'package:dadafinanza/data/app_database.dart';
import 'package:dadafinanza/main.dart';
import 'package:dadafinanza/models/models.dart';
import 'package:dadafinanza/models/smart_models.dart';
import 'package:dadafinanza/screens/quick_add_page.dart';
import 'package:dadafinanza/services/smart_finance_engine.dart';
import 'package:dadafinanza/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class FakeLearningDatabase extends AppDatabase {
  List<LearnedPattern> patterns = const [];
  final feedbackKinds = <String>[];
  final suppressions = <String>{};

  @override
  Future<void> recordPatternFeedback(
    int? patternId,
    String kind,
    String queryText,
  ) async {
    feedbackKinds.add(kind);
  }

  @override
  Future<List<LearnedPattern>> learnedPatterns() async => patterns;

  @override
  Future<void> suppressSuggestion(String normalizedText) async {
    suppressions.add(normalizedText);
  }

  @override
  Future<Set<String>> suppressedSuggestionTexts() async => suppressions;
}

AppState suggestionState({required int samples}) {
  final database = FakeLearningDatabase();
  final state = AppState(database);
  final now = DateTime(2026, 9, 4, 12);
  state.accounts = [
    Account(
      id: 1,
      name: 'Revolut',
      balance: 100,
      colorValue: 0xFF607DFF,
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
    ),
  ];
  state.categories = const [
    Category(
      id: 2,
      name: 'Altro',
      iconKey: 'category',
      colorValue: 0xFF777777,
      type: TransactionType.expense,
      quickOrder: 0,
    ),
    Category(
      id: 1,
      name: 'Alimentari',
      iconKey: 'groceries',
      colorValue: 0xFF888888,
      type: TransactionType.expense,
      quickOrder: 1,
    ),
  ];
  state.learnedPatterns = [
    LearnedPattern(
      id: 1,
      signature: 'lidl|expense|1|1|0',
      normalizedText: 'lidl',
      type: TransactionType.expense,
      categoryId: 1,
      accountId: 1,
      sampleCount: samples,
      acceptedCount: 0,
      rejectedCount: 0,
      amountMedian: 30,
      amountMin: 28,
      amountMax: 32,
      weekdayMask: 1 << (now.weekday - 1),
      hourBucket: SmartFinanceEngine.hourBucket(now),
      firstSeen: now.subtract(const Duration(days: 30)),
      lastSeen: now,
      enabled: true,
    ),
  ];
  database.patterns = state.learnedPatterns;
  state.smartSuggestionsEnabled = true;
  state.smartSensitivity = SmartSensitivity.balanced;
  state.smartUseDescription = true;
  state.smartUseAmount = true;
  state.smartUseTime = true;
  return state;
}

Finder descriptionField() => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      widget.decoration?.labelText == 'Descrizione opzionale',
);

Future<void> pumpQuickAdd(WidgetTester tester, AppState state) async {
  await initializeDateFormatting('it_IT');
  await tester.pumpWidget(
    AppScope(
      notifier: state,
      child: MaterialApp(theme: AppTheme.light(), home: const QuickAddPage()),
    ),
  );
  await tester.pump();
}

Future<void> enterHighConfidenceSuggestion(
  WidgetTester tester,
  AppState state,
) async {
  await pumpQuickAdd(tester, state);
  await tester.enterText(descriptionField(), 'LIDL');
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> openPreview(WidgetTester tester) async {
  final fab = tester.widget<FloatingActionButton>(
    find.byType(FloatingActionButton),
  );
  fab.onPressed!();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Completa stays hidden below the balanced sample threshold', (
    tester,
  ) async {
    await pumpQuickAdd(tester, suggestionState(samples: 2));
    await tester.enterText(descriptionField(), 'LIDL');
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Completa'), findsNothing);
  });

  testWidgets('Completa appears for a coherent high-confidence pattern', (
    tester,
  ) async {
    await enterHighConfidenceSuggestion(tester, suggestionState(samples: 5));
    expect(find.text('Completa'), findsOneWidget);
  });

  testWidgets('smart suggestion preview explains what would be applied', (
    tester,
  ) async {
    await enterHighConfidenceSuggestion(tester, suggestionState(samples: 5));
    await openPreview(tester);

    expect(find.text('Ti suggerisco'), findsOneWidget);
    expect(find.textContaining('Alimentari'), findsWidgets);
    expect(find.textContaining('Revolut'), findsWidgets);
    expect(find.textContaining('5 movimenti simili'), findsOneWidget);
    expect(find.text('Applica'), findsOneWidget);
    expect(find.text('Modifica'), findsOneWidget);
    expect(find.text('Non suggerire'), findsOneWidget);
  });

  testWidgets('Applica fills the suggested category and records acceptance', (
    tester,
  ) async {
    final state = suggestionState(samples: 5);
    final database = state.database as FakeLearningDatabase;
    await enterHighConfidenceSuggestion(tester, state);
    await openPreview(tester);

    await tester.tap(find.text('Applica'));
    await tester.pumpAndSettle();

    expect(database.feedbackKinds, contains('accepted'));
    expect(find.text('Alimentari'), findsNWidgets(2));
    expect(find.text('Completa'), findsNothing);
  });

  testWidgets('Modifica records corrective feedback without applying', (
    tester,
  ) async {
    final state = suggestionState(samples: 5);
    final database = state.database as FakeLearningDatabase;
    await enterHighConfidenceSuggestion(tester, state);
    await openPreview(tester);

    await tester.tap(find.text('Modifica'));
    await tester.pumpAndSettle();

    expect(database.feedbackKinds, contains('modified'));
    expect(find.text('Completa'), findsNothing);
  });

  testWidgets('Non suggerire records rejection', (tester) async {
    final state = suggestionState(samples: 5);
    final database = state.database as FakeLearningDatabase;
    await enterHighConfidenceSuggestion(tester, state);
    await openPreview(tester);

    await tester.tap(find.text('Non suggerire'));
    await tester.pumpAndSettle();

    expect(database.feedbackKinds, contains('rejected'));
    expect(find.text('Completa'), findsNothing);
  });

  testWidgets('permanent suppression stores normalized description locally', (
    tester,
  ) async {
    final state = suggestionState(samples: 5);
    final database = state.database as FakeLearningDatabase;
    await enterHighConfidenceSuggestion(tester, state);
    await openPreview(tester);

    await tester.tap(find.text('Non suggerire più per questo testo'));
    await tester.pumpAndSettle();

    expect(database.suppressions, contains('lidl'));
    expect(state.suppressedSuggestionTexts, contains('lidl'));
    expect(find.text('Completa'), findsNothing);
  });
}

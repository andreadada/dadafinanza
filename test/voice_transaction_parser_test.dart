import 'package:dadafinanza/models/models.dart';
import 'package:dadafinanza/models/quick_capture_models.dart';
import 'package:dadafinanza/services/voice_transaction_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = VoiceTransactionParser();
  final now = DateTime(2026, 9, 5, 12);
  final accounts = [
    _account(1, 'Revolut'),
    _account(2, 'Intesa'),
    _account(3, 'Risparmio'),
  ];
  final categories = [
    const Category(
      id: 10,
      name: 'Uscite',
      iconKey: 'wallet',
      colorValue: 0xff000000,
      type: TransactionType.expense,
      quickOrder: null,
    ),
    const Category(
      id: 11,
      name: 'Benzina',
      iconKey: 'car',
      colorValue: 0xff000000,
      type: TransactionType.expense,
      quickOrder: null,
    ),
    const Category(
      id: 12,
      name: 'Stipendio',
      iconKey: 'wallet',
      colorValue: 0xff000000,
      type: TransactionType.income,
      quickOrder: null,
    ),
  ];

  test('Segna 1,80 euro per Uscite', () {
    final result = parser.parse(
      'Segna 1,80 euro per Uscite',
      accounts: accounts,
      categories: categories,
      now: now,
    );
    expect(result.draft.amountCents, 180);
    expect(result.draft.categoryId, 10);
    expect(result.draft.type, TransactionType.expense);
  });

  test('parses spoken euro and cents', () {
    for (final phrase in [
      'Segna un euro e ottanta per Uscite',
      'Segna 1 euro e 80 per Uscite',
    ]) {
      final result = parser.parse(
        phrase,
        accounts: accounts,
        categories: categories,
        now: now,
      );
      expect(result.draft.amountCents, 180, reason: phrase);
    }
    final twelveFifty = parser.parse(
      'Segna 12 euro e 50 per Uscite',
      accounts: accounts,
      categories: categories,
      now: now,
    );
    expect(twelveFifty.draft.amountCents, 1250);
  });

  test('parses category, yesterday and account', () {
    final result = parser.parse(
      'Segna in Uscite ieri 1,33 euro nel conto Revolut',
      accounts: accounts,
      categories: categories,
      now: now,
    );
    expect(result.draft.amountCents, 133);
    expect(result.draft.categoryId, 10);
    expect(result.draft.accountId, 1);
    expect(result.draft.date?.day, 4);
  });

  test('parses merchant expense', () {
    final result = parser.parse(
      "Ho speso 12,50 euro al McDonald's con Revolut",
      accounts: accounts,
      categories: categories,
      now: now,
    );
    expect(result.draft.type, TransactionType.expense);
    expect(result.draft.amountCents, 1250);
    expect(result.draft.accountId, 1);
    expect(result.draft.note, "McDonald's");
  });

  test('parses fuel category and account', () {
    final result = parser.parse(
      'Ho pagato 22 euro di benzina con Revolut',
      accounts: accounts,
      categories: categories,
      now: now,
    );
    expect(result.draft.type, TransactionType.expense);
    expect(result.draft.amountCents, 2200);
    expect(result.draft.categoryId, 11);
    expect(result.draft.accountId, 1);
  });

  test('parses income with note', () {
    final result = parser.parse(
      'Entrata di 850 euro oggi su Intesa, stipendio',
      accounts: accounts,
      categories: categories,
      now: now,
    );
    expect(result.draft.type, TransactionType.income);
    expect(result.draft.amountCents, 85000);
    expect(result.draft.accountId, 2);
    expect(result.draft.note?.toLowerCase(), 'stipendio');
  });

  test('parses transfer accounts and tomorrow', () {
    final result = parser.parse(
      'Trasferisci 50 euro da Revolut a Risparmio domani',
      accounts: accounts,
      categories: categories,
      now: now,
    );
    expect(result.draft.type, TransactionType.transfer);
    expect(result.draft.amountCents, 5000);
    expect(result.draft.accountId, 1);
    expect(result.draft.toAccountId, 3);
    expect(result.draft.date?.day, 6);
  });

  test('numeric formats map to cents', () {
    for (final phrase in ['1.80 euro', '1,80 euro', '€12', '12€']) {
      final result = parser.parse(
        phrase,
        accounts: accounts,
        categories: categories,
        now: now,
      );
      expect(result.draft.amountCents, phrase.contains('12') ? 1200 : 180);
    }
  });

  test('similar account names are surfaced as ambiguous', () {
    final result = parser.parse(
      'Ho speso 10 euro con Revolut',
      accounts: [...accounts, _account(4, 'Revolut Business')],
      categories: categories,
      now: now,
    );
    expect(result.draft.accountId, isNull);
    expect(
      result.issues.any((issue) => issue.type == VoiceIssueType.ambiguousAccount),
      isTrue,
    );
  });

  test('similar category names are surfaced as ambiguous', () {
    final result = parser.parse(
      'Segna 10 euro al bar',
      accounts: accounts,
      categories: [
        ...categories,
        const Category(
          id: 20,
          name: 'Bar',
          iconKey: 'food',
          colorValue: 0xff000000,
          type: TransactionType.expense,
          quickOrder: null,
        ),
        const Category(
          id: 21,
          name: 'Bar e ristoranti',
          iconKey: 'food',
          colorValue: 0xff000000,
          type: TransactionType.expense,
          quickOrder: null,
        ),
      ],
      now: now,
    );
    expect(result.draft.categoryId, isNull);
    expect(
      result.issues.any(
        (issue) => issue.type == VoiceIssueType.ambiguousCategory,
      ),
      isTrue,
    );
  });
}

Account _account(int id, String name) => Account(
      id: id,
      name: name,
      balance: 0,
      colorValue: 0xff000000,
      iconKey: 'wallet',
      accountType: AccountType.checking,
      includeInTotal: true,
      includeInAnalytics: true,
      isLocked: false,
      isArchived: false,
      hideBalance: false,
      isSystem: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

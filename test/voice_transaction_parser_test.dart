import 'package:dadafinanza/models/models.dart';
import 'package:dadafinanza/models/quick_capture_models.dart';
import 'package:dadafinanza/services/voice_transaction_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = VoiceTransactionParser();
  final now = DateTime(2026, 9, 5, 12, 0);
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

  test('parses word amount', () {
    final result = parser.parse(
      'Segna un euro e ottanta per Uscite',
      accounts: accounts,
      categories: categories,
      now: now,
    );
    expect(result.draft.amountCents, 180);
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

  test('ambiguous account remains unresolved', () {
    final result = parser.parse(
      'Ho speso 10 euro con Revolut',
      accounts: [...accounts, _account(4, 'Revolut Business')],
      categories: categories,
      now: now,
    );
    // Exact match Revolut wins over the longer partial name.
    expect(result.draft.accountId, 1);
  });

  test('ambiguous category is surfaced', () {
    final ambiguousCategories = [
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
    ];
    final result = parser.parse(
      'Segna 10 euro al bar',
      accounts: accounts,
      categories: ambiguousCategories,
      now: now,
    );
    expect(
      result.issues.any((issue) => issue.type == VoiceIssueType.ambiguousCategory),
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

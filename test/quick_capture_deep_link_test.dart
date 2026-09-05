import 'package:dadafinanza/app_state.dart';
import 'package:dadafinanza/data/app_database.dart';
import 'package:dadafinanza/models/models.dart';
import 'package:dadafinanza/models/quick_capture_models.dart';
import 'package:dadafinanza/services/quick_capture_deep_link_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = QuickCaptureDeepLinkService();

  test('parses expense amount category account and note without saving', () async {
    final state = _state();
    final draft = await service.fromUri(
      state,
      Uri.parse(
        'dadafinanza://quick-add?type=expense&amount=1.80&category=Uscite&account=Revolut&note=Caffe',
      ),
    );
    expect(draft, isNotNull);
    expect(draft!.type, TransactionType.expense);
    expect(draft.amountCents, 180);
    expect(draft.categoryId, 10);
    expect(draft.accountId, 1);
    expect(draft.note, 'Caffe');
    expect(draft.source, QuickCaptureSource.deepLink);
    expect(state.transactions, isEmpty);
  });

  test('voice deep link only marks the draft for listening', () async {
    final state = _state();
    final draft = await service.fromUri(
      state,
      Uri.parse('dadafinanza://quick-add?voice=1&account=Revolut'),
    );
    expect(draft?.startVoice, isTrue);
    expect(draft?.accountId, 1);
    expect(state.transactions, isEmpty);
  });

  test('transfer validates destination and clears category', () async {
    final state = _state();
    final draft = await service.fromUri(
      state,
      Uri.parse(
        'dadafinanza://quick-add?type=transfer&amount=50&account=Revolut&toAccount=Risparmio&category=Uscite',
      ),
    );
    expect(draft?.type, TransactionType.transfer);
    expect(draft?.amountCents, 5000);
    expect(draft?.accountId, 1);
    expect(draft?.toAccountId, 2);
    expect(draft?.categoryId, isNull);
  });

  test('unknown entities never map to another account or category', () async {
    final state = _state();
    final draft = await service.fromUri(
      state,
      Uri.parse(
        'dadafinanza://quick-add?type=expense&amount=3&account=Missing&category=Missing',
      ),
    );
    expect(draft?.accountId, isNull);
    expect(draft?.categoryId, isNull);
  });

  test('same source and destination is rejected in draft', () async {
    final state = _state();
    final draft = await service.fromUri(
      state,
      Uri.parse(
        'dadafinanza://quick-add?type=transfer&account=Revolut&toAccount=Revolut',
      ),
    );
    expect(draft?.accountId, 1);
    expect(draft?.toAccountId, isNull);
  });

  test('unrelated URI is ignored', () async {
    expect(
      await service.fromUri(_state(), Uri.parse('https://example.com/quick-add')),
      isNull,
    );
  });
}

AppState _state() {
  final state = AppState(AppDatabase());
  final now = DateTime(2026, 9, 5);
  state.accounts = [
    _account(1, 'Revolut', now),
    _account(2, 'Risparmio', now),
  ];
  state.categories = const [
    Category(
      id: 10,
      name: 'Uscite',
      iconKey: 'wallet',
      colorValue: 0xff111111,
      type: TransactionType.expense,
      quickOrder: 0,
    ),
  ];
  state.transactions = [];
  return state;
}

Account _account(int id, String name, DateTime now) => Account(
      id: id,
      name: name,
      balance: 0,
      colorValue: 0xff111111,
      iconKey: 'wallet',
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

import 'package:flutter_test/flutter_test.dart';

import 'package:dadafinanza/app_state.dart';
import 'package:dadafinanza/data/app_database.dart';
import 'package:dadafinanza/models/models.dart';
import 'package:dadafinanza/services/account_scope_service.dart';

void main() {
  group('AccountScopeService', () {
    late AppState state;
    late DateTime now;

    setUp(() {
      now = DateTime.now();
      state = AppState(AppDatabase());
      state.accounts = [
        _account(id: 1, name: 'Revolut', balance: 120),
        _account(id: 2, name: 'Portafoglio', balance: 35),
      ];
      state.transactions = [
        _transaction(
          id: 1,
          type: TransactionType.income,
          amount: 200,
          accountId: 1,
          date: now,
        ),
        _transaction(
          id: 2,
          type: TransactionType.expense,
          amount: 50,
          accountId: 1,
          date: now,
        ),
        _transaction(
          id: 3,
          type: TransactionType.expense,
          amount: 15,
          accountId: 2,
          date: now,
        ),
        _transaction(
          id: 4,
          type: TransactionType.transfer,
          amount: 20,
          accountId: 1,
          toAccountId: 2,
          date: now,
        ),
      ];
    });

    test('null scope means Totale', () {
      expect(AccountScopeService.balance(state, null), 155);
      expect(
        AccountScopeService.monthTotal(
          state,
          null,
          TransactionType.expense,
        ),
        65,
      );
    });

    test('selected account limits income and expense totals', () {
      expect(AccountScopeService.balance(state, 1), 120);
      expect(
        AccountScopeService.monthTotal(
          state,
          1,
          TransactionType.income,
        ),
        200,
      );
      expect(
        AccountScopeService.monthTotal(
          state,
          1,
          TransactionType.expense,
        ),
        50,
      );
      expect(
        AccountScopeService.monthTotal(
          state,
          2,
          TransactionType.expense,
        ),
        15,
      );
    });

    test('account transaction scope includes incoming transfers', () {
      final revolut = AccountScopeService.transactions(state, 1);
      final wallet = AccountScopeService.transactions(state, 2);

      expect(revolut.map((item) => item.id), containsAll([1, 2, 4]));
      expect(revolut.map((item) => item.id), isNot(contains(3)));
      expect(wallet.map((item) => item.id), containsAll([3, 4]));
    });
  });
}

Account _account({
  required int id,
  required String name,
  required double balance,
}) => Account(
  id: id,
  name: name,
  balance: balance,
  colorValue: 0xFF777777,
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

FinanceTransaction _transaction({
  required int id,
  required TransactionType type,
  required double amount,
  required int accountId,
  required DateTime date,
  int? toAccountId,
}) => FinanceTransaction(
  id: id,
  type: type,
  amount: amount,
  accountId: accountId,
  toAccountId: toAccountId,
  date: date,
  includeInAnalytics: true,
  createdAt: date,
  updatedAt: date,
);

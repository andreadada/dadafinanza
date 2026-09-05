import 'dart:math' as math;

import '../app_state.dart';
import '../models/models.dart';

class AccountScopeService {
  const AccountScopeService._();

  static bool includesTransaction(FinanceTransaction item, int accountId) =>
      item.accountId == accountId || item.toAccountId == accountId;

  static List<FinanceTransaction> transactions(
    AppState state,
    int? accountId,
  ) {
    final items = accountId == null
        ? state.transactions
        : state.transactions
              .where((item) => includesTransaction(item, accountId))
              .toList();
    return [...items]..sort((a, b) => b.date.compareTo(a.date));
  }

  static List<FinanceTransaction> analyticTransactions(
    AppState state,
    int? accountId, {
    DateTime? from,
    DateTime? to,
  }) => state
      .analyticTransactions(from: from, to: to)
      .where(
        (item) =>
            accountId == null || includesTransaction(item, accountId),
      )
      .toList();

  static double periodTotal(
    AppState state,
    int? accountId,
    TransactionType type,
    DateTime from,
    DateTime to,
  ) {
    if (accountId == null) return state.periodTotal(type, from, to);
    var total = 0.0;
    for (final item in state.analyticTransactions(from: from, to: to)) {
      if (item.accountId != accountId || item.type != type) continue;
      if (type == TransactionType.income &&
          item.refundOfTransactionId != null) {
        continue;
      }
      total += type == TransactionType.expense
          ? state.effectiveExpense(item)
          : item.amount;
    }
    return total;
  }

  static double monthTotal(
    AppState state,
    int? accountId,
    TransactionType type, {
    DateTime? month,
  }) {
    final target = month ?? DateTime.now();
    return periodTotal(
      state,
      accountId,
      type,
      DateTime(target.year, target.month),
      DateTime(target.year, target.month + 1),
    );
  }

  static double balance(AppState state, int? accountId) => accountId == null
      ? state.totalBalance
      : state.accountById(accountId)?.balance ?? state.totalBalance;

  static double available(AppState state, int? accountId) {
    if (accountId == null) return state.safeToSpend;
    final account = state.accountById(accountId);
    if (account == null) return state.safeToSpend;

    final now = DateTime.now();
    final end = DateTime(now.year, now.month + 1);
    var projected = account.balance;
    for (final item in state.recurring.where(
      (item) =>
          item.enabled &&
          !item.nextDate.isBefore(now) &&
          item.nextDate.isBefore(end),
    )) {
      if (item.type == TransactionType.expense && item.accountId == accountId) {
        projected -= item.amount;
      } else if (item.type == TransactionType.income &&
          item.accountId == accountId) {
        projected += item.amount;
      } else if (item.type == TransactionType.transfer) {
        if (item.accountId == accountId) projected -= item.amount;
        if (item.toAccountId == accountId) projected += item.amount;
      }
    }
    return math.max(0, math.min(account.balance, projected)).toDouble();
  }

  static List<RecurringPayment> recurring(AppState state, int? accountId) {
    final items = state.recurring
        .where(
          (item) =>
              item.enabled &&
              (accountId == null ||
                  item.accountId == accountId ||
                  item.toAccountId == accountId),
        )
        .toList();
    items.sort((a, b) => a.nextDate.compareTo(b.nextDate));
    return items;
  }

  static String scopeLabel(AppState state, int? accountId) =>
      state.accountById(accountId)?.name ?? 'Totale';
}

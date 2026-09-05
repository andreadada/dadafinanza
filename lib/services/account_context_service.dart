import '../app_state.dart';
import '../models/models.dart';

class AccountCategoryGroup {
  const AccountCategoryGroup({
    required this.type,
    required this.categoryId,
    required this.title,
    required this.total,
    required this.count,
    required this.percentage,
    required this.transactionIds,
  });

  final TransactionType type;
  final int? categoryId;
  final String title;
  final double total;
  final int count;
  final double percentage;
  final Set<int> transactionIds;
}

class AccountContextService {
  const AccountContextService._();

  static bool matchesAccount(FinanceTransaction item, int? accountId) {
    if (accountId == null) return true;
    return item.accountId == accountId || item.toAccountId == accountId;
  }

  static List<FinanceTransaction> transactionsFor(
    AppState state,
    int? accountId,
  ) => state.transactions
      .where((item) => matchesAccount(item, accountId))
      .toList(growable: false);

  static List<FinanceTransaction> analyticTransactionsFor(
    AppState state,
    int? accountId, {
    DateTime? from,
    DateTime? to,
  }) => state
      .analyticTransactions(from: from, to: to)
      .where((item) => matchesAccount(item, accountId))
      .toList(growable: false);

  static double balanceFor(AppState state, int? accountId) => accountId == null
      ? state.totalBalance
      : (state.accountById(accountId)?.balance ?? 0);

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
      if (type == TransactionType.income && item.refundOfTransactionId != null) {
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
    final from = DateTime(target.year, target.month);
    final to = DateTime(target.year, target.month + 1);
    return periodTotal(state, accountId, type, from, to);
  }

  static List<RecurringPayment> recurringFor(AppState state, int? accountId) {
    final items = state.recurring.where((item) {
      if (!item.enabled) return false;
      if (accountId == null) return true;
      return item.accountId == accountId || item.toAccountId == accountId;
    }).toList();
    items.sort((a, b) => a.nextDate.compareTo(b.nextDate));
    return items;
  }

  static List<AccountCategoryGroup> groupByCategory(
    AppState state,
    List<FinanceTransaction> items,
  ) {
    final totals = <String, double>{};
    final ids = <String, Set<int>>{};
    final metadata = <String, (TransactionType, int?, String)>{};

    void add(
      FinanceTransaction item,
      int? categoryId,
      String title,
      double amount,
    ) {
      final key = '${item.type.name}:${categoryId ?? -1}:$title';
      totals[key] = (totals[key] ?? 0) + amount;
      ids.putIfAbsent(key, () => <int>{}).add(item.id);
      metadata[key] = (item.type, categoryId, title);
    }

    for (final item in items) {
      if (item.type == TransactionType.transfer) {
        add(item, null, 'Trasferimenti', item.amount);
        continue;
      }
      final splits = state.splitsFor(item.id);
      if (splits.isNotEmpty) {
        for (final split in splits) {
          final category = state.categoryById(split.categoryId);
          add(
            item,
            split.categoryId,
            category?.name ?? 'Senza categoria',
            split.amount,
          );
        }
      } else {
        final category = state.categoryById(item.categoryId);
        add(
          item,
          item.categoryId,
          category?.name ?? 'Senza categoria',
          item.amount,
        );
      }
    }

    final denominators = <TransactionType, double>{};
    for (final entry in totals.entries) {
      final type = metadata[entry.key]!.$1;
      denominators[type] = (denominators[type] ?? 0) + entry.value;
    }

    final groups = totals.entries.map((entry) {
      final data = metadata[entry.key]!;
      final denominator = denominators[data.$1] ?? 0;
      return AccountCategoryGroup(
        type: data.$1,
        categoryId: data.$2,
        title: data.$3,
        total: entry.value,
        count: ids[entry.key]!.length,
        percentage: denominator <= 0 ? 0 : entry.value / denominator * 100,
        transactionIds: Set<int>.unmodifiable(ids[entry.key]!),
      );
    }).toList();

    groups.sort((a, b) {
      final byType = a.type.index.compareTo(b.type.index);
      if (byType != 0) return byType;
      return b.total.compareTo(a.total);
    });
    return groups;
  }
}

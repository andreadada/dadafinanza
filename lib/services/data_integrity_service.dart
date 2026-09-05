import '../app_state.dart';
import '../core/money.dart';
import '../models/models.dart';

class ReconciliationResult {
  const ReconciliationResult({
    required this.previousBalance,
    required this.actualBalance,
    required this.difference,
    this.transactionId,
  });

  final double previousBalance;
  final double actualBalance;
  final double difference;
  final int? transactionId;
}

class DataIntegrityService {
  const DataIntegrityService._();

  static Future<ReconciliationResult> reconcileAccount(
    AppState state, {
    required Account account,
    required double actualBalance,
    DateTime? at,
  }) async {
    if (account.isSystem || account.isArchived || account.isLocked) {
      throw StateError('Il conto non può essere riconciliato in questo stato.');
    }
    final expectedCents = Money.toCents(account.balance);
    final actualCents = Money.toCents(actualBalance);
    final delta = actualCents - expectedCents;
    final when = at ?? DateTime.now();
    if (delta == 0) {
      await state.database.db.update(
        'accounts',
        {'last_reconciled_at': when.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [account.id],
      );
      await state.refreshCore();
      return ReconciliationResult(
        previousBalance: account.balance,
        actualBalance: Money.fromCents(actualCents),
        difference: 0,
      );
    }

    final transactionType =
        delta > 0 ? TransactionType.income : TransactionType.expense;
    final amountCents = delta.abs();
    final now = DateTime.now().millisecondsSinceEpoch;
    late int transactionId;
    await state.database.db.transaction((txn) async {
      transactionId = await txn.insert('transactions', {
        'type': transactionType.dbValue,
        'amount': Money.fromCents(amountCents),
        'amount_cents': amountCents,
        'account_id': account.id,
        'to_account_id': null,
        'category_id': null,
        'date': when.millisecondsSinceEpoch,
        'note': 'Riconciliazione saldo',
        'tags': 'riconciliazione',
        'receipt_path': null,
        'include_in_analytics': 0,
        'recurring_id': null,
        'refund_of_transaction_id': null,
        'kind': 'reconciliation',
        'created_at': now,
        'updated_at': now,
      });
      await txn.update(
        'accounts',
        {
          'balance': Money.fromCents(actualCents),
          'balance_cents': actualCents,
          'last_reconciled_at': when.millisecondsSinceEpoch,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [account.id],
      );
    });
    await state.refreshCore(includePlanning: true);
    return ReconciliationResult(
      previousBalance: Money.fromCents(expectedCents),
      actualBalance: Money.fromCents(actualCents),
      difference: Money.fromCents(delta),
      transactionId: transactionId,
    );
  }

  static double refundableRemaining(
    AppState state,
    FinanceTransaction expense, {
    int? editingRefundId,
  }) {
    if (expense.type != TransactionType.expense) return 0;
    final refundedCents = state.transactions
        .where(
          (item) =>
              item.id != editingRefundId &&
              item.type == TransactionType.income &&
              item.refundOfTransactionId == expense.id,
        )
        .fold<int>(0, (sum, item) => sum + Money.toCents(item.amount));
    final remaining =
        (Money.toCents(expense.amount) - refundedCents).clamp(0, 1 << 62);
    return Money.fromCents(remaining.toInt());
  }

  static void validateRefund(
    AppState state, {
    required FinanceTransaction expense,
    required double refundAmount,
    int? editingRefundId,
  }) {
    if (expense.type != TransactionType.expense) {
      throw StateError('Solo una spesa può ricevere un rimborso.');
    }
    final requested = Money.toCents(refundAmount);
    final remaining = Money.toCents(
      refundableRemaining(
        state,
        expense,
        editingRefundId: editingRefundId,
      ),
    );
    if (requested <= 0) {
      throw StateError('Il rimborso deve essere maggiore di zero.');
    }
    if (requested > remaining) {
      throw StateError(
        'Il rimborso supera il residuo di ${Money.fromCents(remaining).toStringAsFixed(2)} €.',
      );
    }
  }

  static Future<void> validateSplits(
    AppState state, {
    required FinanceTransaction transaction,
    required List<TransactionSplit> splits,
  }) async {
    if (splits.isEmpty) return;
    if (transaction.type != TransactionType.expense) {
      throw StateError('La divisione in categorie è disponibile per le spese.');
    }
    final total = splits.fold<int>(
      0,
      (sum, split) => sum + Money.toCents(split.amount),
    );
    if (total != Money.toCents(transaction.amount)) {
      throw StateError('La somma delle divisioni deve coincidere con il totale.');
    }
    for (final split in splits) {
      final category = state.categoryById(split.categoryId);
      if (category == null || category.type != TransactionType.expense) {
        throw StateError('Ogni parte richiede una categoria di spesa valida.');
      }
      if (Money.toCents(split.amount) <= 0) {
        throw StateError('Ogni parte deve avere un importo maggiore di zero.');
      }
    }
  }

  static Future<void> archiveAccount(AppState state, Account account) async {
    if (account.isSystem) return;
    await state.updateAccount(account.copyWith(isArchived: true));
  }

  static Future<void> deleteEmptyAccount(AppState state, Account account) async {
    if (account.isSystem) {
      throw StateError('Il conto di sistema non è eliminabile.');
    }
    final linked = state.transactionCountForAccount(account.id);
    final recurring = state.recurring
        .where(
          (item) =>
              item.accountId == account.id || item.toAccountId == account.id,
        )
        .length;
    if (linked > 0 || recurring > 0) {
      throw StateError(
        'Questo conto contiene storico. Archivialo invece di eliminarlo.',
      );
    }
    await state.database.db.transaction((txn) async {
      await txn.update(
        'goals',
        {'linked_account_id': null},
        where: 'linked_account_id = ?',
        whereArgs: [account.id],
      );
      await txn.delete('accounts', where: 'id = ?', whereArgs: [account.id]);
    });
    await state.refreshCore(includePlanning: true);
  }

  static Future<void> mergeCategories(
    AppState state, {
    required Category source,
    required Category destination,
  }) async {
    if (source.id == destination.id) return;
    if (source.type != destination.type) {
      throw StateError('Puoi unire solo categorie dello stesso tipo.');
    }
    final db = state.database.db;
    await db.transaction((txn) async {
      for (final table in [
        'transactions',
        'transaction_splits',
        'recurring',
        'budgets',
        'automation_rules',
        'learned_patterns',
        'detected_recurring_patterns',
      ]) {
        await txn.update(
          table,
          {'category_id': destination.id},
          where: 'category_id = ?',
          whereArgs: [source.id],
        );
      }
      await txn.delete('categories', where: 'id = ?', whereArgs: [source.id]);
    });
    await state.refreshCore(includePlanning: true);
  }

  static Future<void> setCategoryFavorite(
    AppState state,
    Category category,
    bool favorite,
  ) async {
    await state.database.db.update(
      'categories',
      {'is_favorite': favorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [category.id],
    );
    await state.refreshCore(includePlanning: true);
  }

  static Future<void> setQuickSlots(
    AppState state,
    List<Category> ordered,
  ) async {
    await state.database.db.transaction((txn) async {
      await txn.update('categories', {'quick_order': null});
      for (var index = 0; index < ordered.length; index++) {
        await txn.update(
          'categories',
          {'quick_order': index},
          where: 'id = ?',
          whereArgs: [ordered[index].id],
        );
      }
    });
    await state.refreshCore(includePlanning: true);
  }
}

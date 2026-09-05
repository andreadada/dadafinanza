import '../core/money.dart';
import '../data/app_database.dart';
import '../models/models.dart';

class RecurringExecutionService {
  const RecurringExecutionService();

  Future<int> processDue(AppDatabase database, {DateTime? now}) async {
    final target = now ?? DateTime.now();
    final rows = await database.db.query(
      'recurring',
      where: 'enabled = 1 AND auto_create = 1 AND next_date <= ?',
      whereArgs: [target.millisecondsSinceEpoch],
      orderBy: 'next_date ASC, id ASC',
    );
    var created = 0;
    for (final row in rows) {
      final item = RecurringPayment.fromMap(row);
      final source = await database.db.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [item.accountId],
        limit: 1,
      );
      if (source.isEmpty ||
          (source.first['is_locked'] as int? ?? 0) == 1 ||
          (source.first['is_archived'] as int? ?? 0) == 1 ||
          (source.first['is_system'] as int? ?? 0) == 1) {
        continue;
      }
      if (item.type == TransactionType.transfer) {
        if (item.toAccountId == null || item.toAccountId == item.accountId) {
          continue;
        }
        final destination = await database.db.query(
          'accounts',
          where: 'id = ?',
          whereArgs: [item.toAccountId],
          limit: 1,
        );
        if (destination.isEmpty ||
            (destination.first['is_locked'] as int? ?? 0) == 1 ||
            (destination.first['is_archived'] as int? ?? 0) == 1 ||
            (destination.first['is_system'] as int? ?? 0) == 1) {
          continue;
        }
      }

      var next = item.nextDate;
      var guard = 0;
      while (!next.isAfter(target) && guard < 48) {
        if (item.endDate != null && next.isAfter(item.endDate!)) break;
        await _create(database, item, next);
        created++;
        next = advance(next, item.frequency);
        guard++;
      }
      await database.db.update(
        'recurring',
        {'next_date': next.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [item.id],
      );
    }
    return created;
  }

  Future<void> _create(
    AppDatabase database,
    RecurringPayment item,
    DateTime date,
  ) async {
    final cents = Money.toCents(item.amount);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await database.db.transaction((txn) async {
      await txn.insert('transactions', {
        'type': item.type.dbValue,
        'amount': Money.fromCents(cents),
        'amount_cents': cents,
        'account_id': item.accountId,
        'to_account_id': item.type == TransactionType.transfer
            ? item.toAccountId
            : null,
        'category_id': item.type == TransactionType.transfer
            ? null
            : item.categoryId,
        'date': date.millisecondsSinceEpoch,
        'note': item.note ?? item.name,
        'tags': '',
        'receipt_path': null,
        'include_in_analytics': item.type == TransactionType.transfer ? 0 : 1,
        'recurring_id': item.id,
        'refund_of_transaction_id': null,
        'kind': 'normal',
        'created_at': timestamp,
        'updated_at': timestamp,
      });
      await _increment(txn, item.accountId, switch (item.type) {
        TransactionType.expense => -cents,
        TransactionType.income => cents,
        TransactionType.transfer => -cents,
      });
      if (item.type == TransactionType.transfer) {
        await _increment(txn, item.toAccountId!, cents);
      }
    });
  }

  Future<void> _increment(dynamic txn, int accountId, int deltaCents) async {
    await txn.rawUpdate(
      'UPDATE accounts SET balance_cents = COALESCE(balance_cents, CAST(ROUND(balance * 100) AS INTEGER)) + ?, balance = (COALESCE(balance_cents, CAST(ROUND(balance * 100) AS INTEGER)) + ?) / 100.0, updated_at = ? WHERE id = ?',
      [
        deltaCents,
        deltaCents,
        DateTime.now().millisecondsSinceEpoch,
        accountId,
      ],
    );
  }

  static DateTime advance(DateTime date, String frequency) =>
      switch (frequency) {
        'Settimanale' => date.add(const Duration(days: 7)),
        'Quindicinale' => date.add(const Duration(days: 14)),
        'Trimestrale' => DateTime(
          date.year,
          date.month + 3,
          date.day,
          date.hour,
          date.minute,
        ),
        'Annuale' => DateTime(
          date.year + 1,
          date.month,
          date.day,
          date.hour,
          date.minute,
        ),
        _ => DateTime(
          date.year,
          date.month + 1,
          date.day,
          date.hour,
          date.minute,
        ),
      };
}

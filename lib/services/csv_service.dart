import '../app_state.dart';
import '../core/money.dart';
import '../models/models.dart';
import '../services/smart_finance_engine.dart';

class CsvRowPreview {
  const CsvRowPreview({
    required this.type,
    required this.amount,
    required this.date,
    required this.account,
    required this.destination,
    required this.category,
    required this.note,
    required this.tags,
    required this.includeInAnalytics,
    required this.duplicate,
  });

  final TransactionType type;
  final double amount;
  final DateTime date;
  final String account;
  final String? destination;
  final String? category;
  final String? note;
  final List<String> tags;
  final bool includeInAnalytics;
  final bool duplicate;
}

class CsvImportPreview {
  const CsvImportPreview({
    required this.rows,
    required this.invalidRows,
    required this.missingAccounts,
    required this.missingCategories,
  });

  final List<CsvRowPreview> rows;
  final int invalidRows;
  final Set<String> missingAccounts;
  final Set<String> missingCategories;

  int get duplicates => rows.where((row) => row.duplicate).length;
  int get importable => rows.where((row) => !row.duplicate).length;
}

enum CsvMissingAction { create, unassigned, ignore }

class CsvImportPlan {
  const CsvImportPlan({
    this.accountActions = const {},
    this.categoryActions = const {},
    this.skipDuplicates = true,
  });

  final Map<String, CsvMissingAction> accountActions;
  final Map<String, CsvMissingAction> categoryActions;
  final bool skipDuplicates;
}

class CsvService {
  const CsvService();

  String export(AppState state, {int? accountId}) {
    final buffer = StringBuffer();
    buffer.writeln(
      'type,amount,date,account,to_account,category,description,tags,include_in_analytics,stable_key',
    );
    final transactions = accountId == null
        ? state.transactions
        : state.transactions
              .where(
                (item) =>
                    item.accountId == accountId ||
                    item.toAccountId == accountId,
              )
              .toList();
    for (final item in transactions) {
      final account = state.accountById(item.accountId);
      final destination = state.accountById(item.toAccountId);
      final category = state.categoryById(item.categoryId);
      buffer.writeln(
        [
          item.type.dbValue,
          (Money.toCents(item.amount) / 100).toStringAsFixed(2),
          item.date.toUtc().toIso8601String(),
          _quote(account?.isSystem == true ? 'Non assegnato' : account?.name),
          _quote(destination?.name),
          _quote(category?.name),
          _quote(item.note),
          _quote(item.tags.join('|')),
          item.includeInAnalytics ? '1' : '0',
          _quote(_stableKey(state, item)),
        ].join(','),
      );
    }
    return buffer.toString();
  }

  CsvImportPreview preview(AppState state, String content) {
    final records = _records(content);
    if (records.isEmpty) {
      return const CsvImportPreview(
        rows: [],
        invalidRows: 0,
        missingAccounts: {},
        missingCategories: {},
      );
    }
    final header = records.first
        .map((item) => item.trim().toLowerCase())
        .toList(growable: false);
    final indexes = <String, int>{
      for (var i = 0; i < header.length; i++) header[i]: i,
    };
    final required = ['type', 'amount', 'date', 'account'];
    if (required.any((key) => !indexes.containsKey(key))) {
      throw const FormatException(
        'Il CSV deve contenere almeno type, amount, date e account.',
      );
    }

    final accountNames = <String>{
      for (final account in state.userAccounts) _key(account.name),
    };
    final categoryNames = <String>{
      for (final category in state.categories) _key(category.name),
    };
    final existing = state.transactions
        .map((item) => _stableKey(state, item))
        .toSet();
    final rows = <CsvRowPreview>[];
    final missingAccounts = <String>{};
    final missingCategories = <String>{};
    var invalid = 0;
    for (final record in records.skip(1)) {
      try {
        String value(String key) {
          final index = indexes[key];
          return index == null || index >= record.length
              ? ''
              : record[index].trim();
        }

        final typeRaw = value('type').toLowerCase();
        if (!TransactionType.values.any((item) => item.name == typeRaw)) {
          invalid++;
          continue;
        }
        final type = TransactionTypeX.fromDb(typeRaw);
        final parsedAmount = double.tryParse(
          value('amount').replaceAll(',', '.'),
        );
        final date = DateTime.tryParse(value('date'));
        final account = value('account');
        if (parsedAmount == null ||
            parsedAmount <= 0 ||
            date == null ||
            account.isEmpty) {
          invalid++;
          continue;
        }
        final destination = value('to_account').isEmpty
            ? null
            : value('to_account');
        final category = value('category').isEmpty ? null : value('category');
        final note = value('description').isEmpty ? null : value('description');
        final tags = value('tags')
            .split('|')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
        final include = value('include_in_analytics') != '0';
        if (_key(account) != _key('Non assegnato') &&
            !accountNames.contains(_key(account))) {
          missingAccounts.add(account);
        }
        if (destination != null && !accountNames.contains(_key(destination))) {
          missingAccounts.add(destination);
        }
        if (category != null && !categoryNames.contains(_key(category))) {
          missingCategories.add(category);
        }
        final sourceKey = value('stable_key');
        final fallbackKey = _portableKey(
          type: type,
          amount: parsedAmount,
          date: date,
          account: account,
          destination: destination,
          note: note,
        );
        rows.add(
          CsvRowPreview(
            type: type,
            amount: Money.fromCents(Money.toCents(parsedAmount)),
            date: date,
            account: account,
            destination: destination,
            category: category,
            note: note,
            tags: tags,
            includeInAnalytics: include,
            duplicate:
                existing.contains(sourceKey) || existing.contains(fallbackKey),
          ),
        );
      } on FormatException {
        invalid++;
      }
    }
    return CsvImportPreview(
      rows: rows,
      invalidRows: invalid,
      missingAccounts: missingAccounts,
      missingCategories: missingCategories,
    );
  }

  Future<int> import(
    AppState state,
    CsvImportPreview preview,
    CsvImportPlan plan,
  ) async {
    final db = state.database.db;
    var imported = 0;
    await db.transaction((txn) async {
      final accounts = <String, int>{
        for (final account in state.userAccounts)
          _key(account.name): account.id,
      };
      final categories = <String, int>{
        for (final category in state.categories)
          _key(category.name): category.id,
      };
      final unassigned =
          state.unassignedAccount?.id ??
          (await txn.query(
                'accounts',
                columns: ['id'],
                where: 'is_system = 1',
                limit: 1,
              )).first['id']
              as int;

      Future<int?> resolveAccount(String name) async {
        if (_key(name) == _key('Non assegnato')) return unassigned;
        final existing = accounts[_key(name)];
        if (existing != null) return existing;
        final action = plan.accountActions[name] ?? CsvMissingAction.unassigned;
        if (action == CsvMissingAction.ignore) return null;
        if (action == CsvMissingAction.unassigned) return unassigned;
        final now = DateTime.now().millisecondsSinceEpoch;
        final id = await txn.insert('accounts', {
          'name': name,
          'balance': 0.0,
          'balance_cents': 0,
          'opening_balance': 0.0,
          'opening_balance_cents': 0,
          'color': 0xFF8E8E93,
          'icon_key': 'wallet',
          'account_type': AccountType.other.name,
          'include_in_total': 1,
          'include_in_analytics': 1,
          'is_locked': 0,
          'is_archived': 0,
          'hide_balance': 0,
          'is_system': 0,
          'created_at': now,
          'updated_at': now,
        });
        accounts[_key(name)] = id;
        return id;
      }

      Future<int?> resolveCategory(String? name, TransactionType type) async {
        if (name == null || type == TransactionType.transfer) return null;
        final existing = categories[_key(name)];
        if (existing != null) return existing;
        final action = plan.categoryActions[name] ?? CsvMissingAction.ignore;
        if (action != CsvMissingAction.create) return null;
        final id = await txn.insert('categories', {
          'name': name,
          'type': type.dbValue,
          'icon_key': 'category',
          'color': 0xFF8E8E93,
          'quick_order': null,
          'is_favorite': 0,
        });
        categories[_key(name)] = id;
        return id;
      }

      for (final row in preview.rows) {
        if (plan.skipDuplicates && row.duplicate) continue;
        final source = await resolveAccount(row.account);
        if (source == null) continue;
        final destination = row.destination == null
            ? null
            : await resolveAccount(row.destination!);
        if (row.type == TransactionType.transfer &&
            (destination == null || destination == source)) {
          continue;
        }
        final category = await resolveCategory(row.category, row.type);
        final cents = Money.toCents(row.amount);
        final now = DateTime.now().millisecondsSinceEpoch;
        final id = await txn.insert('transactions', {
          'type': row.type.dbValue,
          'amount': Money.fromCents(cents),
          'amount_cents': cents,
          'account_id': source,
          'to_account_id': row.type == TransactionType.transfer
              ? destination
              : null,
          'category_id': row.type == TransactionType.transfer ? null : category,
          'date': row.date.millisecondsSinceEpoch,
          'note': row.note,
          'tags': row.tags.join('|'),
          'receipt_path': null,
          'include_in_analytics': row.includeInAnalytics ? 1 : 0,
          'recurring_id': null,
          'refund_of_transaction_id': null,
          'kind': 'normal',
          'created_at': now,
          'updated_at': now,
        });
        if (id <= 0) continue;
        switch (row.type) {
          case TransactionType.expense:
            await _increment(txn, source, -cents);
          case TransactionType.income:
            await _increment(txn, source, cents);
          case TransactionType.transfer:
            await _increment(txn, source, -cents);
            await _increment(txn, destination!, cents);
        }
        imported++;
      }
    });
    await state.refreshCore(includePlanning: true);
    return imported;
  }

  Future<void> _increment(dynamic txn, int id, int cents) async {
    await txn.rawUpdate(
      'UPDATE accounts SET balance_cents = COALESCE(balance_cents, CAST(ROUND(balance * 100) AS INTEGER)) + ?, balance = (COALESCE(balance_cents, CAST(ROUND(balance * 100) AS INTEGER)) + ?) / 100.0, updated_at = ? WHERE id = ?',
      [cents, cents, DateTime.now().millisecondsSinceEpoch, id],
    );
  }

  String _stableKey(AppState state, FinanceTransaction item) => _portableKey(
    type: item.type,
    amount: item.amount,
    date: item.date,
    account: state.accountById(item.accountId)?.name ?? 'Non assegnato',
    destination: state.accountById(item.toAccountId)?.name,
    note: item.note,
  );

  String _portableKey({
    required TransactionType type,
    required double amount,
    required DateTime date,
    required String account,
    String? destination,
    String? note,
  }) => [
    type.name,
    Money.toCents(amount),
    date.toUtc().toIso8601String(),
    _key(account),
    _key(destination ?? ''),
    SmartFinanceEngine.normalizeText(note),
  ].join('|');

  String _quote(String? value) =>
      '"${(value ?? '').replaceAll('"', '""').replaceAll('\r', ' ').replaceAll('\n', ' ')}"';

  String _key(String value) => value.trim().toLowerCase();

  List<List<String>> _records(String content) {
    final records = <List<String>>[];
    final row = <String>[];
    final field = StringBuffer();
    var quoted = false;
    for (var index = 0; index < content.length; index++) {
      final char = content[index];
      if (char == '"') {
        if (quoted && index + 1 < content.length && content[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          quoted = !quoted;
        }
        continue;
      }
      if (char == ',' && !quoted) {
        row.add(field.toString());
        field.clear();
        continue;
      }
      if ((char == '\n' || char == '\r') && !quoted) {
        if (char == '\r' &&
            index + 1 < content.length &&
            content[index + 1] == '\n') {
          index++;
        }
        row.add(field.toString());
        field.clear();
        if (row.any((item) => item.trim().isNotEmpty)) {
          records.add(List<String>.from(row));
        }
        row.clear();
        continue;
      }
      field.write(char);
    }
    if (quoted) throw const FormatException('Virgolette CSV non bilanciate.');
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      if (row.any((item) => item.trim().isNotEmpty)) records.add(row);
    }
    return records;
  }
}

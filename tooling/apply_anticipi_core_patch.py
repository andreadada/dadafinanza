from pathlib import Path


def read(path):
    return Path(path).read_text()


def write(path, content):
    Path(path).write_text(content)


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)


# Finance schema ----------------------------------------------------------------
p = 'lib/services/finance_schema_service.dart'
s = read(p)
s = replace_once(
    s,
    '      await _ensureGoalLedger(txn);\n      await _ensurePresets(txn);\n      await _ensureCompatibilityTriggers(txn);',
    '      await _ensureGoalLedger(txn);\n      await _ensurePresets(txn);\n      await _ensureAdvances(txn);\n      await _ensureCompatibilityTriggers(txn);',
    'schema ensure hook',
)
marker = '  Future<void> _ensureCompatibilityTriggers(Transaction txn) async {'
advance_schema = r'''  Future<void> _ensureAdvances(Transaction txn) async {
    await txn.execute('''CREATE TABLE IF NOT EXISTS finance_people(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL COLLATE NOCASE,
      color INTEGER NOT NULL DEFAULT 4287532691,
      icon_key TEXT NOT NULL DEFAULT 'person',
      archived INTEGER NOT NULL DEFAULT 0 CHECK(archived IN (0,1)),
      note TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )''');
    await txn.execute('''CREATE TABLE IF NOT EXISTS advances(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      direction TEXT NOT NULL CHECK(direction IN ('receivable','payable')),
      person_id INTEGER NOT NULL,
      original_amount_cents INTEGER NOT NULL CHECK(original_amount_cents > 0),
      source_account_id INTEGER,
      source_transaction_id INTEGER,
      due_date INTEGER,
      reminder_date INTEGER,
      note TEXT,
      closed_kind TEXT CHECK(closed_kind IS NULL OR closed_kind IN ('cancelled','writtenOff','forgiven')),
      closed_at INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY(person_id) REFERENCES finance_people(id) ON DELETE RESTRICT,
      FOREIGN KEY(source_account_id) REFERENCES accounts(id) ON DELETE SET NULL,
      FOREIGN KEY(source_transaction_id) REFERENCES transactions(id) ON DELETE RESTRICT
    )''');
    await txn.execute('''CREATE TABLE IF NOT EXISTS advance_settlements(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      advance_id INTEGER NOT NULL,
      amount_cents INTEGER NOT NULL CHECK(amount_cents > 0),
      transaction_id INTEGER NOT NULL UNIQUE,
      account_id INTEGER NOT NULL,
      date INTEGER NOT NULL,
      note TEXT,
      created_at INTEGER NOT NULL,
      FOREIGN KEY(advance_id) REFERENCES advances(id) ON DELETE CASCADE,
      FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
      FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT
    )''');

    await txn.insert(
      'settings',
      {'key': 'notifications_advances', 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await txn.insert(
      'settings',
      {'key': 'advances_default_reminder_days', 'value': '7'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    for (final name in const [
      'advance_settlement_validate_insert',
      'advance_settlement_validate_update',
      'advance_settlement_sync_transaction',
    ]) {
      await txn.execute('DROP TRIGGER IF EXISTS $name');
    }
    await txn.execute('''CREATE TRIGGER advance_settlement_validate_insert
      BEFORE INSERT ON advance_settlements
      BEGIN
        SELECT CASE
          WHEN NEW.amount_cents <= 0 THEN RAISE(ABORT, 'advance settlement must be positive')
          WHEN NOT EXISTS(SELECT 1 FROM advances WHERE id = NEW.advance_id AND closed_kind IS NULL)
            THEN RAISE(ABORT, 'advance is closed or missing')
          WHEN NEW.amount_cents + COALESCE((SELECT SUM(amount_cents) FROM advance_settlements WHERE advance_id = NEW.advance_id), 0)
               > (SELECT original_amount_cents FROM advances WHERE id = NEW.advance_id)
            THEN RAISE(ABORT, 'advance settlement exceeds remaining amount')
        END;
      END''');
    await txn.execute('''CREATE TRIGGER advance_settlement_validate_update
      BEFORE UPDATE OF amount_cents, advance_id ON advance_settlements
      BEGIN
        SELECT CASE
          WHEN NEW.amount_cents <= 0 THEN RAISE(ABORT, 'advance settlement must be positive')
          WHEN NOT EXISTS(SELECT 1 FROM advances WHERE id = NEW.advance_id AND closed_kind IS NULL)
            THEN RAISE(ABORT, 'advance is closed or missing')
          WHEN NEW.amount_cents + COALESCE((SELECT SUM(amount_cents) FROM advance_settlements WHERE advance_id = NEW.advance_id AND id <> OLD.id), 0)
               > (SELECT original_amount_cents FROM advances WHERE id = NEW.advance_id)
            THEN RAISE(ABORT, 'advance settlement exceeds remaining amount')
        END;
      END''');
    await txn.execute('''CREATE TRIGGER advance_settlement_sync_transaction
      AFTER UPDATE OF amount, account_id, date, note ON transactions
      WHEN NEW.kind = 'advance_settlement' AND EXISTS(SELECT 1 FROM advance_settlements WHERE transaction_id = NEW.id)
      BEGIN
        UPDATE advance_settlements SET
          amount_cents = CAST(ROUND(NEW.amount * 100) AS INTEGER),
          account_id = NEW.account_id,
          date = NEW.date,
          note = NEW.note
        WHERE transaction_id = NEW.id;
      END''');
  }

'''
s = replace_once(s, marker, advance_schema + marker, 'schema method insertion')
s = replace_once(
    s,
    "    await txn.execute(\n      'CREATE INDEX IF NOT EXISTS idx_presets_position ON quick_presets(enabled, position)',\n    );\n  }",
    "    await txn.execute(\n      'CREATE INDEX IF NOT EXISTS idx_presets_position ON quick_presets(enabled, position)',\n    );\n    await txn.execute(\n      'CREATE INDEX IF NOT EXISTS idx_advances_person ON advances(person_id, closed_at)',\n    );\n    await txn.execute(\n      'CREATE INDEX IF NOT EXISTS idx_advances_source_transaction ON advances(source_transaction_id)',\n    );\n    await txn.execute(\n      'CREATE INDEX IF NOT EXISTS idx_advances_due ON advances(due_date, reminder_date)',\n    );\n    await txn.execute(\n      'CREATE INDEX IF NOT EXISTS idx_advance_settlements_advance ON advance_settlements(advance_id, date)',\n    );\n  }",
    'advance indexes',
)
write(p, s)


# AppDatabase -------------------------------------------------------------------
p = 'lib/data/app_database.dart'
s = read(p)
s = replace_once(
    s,
    "    'refund_of_transaction_id': item.refundOfTransactionId,\n    'created_at': preserveCreatedAt",
    "    'refund_of_transaction_id': item.refundOfTransactionId,\n    'kind': item.kind,\n    'created_at': preserveCreatedAt",
    'persist transaction kind',
)
s = replace_once(
    s,
    '  Future<void> _applyBalance(\n    Transaction txn,\n    FinanceTransaction item,\n    int direction, {\n    bool validateAccounts = true,\n  }) async {\n    if (validateAccounts) await _validateAccount(txn, item.accountId);',
    "  Future<void> _applyBalance(\n    Transaction txn,\n    FinanceTransaction item,\n    int direction, {\n    bool validateAccounts = true,\n  }) async {\n    if (item.kind == 'advance_writeoff' ||\n        item.kind == 'advance_forgiven_income') {\n      return;\n    }\n    if (validateAccounts) await _validateAccount(txn, item.accountId);",
    'analytics-only balance guard',
)
s = replace_once(
    s,
    "      final linkedRows = await txn.query(\n        'transactions',\n        where: 'account_id = ? OR to_account_id = ?',\n        whereArgs: [id, id],\n        orderBy: 'date DESC, id DESC',\n      );\n      for (final row in linkedRows) {",
    "      final linkedRows = await txn.query(\n        'transactions',\n        where: 'account_id = ? OR to_account_id = ?',\n        whereArgs: [id, id],\n        orderBy: 'date DESC, id DESC',\n      );\n      final hasAdvanceHistory = linkedRows.any((row) {\n        final kind = (row['kind'] as String?) ?? 'normal';\n        return kind == 'advance_origin' ||\n            kind == 'mixed_advance' ||\n            kind == 'advance_settlement' ||\n            kind == 'advance_writeoff' ||\n            kind == 'advance_forgiven_income';\n      });\n      if (hasAdvanceHistory) {\n        throw StateError(\n          'Questo conto contiene movimenti collegati ad Anticipi. Archivialo invece di eliminarlo per conservare lo storico.',\n        );\n      }\n      for (final row in linkedRows) {",
    'account delete safety',
)
write(p, s)


# AppState ----------------------------------------------------------------------
p = 'lib/app_state.dart'
s = read(p)
s = replace_once(
    s,
    "import 'data/app_database.dart';\nimport 'models/models.dart';",
    "import 'core/money.dart';\nimport 'data/app_database.dart';\nimport 'models/advance_models.dart';\nimport 'models/models.dart';",
    'state imports models',
)
s = replace_once(
    s,
    "import 'services/goal_ledger_service.dart';\nimport 'services/smart_finance_engine.dart';",
    "import 'services/advance_service.dart';\nimport 'services/goal_ledger_service.dart';\nimport 'services/smart_finance_engine.dart';",
    'state imports service',
)
s = replace_once(
    s,
    '  List<AutomationRule> rules = [];\n  List<LearnedPattern> learnedPatterns = [];',
    '  List<AutomationRule> rules = [];\n  List<FinancePerson> people = [];\n  List<Advance> advances = [];\n  List<AdvanceSettlement> advanceSettlements = [];\n  List<LearnedPattern> learnedPatterns = [];',
    'state advance fields',
)
s = replace_once(
    s,
    '    rules = await database.rules();\n    learnedPatterns = await database.learnedPatterns();',
    "    rules = await database.rules();\n    final advanceService = AdvanceService(database);\n    people = await advanceService.people(includeArchived: true);\n    advances = await advanceService.advances();\n    advanceSettlements = await advanceService.settlements();\n    learnedPatterns = await database.learnedPatterns();",
    'state reload advances',
)
old_analytic = '''  Iterable<FinanceTransaction> analyticTransactions({
    DateTime? from,
    DateTime? to,
  }) => transactions.where((t) {
    if (!t.includeInAnalytics) return false;
    final account = accountById(t.accountId);
    if (account != null && !account.isSystem && !account.includeInAnalytics)
      return false;
    if (t.type == TransactionType.transfer && !showTransfersInAnalytics)
      return false;
    if (from != null && t.date.isBefore(from)) return false;
    if (to != null && !t.date.isBefore(to)) return false;
    return true;
  });
'''
new_analytic = '''  Iterable<FinanceTransaction> analyticTransactions({
    DateTime? from,
    DateTime? to,
  }) sync* {
    for (final transaction in transactions) {
      if (!transaction.includeInAnalytics) continue;
      final account = accountById(transaction.accountId);
      if (account != null && !account.isSystem && !account.includeInAnalytics) {
        continue;
      }
      if (transaction.type == TransactionType.transfer &&
          !showTransfersInAnalytics) {
        continue;
      }
      if (from != null && transaction.date.isBefore(from)) continue;
      if (to != null && !transaction.date.isBefore(to)) continue;

      var projected = transaction;
      if (transaction.type == TransactionType.expense &&
          transaction.kind == 'mixed_advance') {
        final originalCents = Money.toCents(transaction.amount);
        final personalCents = math.max(
          0,
          originalCents - advanceAllocationCentsForTransaction(transaction.id),
        ).toInt();
        if (personalCents <= 0) continue;
        projected = transaction.copyWith(amount: Money.fromCents(personalCents));
      }
      yield projected;
    }
  }
'''
s = replace_once(s, old_analytic, new_analytic, 'analytics projection')
insert_after = '''  List<Category> categoriesFor(TransactionType type) =>
      categories.where((c) => c.type == type).toList(growable: false);
'''
advance_helpers = r'''

  FinancePerson? personById(int? id) =>
      id == null ? null : people.where((item) => item.id == id).firstOrNull;

  List<AdvanceSettlement> settlementsForAdvance(int advanceId) =>
      advanceSettlements
          .where((item) => item.advanceId == advanceId)
          .toList(growable: false);

  Advance? advanceForSourceTransaction(int transactionId) => advances
      .where((item) => item.sourceTransactionId == transactionId)
      .firstOrNull;

  AdvanceSettlement? settlementForTransaction(int transactionId) =>
      advanceSettlements
          .where((item) => item.transactionId == transactionId)
          .firstOrNull;

  Advance? advanceForSettlementTransaction(int transactionId) {
    final settlement = settlementForTransaction(transactionId);
    if (settlement == null) return null;
    return advances.where((item) => item.id == settlement.advanceId).firstOrNull;
  }

  int advanceRemainingCents(int advanceId) {
    final advance = advances.where((item) => item.id == advanceId).firstOrNull;
    if (advance == null) return 0;
    final settled = settlementsForAdvance(advanceId).fold<int>(
      0,
      (sum, item) => sum + item.amountCents,
    );
    return math.max(0, advance.originalAmountCents - settled).toInt();
  }

  AdvanceStatus advanceStatus(Advance advance, {DateTime? now}) {
    switch (advance.closedKind) {
      case AdvanceClosedKind.cancelled:
        return AdvanceStatus.cancelled;
      case AdvanceClosedKind.writtenOff:
        return AdvanceStatus.writtenOff;
      case AdvanceClosedKind.forgiven:
        return AdvanceStatus.forgiven;
      case null:
        break;
    }
    final remaining = advanceRemainingCents(advance.id);
    if (remaining <= 0) return AdvanceStatus.settled;
    final due = advance.dueDate;
    final target = now ?? DateTime.now();
    if (due != null &&
        DateTime(due.year, due.month, due.day).isBefore(
          DateTime(target.year, target.month, target.day),
        )) {
      return AdvanceStatus.overdue;
    }
    if (remaining < advance.originalAmountCents) return AdvanceStatus.partial;
    return AdvanceStatus.open;
  }

  int get advanceReceivableCents => advances
      .where(
        (item) =>
            item.direction == AdvanceDirection.receivable &&
            item.closedKind == null,
      )
      .fold<int>(0, (sum, item) => sum + advanceRemainingCents(item.id));

  int get advancePayableCents => advances
      .where(
        (item) =>
            item.direction == AdvanceDirection.payable && item.closedKind == null,
      )
      .fold<int>(0, (sum, item) => sum + advanceRemainingCents(item.id));

  int get advanceNetCents => advanceReceivableCents - advancePayableCents;

  int advanceAllocationCentsForTransaction(int transactionId) => advances
      .where(
        (item) =>
            item.sourceTransactionId == transactionId &&
            item.direction == AdvanceDirection.receivable &&
            item.closedKind != AdvanceClosedKind.cancelled,
      )
      .fold<int>(0, (sum, item) => sum + item.originalAmountCents);

  double analyticsAmountForSplit(
    int transactionId,
    TransactionSplit split,
  ) {
    final original = transactionById(transactionId);
    if (original == null || original.kind != 'mixed_advance') return split.amount;
    final totalCents = Money.toCents(original.amount);
    if (totalCents <= 0) return 0;
    final personalCents = math.max(
      0,
      totalCents - advanceAllocationCentsForTransaction(transactionId),
    ).toInt();
    final splitCents = Money.toCents(split.amount);
    return Money.fromCents((splitCents * personalCents / totalCents).round());
  }

  int advanceSettledInPeriodCents(DateTime from, DateTime to) =>
      advanceSettlements
          .where(
            (item) => !item.date.isBefore(from) && item.date.isBefore(to),
          )
          .fold<int>(0, (sum, item) => sum + item.amountCents);

  bool isAdvanceProtectedTransaction(FinanceTransaction item) =>
      item.kind == 'advance_origin' ||
      item.kind == 'mixed_advance' ||
      item.kind == 'advance_settlement' ||
      item.kind == 'advance_writeoff' ||
      item.kind == 'advance_forgiven_income';
'''
s = replace_once(s, insert_after, insert_after + advance_helpers, 'state advance helpers')
s = s.replace(
    ".fold(0.0, (sum, s) => sum + s.amount);",
    ".fold(0.0, (sum, s) => sum + analyticsAmountForSplit(t.id, s));",
    1,
)
# budget split is a second, differently named block
s = replace_once(
    s,
    ".fold(0.0, (sum, split) => sum + split.amount);",
    ".fold(0.0, (sum, split) =>\n                sum + analyticsAmountForSplit(transaction.id, split));",
    'budget mixed split analytics',
)
# protect generic mutators
s = replace_once(
    s,
    '''  Future<void> updateTransaction(
    FinanceTransaction oldItem,
    FinanceTransaction newItem,
  ) async {
    await database.updateTransaction(oldItem, newItem);''',
    '''  Future<void> updateTransaction(
    FinanceTransaction oldItem,
    FinanceTransaction newItem,
  ) async {
    if (isAdvanceProtectedTransaction(oldItem)) {
      throw StateError('Gestisci questo movimento dalla sezione Anticipi.');
    }
    await database.updateTransaction(oldItem, newItem);''',
    'protect update',
)
s = replace_once(
    s,
    '''  Future<void> duplicateTransaction(FinanceTransaction item) async {
    await database.duplicateTransaction(item);''',
    '''  Future<void> duplicateTransaction(FinanceTransaction item) async {
    if (isAdvanceProtectedTransaction(item)) {
      throw StateError('I movimenti Anticipi non possono essere duplicati direttamente.');
    }
    await database.duplicateTransaction(item);''',
    'protect duplicate',
)
s = replace_once(
    s,
    '''  Future<void> deleteTransaction(FinanceTransaction item) async {
    await database.deleteTransaction(item);''',
    '''  Future<void> deleteTransaction(FinanceTransaction item) async {
    if (isAdvanceProtectedTransaction(item)) {
      throw StateError('Gestisci questo movimento dalla sezione Anticipi.');
    }
    await database.deleteTransaction(item);''',
    'protect delete',
)
# add service API before recurring methods
api_marker = '  Future<void> addRecurring({\n'
advance_api = r'''  Future<int> createFinancePerson(String name) async {
    final id = await AdvanceService(database).createPerson(name);
    people = await AdvanceService(database).people(includeArchived: true);
    notifyListeners();
    return id;
  }

  Future<int> createPureAdvance({
    required AdvanceDirection direction,
    required int personId,
    required double amount,
    required int accountId,
    required DateTime date,
    DateTime? dueDate,
    DateTime? reminderDate,
    String? note,
  }) async {
    final id = await AdvanceService(database).createPureAdvance(
      direction: direction,
      personId: personId,
      amount: amount,
      accountId: accountId,
      date: date,
      dueDate: dueDate,
      reminderDate: reminderDate,
      note: note,
    );
    await refreshCore(includePlanning: true);
    await _reloadAdvances();
    await _rebuildLearning();
    return id;
  }

  Future<int> createMixedAdvanceExpense({
    required int personId,
    required double totalAmount,
    required double personalAmount,
    required double advanceAmount,
    required int accountId,
    required int categoryId,
    required DateTime date,
    String? note,
    List<String> tags = const [],
    String? receiptPath,
  }) async {
    final id = await AdvanceService(database).createMixedExpense(
      personId: personId,
      totalAmount: totalAmount,
      personalAmount: personalAmount,
      advanceAmount: advanceAmount,
      accountId: accountId,
      categoryId: categoryId,
      date: date,
      note: note,
      tags: tags,
      receiptPath: receiptPath,
    );
    await refreshCore(includePlanning: true);
    await _reloadAdvances();
    await _rebuildLearning();
    return id;
  }

  Future<void> recordAdvanceSettlement({
    required int advanceId,
    required double amount,
    required int accountId,
    required DateTime date,
    String? note,
  }) async {
    await AdvanceService(database).recordSettlement(
      advanceId: advanceId,
      amount: amount,
      accountId: accountId,
      date: date,
      note: note,
    );
    await refreshCore(includePlanning: true);
    await _reloadAdvances();
    await _rebuildLearning();
  }

  Future<void> linkTransactionToAdvance({
    required int advanceId,
    required int transactionId,
  }) async {
    await AdvanceService(database).linkExistingTransactionAsSettlement(
      advanceId: advanceId,
      transactionId: transactionId,
    );
    await refreshCore(includePlanning: true);
    await _reloadAdvances();
    await _rebuildLearning();
  }

  Future<void> closeAdvanceWithoutRecovery(
    int advanceId, {
    required bool recognizeInAnalytics,
    int? categoryId,
    int? accountId,
  }) async {
    await AdvanceService(database).closeWithoutRecovery(
      advanceId: advanceId,
      recognizeInAnalytics: recognizeInAnalytics,
      categoryId: categoryId,
      accountId: accountId,
      date: DateTime.now(),
    );
    await refreshCore(includePlanning: true);
    await _reloadAdvances();
    await _rebuildLearning();
  }

  Future<void> updateAdvanceDates(
    int advanceId, {
    DateTime? dueDate,
    DateTime? reminderDate,
  }) async {
    await AdvanceService(database).updateDates(
      advanceId: advanceId,
      dueDate: dueDate,
      reminderDate: reminderDate,
    );
    await _reloadAdvances();
    notifyListeners();
  }

  Future<AdvanceMatchSuggestion?> advanceMatchSuggestion({
    required TransactionType type,
    required double amount,
    String? note,
  }) => AdvanceService(database).suggestMatch(
    type: type,
    amount: amount,
    note: note,
  );

  Future<void> _reloadAdvances() async {
    final service = AdvanceService(database);
    people = await service.people(includeArchived: true);
    advances = await service.advances();
    advanceSettlements = await service.settlements();
  }

'''
s = replace_once(s, api_marker, advance_api + api_marker, 'state advance API')
# learning projection
s = replace_once(
    s,
    '''    final patterns = SmartFinanceEngine.buildPatterns(
      transactions,
      previous: previous,
    );''',
    '''    final learningTransactions = analyticTransactions()
        .where((item) => !item.kind.startsWith('advance_'))
        .toList();
    final patterns = SmartFinanceEngine.buildPatterns(
      learningTransactions,
      previous: previous,
    );''',
    'learning projection build',
)
s = replace_once(
    s,
    '      final detected = SmartFinanceEngine.detectRecurring(transactions);',
    '      final detected = SmartFinanceEngine.detectRecurring(learningTransactions);',
    'learning projection recurring',
)
# refresh reload
s = replace_once(
    s,
    '''    transactions = await database.transactions();
    splits = await database.splits();
    if (includePlanning) {''',
    '''    transactions = await database.transactions();
    splits = await database.splits();
    await _reloadAdvances();
    if (includePlanning) {''',
    'refresh advances',
)
write(p, s)


# Notification service -----------------------------------------------------------
p = 'lib/services/notification_service.dart'
s = read(p)
s = replace_once(
    s,
    "    final forecastEnabled =\n        (await state.database.getSetting('notifications_forecast')) != '0';\n\n    final signatureParts = <String>[\n      '$recurringEnabled',\n      '$budgetEnabled',\n      '$goalEnabled',\n      '$forecastEnabled',\n    ];",
    "    final forecastEnabled =\n        (await state.database.getSetting('notifications_forecast')) != '0';\n    final advancesEnabled =\n        (await state.database.getSetting('notifications_advances')) != '0';\n\n    final signatureParts = <String>[\n      '$recurringEnabled',\n      '$budgetEnabled',\n      '$goalEnabled',\n      '$forecastEnabled',\n      '$advancesEnabled',\n    ];",
    'notification advance setting',
)
s = replace_once(
    s,
    '    signatureParts.add(state.endOfMonthForecast.toStringAsFixed(2));',
    "    signatureParts.add(state.endOfMonthForecast.toStringAsFixed(2));\n    for (final advance in state.advances) {\n      signatureParts.add(\n        'advance:${advance.id}:${state.advanceRemainingCents(advance.id)}:${advance.reminderDate?.millisecondsSinceEpoch}:${advance.dueDate?.millisecondsSinceEpoch}:${advance.closedKind}',\n      );\n    }",
    'notification advance signature',
)
s = replace_once(
    s,
    '    if (forecastEnabled) await _notifyLowForecast(state);\n  }',
    '    if (forecastEnabled) await _notifyLowForecast(state);\n    if (advancesEnabled) await _scheduleAdvances(state);\n  }',
    'notification advance sync',
)
method_marker = '  Future<void> _notifyLowForecast(AppState state) async {'
advance_notifications = r'''  Future<void> _scheduleAdvances(AppState state) async {
    final now = DateTime.now();
    for (final advance in state.advances) {
      final remainingCents = state.advanceRemainingCents(advance.id);
      if (advance.closedKind != null || remainingCents <= 0) continue;
      final person = state.personById(advance.personId);
      final due = advance.dueDate;
      final requested = advance.reminderDate ??
          (due == null ? null : due.subtract(const Duration(days: 1)));
      if (requested == null) continue;
      final reminder = DateTime(
        requested.year,
        requested.month,
        requested.day,
        9,
      );
      if (!reminder.isAfter(now)) {
        final overdueKey = 'notification_advance_${advance.id}_remaining';
        final previous = int.tryParse(
          await state.database.getSetting(overdueKey) ?? '',
        );
        if (previous == remainingCents) continue;
        final amount = (remainingCents / 100).toStringAsFixed(2).replaceAll('.', ',');
        await plugin.show(
          id: 500000 + advance.id,
          title: advance.direction.name == 'receivable'
              ? '${person?.name ?? 'Qualcuno'} deve ancora restituirti $amount €'
              : 'Devi ancora restituire $amount € a ${person?.name ?? 'qualcuno'}',
          body: 'Apri Anticipi per registrare un rimborso o aggiornare il promemoria.',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'finance_advances',
              'Anticipi',
              channelDescription: 'Promemoria locali per soldi da ricevere o restituire',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
          ),
          payload: 'advance:${advance.id}',
        );
        await state.database.setSetting(overdueKey, '$remainingCents');
        continue;
      }
      final amount = (remainingCents / 100).toStringAsFixed(2).replaceAll('.', ',');
      await plugin.zonedSchedule(
        id: 500000 + advance.id,
        title: advance.direction.name == 'receivable'
            ? '${person?.name ?? 'Qualcuno'} deve restituirti $amount €'
            : 'Devi restituire $amount € a ${person?.name ?? 'qualcuno'}',
        body: due == null
            ? 'Promemoria Anticipi'
            : 'Scadenza ${due.day}/${due.month}/${due.year}',
        scheduledDate: tz.TZDateTime.from(reminder.toUtc(), tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'finance_advances',
            'Anticipi',
            channelDescription: 'Promemoria locali per soldi da ricevere o restituire',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'advance:${advance.id}',
      );
    }
  }

'''
s = replace_once(s, method_marker, advance_notifications + method_marker, 'advance notifications method')
write(p, s)


# Notification settings ---------------------------------------------------------
p = 'lib/screens/notification_settings_screen.dart'
s = read(p)
s = replace_once(s, '  bool forecast = true;\n', '  bool forecast = true;\n  bool advances = true;\n', 'settings bool')
s = replace_once(
    s,
    "      state.database.getSetting('notifications_forecast'),\n      state.database.getSetting('notifications_low_balance_threshold'),",
    "      state.database.getSetting('notifications_forecast'),\n      state.database.getSetting('notifications_advances'),\n      state.database.getSetting('notifications_low_balance_threshold'),",
    'settings load key',
)
s = replace_once(
    s,
    "      forecast = values[4] != '0';\n      threshold.text = values[5] ?? '0';",
    "      forecast = values[4] != '0';\n      advances = values[5] != '0';\n      threshold.text = values[6] ?? '0';",
    'settings load values',
)
s = replace_once(
    s,
    "              _toggle(\n                'Saldo previsto basso',",
    "              _toggle(\n                'Anticipi',\n                'Ricorda i soldi ancora da ricevere o restituire.',\n                Icons.handshake_outlined,\n                advances,\n                'notifications_advances',\n                (value) => advances = value,\n              ),\n              _toggle(\n                'Saldo previsto basso',",
    'settings toggle advances',
)
write(p, s)

print('Anticipi core patch applied.')

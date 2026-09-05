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


# AdvanceService: people maintenance, metadata editing, safe cancellation -------
p = 'lib/services/advance_service.dart'
s = read(p)
marker = """  Future<int> createPureAdvance({"""
methods = r'''  Future<void> renamePerson(int personId, String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw StateError('Inserisci il nome della persona.');
    }
    final changed = await database.db.update(
      'finance_people',
      {
        'name': normalized,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [personId],
    );
    if (changed == 0) throw StateError('Persona non trovata.');
  }

  Future<void> updateAdvanceDetails({
    required int advanceId,
    required int personId,
    DateTime? dueDate,
    DateTime? reminderDate,
    String? note,
  }) async {
    await database.db.transaction((txn) async {
      final advance = await _advanceIn(txn, advanceId);
      if (advance.closedKind != null) {
        throw StateError('Lo storico di un anticipo chiuso non è modificabile.');
      }
      await _validatePerson(txn, personId);
      await txn.update(
        'advances',
        {
          'person_id': personId,
          'due_date': dueDate?.millisecondsSinceEpoch,
          'reminder_date': reminderDate?.millisecondsSinceEpoch,
          'note': note?.trim().isEmpty == true ? null : note?.trim(),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [advanceId],
      );
    });
  }

  /// Cancels an advance without fabricating new income/expense.
  ///
  /// Pure advances reverse their original cash movement. Mixed expenses keep
  /// the real purchase and simply stop allocating a share to the advance, so
  /// the whole purchase becomes personal analytics again.
  Future<void> cancelAdvance(int advanceId) async {
    await database.db.transaction((txn) async {
      final advance = await _advanceIn(txn, advanceId);
      if (advance.closedKind != null) {
        throw StateError('Questo anticipo è già chiuso.');
      }
      final settlementCount =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM advance_settlements WHERE advance_id = ?',
              [advanceId],
            ),
          ) ??
          0;
      if (settlementCount > 0) {
        throw StateError(
          'Elimina prima i rimborsi/restituzioni registrati per annullare l’anticipo.',
        );
      }

      final sourceId = advance.sourceTransactionId;
      if (sourceId != null) {
        final rows = await txn.query(
          'transactions',
          where: 'id = ?',
          whereArgs: [sourceId],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final item = FinanceTransaction.fromMap(rows.first);
          if (item.kind == 'advance_origin') {
            final cents = Money.toCents(item.amount);
            await _applyCashDelta(
              txn,
              item.accountId,
              item.type == TransactionType.income ? -cents : cents,
            );
            await txn.update(
              'advances',
              {'source_transaction_id': null},
              where: 'id = ?',
              whereArgs: [advanceId],
            );
            await txn.delete(
              'transactions',
              where: 'id = ?',
              whereArgs: [sourceId],
            );
          } else if (item.kind == 'mixed_advance') {
            await txn.update(
              'transactions',
              {
                'kind': 'normal',
                'updated_at': DateTime.now().millisecondsSinceEpoch,
              },
              where: 'id = ?',
              whereArgs: [sourceId],
            );
          }
        }
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.update(
        'advances',
        {
          'closed_kind': AdvanceClosedKind.cancelled.dbValue,
          'closed_at': now,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [advanceId],
      );
    });
  }

'''
s = replace_once(s, marker, methods + marker, 'advance service maintenance methods')

# Strengthen archive semantics: do not hide a person with money still open.
old = r'''  Future<void> archivePerson(int personId, bool archived) async {
    await database.db.update(
      'finance_people',
      {
        'archived': archived ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [personId],
    );
  }
'''
new = r"""  Future<void> archivePerson(int personId, bool archived) async {
    if (archived) {
      final open =
          Sqflite.firstIntValue(
            await database.db.rawQuery(
              '''SELECT COUNT(*) FROM advances a
                 WHERE a.person_id = ? AND a.closed_kind IS NULL
                   AND a.original_amount_cents > COALESCE(
                     (SELECT SUM(s.amount_cents) FROM advance_settlements s WHERE s.advance_id = a.id), 0
                   )''',
              [personId],
            ),
          ) ??
          0;
      if (open > 0) {
        throw StateError(
          'Questa persona ha anticipi ancora aperti. Chiudili prima di archiviarla.',
        );
      }
    }
    final changed = await database.db.update(
      'finance_people',
      {
        'archived': archived ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [personId],
    );
    if (changed == 0) throw StateError('Persona non trovata.');
  }
"""
s = replace_once(s, old, new, 'advance person archive guard')
write(p, s)


# AppState wrappers --------------------------------------------------------------
p = 'lib/app_state.dart'
s = read(p)
marker = """  Future<int> createPureAdvance({"""
wrappers = r'''  Future<void> renameFinancePerson(int personId, String name) async {
    await AdvanceService(database).renamePerson(personId, name);
    await _reloadAdvances();
    notifyListeners();
  }

  Future<void> archiveFinancePerson(int personId, bool archived) async {
    await AdvanceService(database).archivePerson(personId, archived);
    await _reloadAdvances();
    notifyListeners();
  }

  Future<void> updateAdvanceDetails({
    required int advanceId,
    required int personId,
    DateTime? dueDate,
    DateTime? reminderDate,
    String? note,
  }) async {
    await AdvanceService(database).updateAdvanceDetails(
      advanceId: advanceId,
      personId: personId,
      dueDate: dueDate,
      reminderDate: reminderDate,
      note: note,
    );
    await _reloadAdvances();
    notifyListeners();
  }

  Future<void> cancelAdvance(int advanceId) async {
    await AdvanceService(database).cancelAdvance(advanceId);
    await refreshCore(includePlanning: true);
    await _reloadAdvances();
    await _rebuildLearning();
  }

'''
s = replace_once(s, marker, wrappers + marker, 'app state advance maintenance wrappers')
marker = """  Future<void> linkTransactionToAdvance({"""
wrappers2 = r'''  Future<void> updateAdvanceSettlement({
    required AdvanceSettlement settlement,
    required double amount,
    required int accountId,
    required DateTime date,
    String? note,
  }) async {
    await AdvanceService(database).updateSettlement(
      settlementId: settlement.id,
      amount: amount,
      accountId: accountId,
      date: date,
      note: note,
    );
    await refreshCore(includePlanning: true);
    await _reloadAdvances();
    await _rebuildLearning();
  }

  Future<void> deleteAdvanceSettlement(int settlementId) async {
    await AdvanceService(database).deleteSettlement(settlementId);
    await refreshCore(includePlanning: true);
    await _reloadAdvances();
    await _rebuildLearning();
  }

'''
s = replace_once(s, marker, wrappers2 + marker, 'app state settlement wrappers')
write(p, s)


# Database wipe includes the new ledger -----------------------------------------
p = 'lib/data/app_database.dart'
s = read(p)
old = """      await txn.delete('transaction_splits');
      await txn.delete('transactions');"""
new = """      await txn.delete('transaction_splits');
      await txn.delete('advance_settlements');
      await txn.delete('advances');
      await txn.delete('finance_people');
      await txn.delete('transactions');"""
s = replace_once(s, old, new, 'clear user Anticipi data')
write(p, s)

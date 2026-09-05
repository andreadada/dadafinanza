import '../core/money.dart';
import '../data/app_database.dart';
import '../models/models.dart';

class QuickPreset {
  const QuickPreset({
    required this.id,
    required this.name,
    required this.type,
    required this.position,
    required this.enabled,
    this.accountId,
    this.toAccountId,
    this.categoryId,
    this.amount,
    this.note,
    this.tags = const [],
  });

  final int id;
  final String name;
  final TransactionType type;
  final int? accountId;
  final int? toAccountId;
  final int? categoryId;
  final double? amount;
  final String? note;
  final List<String> tags;
  final int position;
  final bool enabled;

  factory QuickPreset.fromMap(Map<String, Object?> map) => QuickPreset(
        id: map['id'] as int,
        name: map['name'] as String,
        type: TransactionTypeX.fromDb(map['type'] as String),
        accountId: map['account_id'] as int?,
        toAccountId: map['to_account_id'] as int?,
        categoryId: map['category_id'] as int?,
        amount: map['amount_cents'] == null
            ? null
            : Money.fromCents((map['amount_cents'] as num).toInt()),
        note: map['note'] as String?,
        tags: ((map['tags'] as String?) ?? '')
            .split('|')
            .where((item) => item.isNotEmpty)
            .toList(),
        position: map['position'] as int? ?? 0,
        enabled: (map['enabled'] as int? ?? 1) == 1,
      );
}

class QuickPresetService {
  QuickPresetService(this.database);
  final AppDatabase database;

  Future<List<QuickPreset>> all({bool enabledOnly = false}) async {
    final rows = await database.db.query(
      'quick_presets',
      where: enabledOnly ? 'enabled = 1' : null,
      orderBy: 'position ASC, id ASC',
    );
    return rows.map(QuickPreset.fromMap).toList();
  }

  Future<int> save({
    int? id,
    required String name,
    required TransactionType type,
    int? accountId,
    int? toAccountId,
    int? categoryId,
    double? amount,
    String? note,
    List<String> tags = const [],
    int? position,
    bool enabled = true,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final value = <String, Object?>{
      'name': name.trim(),
      'type': type.dbValue,
      'account_id': accountId,
      'to_account_id': type == TransactionType.transfer ? toAccountId : null,
      'category_id': type == TransactionType.transfer ? null : categoryId,
      'amount_cents': amount == null ? null : Money.toCents(amount),
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
      'tags': tags.where((item) => item.trim().isNotEmpty).join('|'),
      'position': position ?? await _nextPosition(),
      'enabled': enabled ? 1 : 0,
      'updated_at': now,
    };
    if (id == null) {
      value['created_at'] = now;
      return database.db.insert('quick_presets', value);
    }
    await database.db.update(
      'quick_presets',
      value,
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }

  Future<void> delete(int id) => database.db.delete(
        'quick_presets',
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> reorder(List<QuickPreset> presets) async {
    await database.db.transaction((txn) async {
      for (var index = 0; index < presets.length; index++) {
        await txn.update(
          'quick_presets',
          {'position': index, 'updated_at': DateTime.now().millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [presets[index].id],
        );
      }
    });
  }

  Future<int> _nextPosition() async {
    final rows = await database.db.rawQuery(
      'SELECT COALESCE(MAX(position), -1) + 1 AS next_position FROM quick_presets',
    );
    return (rows.first['next_position'] as num?)?.toInt() ?? 0;
  }
}

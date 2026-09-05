import '../app_state.dart';
import '../core/money.dart';
import '../models/models.dart';
import '../models/quick_capture_models.dart';
import 'quick_preset_service.dart';

class QuickCaptureDeepLinkService {
  const QuickCaptureDeepLinkService();

  Future<TransactionDraft?> fromUri(AppState state, Uri uri) async {
    if (uri.scheme != 'dadafinanza' || uri.host != 'quick-add') return null;
    final query = uri.queryParameters;

    var type = switch (query['type']?.toLowerCase()) {
      'income' => TransactionType.income,
      'transfer' => TransactionType.transfer,
      _ => TransactionType.expense,
    };
    int? amountCents;
    int? accountId;
    int? toAccountId;
    int? categoryId;
    String? note = _clean(query['note']);
    DateTime? date = DateTime.tryParse(query['date'] ?? '');
    var source = QuickCaptureSource.deepLink;

    final presetId = int.tryParse(query['presetId'] ?? '');
    if (presetId != null) {
      final preset = await QuickPresetService(state.database).all();
      final selected = preset.where((item) => item.id == presetId && item.enabled).firstOrNull;
      if (selected != null) {
        type = selected.type;
        amountCents = selected.amount == null ? null : Money.toCents(selected.amount!);
        accountId = _validAccount(state, selected.accountId);
        toAccountId = _validAccount(state, selected.toAccountId);
        categoryId = _validCategory(state, selected.categoryId, type);
        source = QuickCaptureSource.preset;
      }
    }

    final amountRaw = _clean(query['amount']);
    if (amountRaw != null) {
      final parsed = Money.parseExpression(amountRaw);
      if (parsed != null && parsed > 0) amountCents = Money.toCents(parsed);
    }

    final accountRaw = _clean(query['account']);
    if (accountRaw != null) accountId = _resolveAccount(state, accountRaw);
    final destinationRaw = _clean(query['toAccount']);
    if (destinationRaw != null) {
      toAccountId = _resolveAccount(state, destinationRaw);
    }
    final categoryRaw = _clean(query['category']);
    if (categoryRaw != null && type != TransactionType.transfer) {
      categoryId = _resolveCategory(state, categoryRaw, type);
    }

    if (type != TransactionType.transfer) toAccountId = null;
    if (type == TransactionType.transfer) categoryId = null;
    if (accountId != null && accountId == toAccountId) toAccountId = null;
    if (date != null && date.year < 2000) date = null;

    return TransactionDraft(
      type: type,
      amountCents: amountCents,
      accountId: accountId,
      toAccountId: toAccountId,
      categoryId: categoryId,
      date: date,
      note: note,
      source: source,
      startVoice: query['voice'] == '1' || query['voice'] == 'true',
    );
  }

  int? _resolveAccount(AppState state, String value) {
    final numeric = int.tryParse(value);
    if (numeric != null) return _validAccount(state, numeric);
    final normalized = _normalize(value);
    final matches = state.activeAccounts
        .where((item) => _normalize(item.name) == normalized && !item.isLocked)
        .toList();
    return matches.length == 1 ? matches.single.id : null;
  }

  int? _resolveCategory(
    AppState state,
    String value,
    TransactionType type,
  ) {
    final numeric = int.tryParse(value);
    if (numeric != null) return _validCategory(state, numeric, type);
    final normalized = _normalize(value);
    final matches = state
        .categoriesFor(type)
        .where((item) => _normalize(item.name) == normalized)
        .toList();
    return matches.length == 1 ? matches.single.id : null;
  }

  int? _validAccount(AppState state, int? id) {
    if (id == null) return null;
    final item = state.accountById(id);
    if (item == null || item.isArchived || item.isLocked) return null;
    return item.id;
  }

  int? _validCategory(AppState state, int? id, TransactionType type) {
    if (id == null) return null;
    final item = state.categoryById(id);
    return item?.type == type ? item!.id : null;
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');
}

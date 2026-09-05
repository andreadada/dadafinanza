import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../core/money.dart';
import '../main.dart';
import '../models/models.dart';
import '../models/quick_capture_models.dart';
import '../models/smart_models.dart';
import '../services/attachment_service.dart';
import '../services/goal_ledger_service.dart';
import '../services/voice_input_service.dart';
import '../services/voice_transaction_parser.dart';
import '../widgets/ui_helpers.dart';
import 'account_screens.dart';

class QuickAddPage extends StatefulWidget {
  const QuickAddPage({
    this.initialDraft,
    this.initialCategoryName,
    this.initialTypeName,
    this.initialAccountId,
    this.initialToAccountId,
    this.initialAmount,
    this.initialNote,
    this.initialDate,
    this.startVoice = false,
    this.initialGoalId,
    this.editing,
    this.refundOfTransactionId,
    super.key,
  });

  final TransactionDraft? initialDraft;
  final String? initialCategoryName;
  final String? initialTypeName;
  final int? initialAccountId;
  final int? initialToAccountId;
  final double? initialAmount;
  final String? initialNote;
  final DateTime? initialDate;
  final bool startVoice;
  final int? initialGoalId;
  final FinanceTransaction? editing;
  final int? refundOfTransactionId;

  @override
  State<QuickAddPage> createState() => _QuickAddPageState();
}

class _QuickAddPageState extends State<QuickAddPage> {
  final amount = TextEditingController();
  final note = TextEditingController();
  final tag = TextEditingController();
  final amountFocus = FocusNode();
  final picker = ImagePicker();
  final attachments = AttachmentService();
  final voice = VoiceInputService();
  final voiceParser = VoiceTransactionParser();

  late TransactionType type;
  int? accountId;
  int? toAccountId;
  int? categoryId;
  DateTime date = DateTime.now();
  final tags = <String>[];
  XFile? receipt;
  String? existingReceiptPath;
  bool receiptRemoved = false;
  bool includeInAnalytics = true;
  bool expanded = false;
  bool saving = false;
  bool _defaultsSet = false;
  bool _voiceAutoStarted = false;
  bool voiceApplied = false;
  String? lastVoiceTranscript;
  Timer? _suggestionDebounce;
  SmartSuggestion? suggestion;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    final draft = widget.initialDraft;
    type =
        editing?.type ??
        draft?.type ??
        switch (widget.initialTypeName) {
          'income' => TransactionType.income,
          'transfer' => TransactionType.transfer,
          _ => TransactionType.expense,
        };
    if (editing != null) {
      amount.text = editing.amount.toStringAsFixed(2);
      note.text = editing.note ?? '';
      tags.addAll(editing.tags);
      accountId = editing.accountId;
      toAccountId = editing.toAccountId;
      categoryId = editing.categoryId;
      date = editing.date;
      includeInAnalytics = editing.includeInAnalytics;
      existingReceiptPath = editing.receiptPath;
      expanded =
          editing.tags.isNotEmpty ||
          editing.receiptPath != null ||
          !editing.includeInAnalytics;
    } else {
      if (draft?.amountCents != null) {
        amount.text = Money.fromCents(draft!.amountCents!).toStringAsFixed(2);
      } else if (widget.initialAmount != null && widget.initialAmount! > 0) {
        amount.text = widget.initialAmount!.toStringAsFixed(2);
      }
      note.text = draft?.note ?? widget.initialNote ?? '';
      tags.addAll(draft?.tags ?? const []);
      accountId = draft?.accountId;
      toAccountId = draft?.toAccountId;
      categoryId = draft?.categoryId;
      date = draft?.date ?? widget.initialDate ?? DateTime.now();
    }
    amount.addListener(_scheduleSuggestion);
    note.addListener(_scheduleSuggestion);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_defaultsSet) {
      _defaultsSet = true;
      _setDefaults();
      _scheduleSuggestion();
      final shouldStartVoice =
          widget.startVoice || widget.initialDraft?.startVoice == true;
      if (shouldStartVoice && !_voiceAutoStarted && widget.editing == null) {
        _voiceAutoStarted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_startVoice());
        });
      }
    }
  }

  @override
  void dispose() {
    _suggestionDebounce?.cancel();
    amount.removeListener(_scheduleSuggestion);
    note.removeListener(_scheduleSuggestion);
    amount.dispose();
    note.dispose();
    tag.dispose();
    amountFocus.dispose();
    unawaited(voice.cancel());
    super.dispose();
  }

  Account? _recentUsableAccount(AppState state, TransactionType wanted) {
    for (final transaction in state.transactions) {
      if (transaction.type != wanted && wanted != TransactionType.transfer) {
        continue;
      }
      final account = state.accountById(transaction.accountId);
      if (account != null &&
          !account.isSystem &&
          !account.isArchived &&
          !account.isLocked) {
        return account;
      }
    }
    return null;
  }

  List<Category> _recentCategories(AppState state) {
    if (type == TransactionType.transfer) return const [];
    final preferred = state
        .categoriesFor(type)
        .where((item) => item.isFavorite)
        .toList();
    final result = <Category>[...preferred];
    final seen = preferred.map((item) => item.id).toSet();
    for (final transaction in state.transactions) {
      if (transaction.type != type || transaction.categoryId == null) continue;
      final category = state.categoryById(transaction.categoryId);
      if (category != null && category.type == type && seen.add(category.id)) {
        result.add(category);
      }
      if (result.length >= 6) break;
    }
    if (result.isEmpty) return state.categoriesFor(type).take(5).toList();
    return result.take(6).toList();
  }

  List<Account> _orderedAccounts(AppState state, {bool destination = false}) {
    final active = state.activeAccounts
        .where(
          (account) =>
              !account.isLocked && (!destination || account.id != accountId),
        )
        .toList();
    final last = _recentUsableAccount(state, type);
    if (last != null) {
      final index = active.indexWhere((item) => item.id == last.id);
      if (index > 0) active.insert(0, active.removeAt(index));
    }
    return active;
  }

  void _setDefaults() {
    if (widget.editing != null) return;
    final state = AppScope.of(context);
    final active = _orderedAccounts(state);
    accountId ??= widget.initialAccountId;
    accountId ??= _recentUsableAccount(state, type)?.id;
    accountId ??= active.firstOrNull?.id;
    if (accountId == null && state.allowUnassigned) {
      accountId = state.unassignedAccount?.id;
    }
    if (type == TransactionType.transfer) {
      final alternatives = _orderedAccounts(state, destination: true);
      toAccountId ??= widget.initialToAccountId;
      if (toAccountId == accountId ||
          alternatives.every((item) => item.id != toAccountId)) {
        toAccountId = alternatives.firstOrNull?.id;
      }
    }
    final categories = state.categoriesFor(type);
    if (categoryId == null && widget.initialCategoryName != null) {
      categoryId = categories
          .where(
            (item) =>
                item.name.toLowerCase() ==
                widget.initialCategoryName!.toLowerCase(),
          )
          .firstOrNull
          ?.id;
    }
    categoryId ??= _recentCategories(state).firstOrNull?.id;
    categoryId ??= categories.firstOrNull?.id;
  }

  void _changeType(TransactionType value) {
    final state = AppScope.of(context);
    setState(() {
      type = value;
      suggestion = null;
      categoryId = value == TransactionType.transfer
          ? null
          : _recentCategories(state).firstOrNull?.id ??
                state.categoriesFor(value).firstOrNull?.id;
      final recentAccount = _recentUsableAccount(state, value);
      if (recentAccount != null) accountId = recentAccount.id;
      if (value == TransactionType.transfer) {
        final alternatives = _orderedAccounts(state, destination: true);
        toAccountId = alternatives.firstOrNull?.id;
      } else {
        toAccountId = null;
      }
    });
    _scheduleSuggestion();
  }

  void _scheduleSuggestion() {
    if (!mounted || widget.editing != null || !_defaultsSet) return;
    _suggestionDebounce?.cancel();
    _suggestionDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      final state = AppScope.of(context);
      final parsed = Money.parseExpression(amount.text);
      final next = state.smartSuggestion(
        note: note.text,
        type: type,
        amount: parsed,
        date: date,
      );
      if (mounted) setState(() => suggestion = next);
    });
  }

  Color _suggestionColor(BuildContext context) => switch (type) {
    TransactionType.expense => context.financeColors.negative,
    TransactionType.income => context.financeColors.positive,
    TransactionType.transfer => context.financeColors.neutral,
  };

  Future<void> _startVoice() async {
    final state = AppScope.of(context);
    final enabled =
        (await state.database.getSetting('voice_enabled') ?? '1') == '1';
    if (!enabled) {
      if (mounted)
        _error('L’inserimento vocale è disattivato nelle Impostazioni.');
      return;
    }
    final allowSystem =
        (await state.database.getSetting('voice_allow_system_recognizer') ??
            '0') ==
        '1';
    final status = await voice.prepare(allowSystemRecognizer: allowSystem);
    if (!mounted) return;
    if (!status.available) {
      _error(status.message ?? 'Riconoscimento vocale non disponibile.');
      return;
    }
    if (state.haptics) HapticFeedback.selectionClick();
    final transcript = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      builder: (_) =>
          _VoiceListeningSheet(voice: voice, onDevice: status.onDevice),
    );
    if (!mounted || transcript == null || transcript.trim().isEmpty) return;
    if (state.haptics) HapticFeedback.lightImpact();
    await _applyVoiceTranscript(transcript);
  }

  Future<void> _applyVoiceTranscript(String transcript) async {
    final state = AppScope.of(context);
    var result = voiceParser.parse(
      transcript,
      accounts: state.accounts,
      categories: state.categories,
    );

    for (final issue in result.issues) {
      if (!mounted) return;
      if (issue.type == VoiceIssueType.ambiguousCategory &&
          issue.candidateIds.isNotEmpty) {
        final selected = await _pickVoiceCategory(issue.candidateIds);
        if (selected != null) {
          result = VoiceParseResult(
            transcript: result.transcript,
            issues: result.issues.where((item) => item != issue).toList(),
            draft: result.draft.copyWith(categoryId: selected),
          );
        }
      } else if (issue.type == VoiceIssueType.ambiguousAccount &&
          issue.candidateIds.isNotEmpty) {
        final selected = await _pickVoiceAccount(issue.candidateIds);
        if (selected != null && result.draft.type != TransactionType.transfer) {
          result = VoiceParseResult(
            transcript: result.transcript,
            issues: result.issues.where((item) => item != issue).toList(),
            draft: result.draft.copyWith(accountId: selected),
          );
        }
      }
    }

    final draft = result.draft;
    final parsedAmount = draft.amountCents == null
        ? null
        : Money.fromCents(draft.amountCents!);
    SmartSuggestion? smart;
    if ((draft.note ?? '').trim().isNotEmpty) {
      smart = state.smartSuggestion(
        note: draft.note!,
        type: draft.type,
        amount: parsedAmount,
        date: draft.date ?? DateTime.now(),
      );
    }

    setState(() {
      type = draft.type;
      if (draft.amountCents != null) {
        amount.text = Money.fromCents(draft.amountCents!).toStringAsFixed(2);
      }
      if (draft.categoryId != null) {
        categoryId = draft.categoryId;
      } else if (type != TransactionType.transfer &&
          smart?.categoryId != null) {
        categoryId = smart!.categoryId;
      }
      if (draft.accountId != null) {
        accountId = draft.accountId;
      } else if (smart?.accountId != null) {
        final candidate = state.accountById(smart!.accountId);
        if (candidate != null && !candidate.isArchived && !candidate.isLocked) {
          accountId = candidate.id;
        }
      }
      if (draft.toAccountId != null) {
        toAccountId = draft.toAccountId;
      } else if (type == TransactionType.transfer &&
          smart?.toAccountId != null) {
        toAccountId = smart!.toAccountId;
      }
      if (draft.date != null) date = draft.date!;
      if ((draft.note ?? '').trim().isNotEmpty) note.text = draft.note!;
      for (final value in draft.tags) {
        if (!tags.contains(value)) tags.add(value);
      }
      lastVoiceTranscript = transcript;
      voiceApplied = true;
      suggestion = null;
    });

    final blocking = result.issues.where(
      (issue) =>
          issue.type == VoiceIssueType.missingAmount ||
          issue.type == VoiceIssueType.ambiguousAmount,
    );
    if (blocking.isNotEmpty) {
      _error(
        '${blocking.first.message} Puoi inserirlo manualmente oppure riprovare.',
      );
      amountFocus.requestFocus();
    }
    _scheduleSuggestion();
  }

  Future<int?> _pickVoiceCategory(List<int> ids) async {
    final state = AppScope.of(context);
    final items = ids.map(state.categoryById).whereType<Category>().toList();
    return showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quale categoria intendevi?',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(categoryIcon(item.iconKey)),
                title: Text(item.name),
                onTap: () => Navigator.pop(sheetContext, item.id),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<int?> _pickVoiceAccount(List<int> ids) async {
    final state = AppScope.of(context);
    final items = ids.map(state.accountById).whereType<Account>().toList();
    return showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quale conto intendevi?',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(accountIcon(item.iconKey)),
                title: Text(item.name),
                onTap: () => Navigator.pop(sheetContext, item.id),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _previewSuggestion() async {
    final current = suggestion;
    if (current == null) return;
    final state = AppScope.of(context);
    final category = state.categoryById(current.categoryId);
    final account = state.accountById(current.accountId);
    final destination = state.accountById(current.toAccountId);
    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ti suggerisco',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                current.type == TransactionType.expense
                    ? Icons.arrow_upward_rounded
                    : current.type == TransactionType.income
                    ? Icons.arrow_downward_rounded
                    : Icons.swap_horiz_rounded,
                color: _suggestionColor(sheetContext),
              ),
              title: Text(current.type.label),
              subtitle: Text(
                [
                  if (category != null) category.name,
                  if (account != null) account.name,
                  if (destination != null) '→ ${destination.name}',
                  if (current.tags.isNotEmpty)
                    current.tags.map((item) => '#$item').join(' '),
                ].join(' · '),
              ),
              trailing: current.amount == null
                  ? null
                  : Text(
                      moneyFor(state, current.amount!),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(current.explanation)),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext, 'reject'),
                  child: const Text('Non suggerire'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext, 'modify'),
                  child: const Text('Modifica'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, 'apply'),
                  child: const Text('Applica'),
                ),
              ],
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(sheetContext, 'suppress'),
                child: const Text('Non suggerire più per questo testo'),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result == 'apply') {
      await _applySuggestion(current);
    } else if (result == 'suppress') {
      await state.suppressSuggestion(current, note.text);
      if (mounted) setState(() => suggestion = null);
    } else {
      await state.rejectSuggestion(
        current,
        note.text,
        modified: result == 'modify',
      );
      if (mounted) setState(() => suggestion = null);
    }
  }

  Future<void> _applySuggestion(SmartSuggestion current) async {
    final state = AppScope.of(context);
    final suggestedAccount = state.accountById(current.accountId);
    final suggestedDestination = state.accountById(current.toAccountId);
    setState(() {
      if (current.categoryId != null && type != TransactionType.transfer) {
        final category = state.categoryById(current.categoryId);
        if (category?.type == type) categoryId = category!.id;
      }
      if (suggestedAccount != null &&
          !suggestedAccount.isLocked &&
          !suggestedAccount.isArchived) {
        accountId = suggestedAccount.id;
      }
      if (type == TransactionType.transfer &&
          suggestedDestination != null &&
          suggestedDestination.id != accountId &&
          !suggestedDestination.isLocked &&
          !suggestedDestination.isArchived) {
        toAccountId = suggestedDestination.id;
      }
      for (final item in current.tags) {
        if (!tags.contains(item)) tags.add(item);
      }
      if (amount.text.trim().isEmpty && current.amount != null) {
        amount.text = current.amount!.toStringAsFixed(2);
      }
      suggestion = null;
    });
    await state.acceptSuggestion(current, note.text);
  }

  Future<void> _chooseReceipt() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Scatta foto'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Scegli dalla galleria'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            if (receipt != null || existingReceiptPath != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
                title: Text(
                  'Rimuovi ricevuta',
                  style: TextStyle(
                    color: Theme.of(sheetContext).colorScheme.error,
                  ),
                ),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'remove') {
      setState(() {
        receipt = null;
        receiptRemoved = true;
      });
      return;
    }
    final source = choice == 'camera'
        ? ImageSource.camera
        : ImageSource.gallery;
    final result = await picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (result != null && mounted) {
      setState(() {
        receipt = result;
        receiptRemoved = false;
      });
    }
  }

  Future<void> _save() async {
    final state = AppScope.of(context);
    final parsed = Money.parseExpression(amount.text);
    if (parsed == null || parsed <= 0) {
      return _error('Inserisci un importo maggiore di 0.');
    }
    if (accountId == null) {
      return _error('Scegli un conto o usa Non assegnato.');
    }
    if (type == TransactionType.transfer &&
        (toAccountId == null || toAccountId == accountId)) {
      return _error('Scegli due conti diversi.');
    }
    if (type != TransactionType.transfer && categoryId == null) {
      return _error('Scegli o crea una categoria.');
    }
    if (widget.initialGoalId != null && type == TransactionType.transfer) {
      final goal = state.goals
          .where((item) => item.id == widget.initialGoalId)
          .firstOrNull;
      if (goal == null || goal.linkedAccountId == null) {
        return _error('L’obiettivo collegato non è più disponibile.');
      }
      if (goal.linkedAccountId != toAccountId) {
        return _error(
          'Usa il conto collegato all’obiettivo come destinazione.',
        );
      }
    }
    setState(() => saving = true);
    String? managedReceipt = receiptRemoved ? null : existingReceiptPath;
    try {
      if (receipt != null)
        managedReceipt = await attachments.persist(receipt!.path);
      final editing = widget.editing;
      if (editing == null) {
        final createdId = await state.addTransaction(
          type: type,
          amount: parsed,
          accountId: accountId!,
          toAccountId: type == TransactionType.transfer ? toAccountId : null,
          categoryId: type == TransactionType.transfer ? null : categoryId,
          date: date,
          note: note.text.trim().isEmpty ? null : note.text.trim(),
          tags: tags,
          receiptPath: managedReceipt,
          includeInAnalytics: includeInAnalytics,
          refundOfTransactionId: widget.refundOfTransactionId,
        );
        if (type == TransactionType.transfer && widget.initialGoalId != null) {
          await GoalLedgerService(state.database).linkTransfer(
            goalId: widget.initialGoalId!,
            transactionId: createdId,
          );
          await state.refreshCore(includePlanning: true);
        }
      } else {
        await state.updateTransaction(
          editing,
          editing.copyWith(
            type: type,
            amount: parsed,
            accountId: accountId!,
            toAccountId: type == TransactionType.transfer ? toAccountId : null,
            categoryId: type == TransactionType.transfer ? null : categoryId,
            date: date,
            note: note.text.trim().isEmpty ? null : note.text.trim(),
            tags: tags,
            receiptPath: managedReceipt,
            includeInAnalytics: includeInAnalytics,
            updatedAt: DateTime.now(),
          ),
        );
        if ((receiptRemoved || receipt != null) &&
            existingReceiptPath != null) {
          await attachments.delete(existingReceiptPath);
        }
      }
      await attachments.cleanup(
        state.transactions.map((item) => item.receiptPath),
      );
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        final message = editing != null
            ? 'Movimento aggiornato.'
            : switch (type) {
                TransactionType.expense => 'Spesa registrata.',
                TransactionType.income => 'Entrata registrata.',
                TransactionType.transfer => 'Trasferimento registrato.',
              };
        Navigator.pop(context);
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (managedReceipt != null && managedReceipt != existingReceiptPath) {
        await attachments.delete(managedReceipt);
      }
      if (mounted) {
        setState(() => saving = false);
        _error(error.toString().replaceFirst('Bad state: ', ''));
      }
    }
  }

  void _error(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _chooseCategory() async {
    final state = AppScope.of(context);
    final values = state.categoriesFor(type);
    final picked = await showModalBottomSheet<int?>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          shrinkWrap: true,
          children: [
            Text(
              'Categoria',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...values.map(
              (category) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  categoryIcon(category.iconKey),
                  color: Color(category.colorValue),
                ),
                title: Text(category.name),
                trailing: categoryId == category.id
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(sheetContext, category.id),
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add_rounded),
              title: const Text('Nuova categoria'),
              subtitle: const Text('Creala senza perdere i dati inseriti'),
              onTap: () => Navigator.pop(sheetContext, -1),
            ),
          ],
        ),
      ),
    );
    if (picked == -1 && mounted) {
      final created = await showCategoryCreator(
        context,
        state,
        initialType: type,
        lockType: true,
      );
      if (created != null && mounted) setState(() => categoryId = created.id);
    } else if (picked != null && mounted) {
      setState(() => categoryId = picked);
    }
  }

  Future<void> _chooseAccount({bool destination = false}) async {
    final state = AppScope.of(context);
    final current = destination ? toAccountId : accountId;
    final options = _orderedAccounts(state, destination: destination);
    final picked = await showModalBottomSheet<int?>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            Text(
              destination ? 'Conto destinazione' : 'Conto',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            if (!destination &&
                state.allowUnassigned &&
                state.unassignedAccount != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.help_outline_rounded),
                title: const Text('Non assegnato'),
                subtitle: const Text('Potrai scegliere il conto in seguito'),
                trailing: current == state.unassignedAccount!.id
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () =>
                    Navigator.pop(sheetContext, state.unassignedAccount!.id),
              ),
            ...options.map(
              (account) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  accountIcon(account.iconKey),
                  color: Color(account.colorValue),
                ),
                title: Text(account.name),
                subtitle: Text(account.accountType.label),
                trailing: current == account.id
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(sheetContext, account.id),
              ),
            ),
            if (!destination) ...[
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_rounded),
                title: const Text('Nuovo conto'),
                onTap: () => Navigator.pop(sheetContext, -1),
              ),
            ],
          ],
        ),
      ),
    );
    if (picked == -1 && mounted) {
      final created = await showAccountEditor(context);
      if (created != null && mounted) setState(() => accountId = created.id);
    } else if (picked != null && mounted) {
      setState(() {
        if (destination) {
          toAccountId = picked;
        } else {
          accountId = picked;
          if (toAccountId == picked) toAccountId = null;
        }
      });
      _scheduleSuggestion();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final category = state.categoryById(categoryId);
    final account = state.accountById(accountId);
    final destination = state.accountById(toAccountId);
    final linkedGoal = widget.initialGoalId == null
        ? null
        : state.goals
              .where((item) => item.id == widget.initialGoalId)
              .firstOrNull;
    final recentCategories = _recentCategories(state);
    final visibleSuggestion =
        widget.editing == null && suggestion?.shouldSurface == true;
    final hasInitialAmount = amount.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editing == null ? 'Nuovo movimento' : 'Modifica movimento',
        ),
        actions: [
          if (widget.editing == null)
            Semantics(
              button: true,
              label: 'Compila con la voce',
              child: IconButton(
                tooltip: 'Compila con la voce',
                onPressed: _startVoice,
                icon: const Icon(Icons.mic_none_rounded),
              ),
            ),
        ],
      ),
      floatingActionButton: visibleSuggestion
          ? FloatingActionButton.extended(
              heroTag: 'smart-complete',
              tooltip: 'Completa con il suggerimento',
              onPressed: _previewSuggestion,
              backgroundColor: _suggestionColor(context),
              foregroundColor: Theme.of(context).colorScheme.surface,
              icon: const Icon(Icons.bolt_rounded),
              label: const Text('Completa'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
          children: [
            if (voiceApplied) ...[
              Row(
                children: [
                  const Icon(Icons.mic_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Compilato dalla voce · controlla e salva',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: _startVoice,
                    child: const Text('Ripeti'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'IMPORTO',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(letterSpacing: 1.2),
            ),
            TextField(
              controller: amount,
              focusNode: amountFocus,
              autofocus:
                  widget.editing == null &&
                  !hasInitialAmount &&
                  !widget.startVoice,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(fontSize: 48),
              decoration: const InputDecoration(
                hintText: '0,00',
                suffixText: '€',
                helperText: 'Puoi anche scrivere 12,50 + 4,20',
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<TransactionType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Spesa'),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Entrata'),
                  ),
                  ButtonSegment(
                    value: TransactionType.transfer,
                    label: Text('Trasferimento'),
                  ),
                ],
                selected: {type},
                onSelectionChanged: (value) => _changeType(value.first),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descrizione opzionale',
                hintText: 'Es. LIDL, Spotify, stipendio…',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            if (lastVoiceTranscript != null) ...[
              const SizedBox(height: 4),
              Text(
                'Hai detto: “$lastVoiceTranscript”',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (type != TransactionType.transfer &&
                recentCategories.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Preferite e recenti',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: recentCategories
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            avatar: Icon(categoryIcon(item.iconKey), size: 17),
                            label: Text(item.name),
                            selected: categoryId == item.id,
                            onSelected: (_) =>
                                setState(() => categoryId = item.id),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (type != TransactionType.transfer) ...[
              _PickerRow(
                icon: category == null
                    ? Icons.category_outlined
                    : categoryIcon(category.iconKey),
                label: 'Categoria',
                value: category?.name ?? 'Scegli categoria',
                onTap: _chooseCategory,
              ),
              const Divider(height: 1),
              _PickerRow(
                icon: account?.isSystem == true
                    ? Icons.help_outline_rounded
                    : accountIcon(account?.iconKey ?? 'wallet'),
                label: 'Conto',
                value: account?.isSystem == true
                    ? 'Non assegnato'
                    : account?.name ?? 'Scegli conto',
                onTap: _chooseAccount,
              ),
            ] else ...[
              _PickerRow(
                icon: accountIcon(account?.iconKey ?? 'wallet'),
                label: 'Da',
                value: account?.name ?? 'Scegli conto',
                onTap: _chooseAccount,
              ),
              const Divider(height: 1),
              _PickerRow(
                icon: accountIcon(destination?.iconKey ?? 'wallet'),
                label: 'A',
                value: destination?.name ?? 'Scegli destinazione',
                onTap: () => _chooseAccount(destination: true),
              ),
              if (linkedGoal != null) ...[
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(categoryIcon(linkedGoal.iconKey)),
                  title: Text('Obiettivo: ${linkedGoal.name}'),
                  subtitle: const Text(
                    'Questo trasferimento aggiornerà automaticamente il progresso.',
                  ),
                ),
              ],
            ],
            const Divider(height: 1),
            _PickerRow(
              icon: Icons.calendar_today_outlined,
              label: 'Data',
              value: DateFormat('dd MMM yyyy, HH:mm', 'it_IT').format(date),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                  initialDate: date,
                );
                if (picked != null && mounted) {
                  setState(
                    () => date = DateTime(
                      picked.year,
                      picked.month,
                      picked.day,
                      date.hour,
                      date.minute,
                    ),
                  );
                  _scheduleSuggestion();
                }
              },
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => expanded = !expanded),
                icon: Icon(
                  expanded ? Icons.expand_less_rounded : Icons.add_rounded,
                ),
                label: Text(
                  expanded ? 'Nascondi dettagli' : 'Aggiungi dettagli',
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              child: expanded
                  ? Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: tag,
                                decoration: const InputDecoration(
                                  labelText: 'Aggiungi tag',
                                  hintText: 'Es. VacanzaRoma',
                                ),
                                onSubmitted: (_) => _addTag(),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Aggiungi tag',
                              onPressed: _addTag,
                              icon: const Icon(Icons.add_rounded),
                            ),
                          ],
                        ),
                        if (tags.isNotEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: tags
                                  .map(
                                    (value) => InputChip(
                                      label: Text('#$value'),
                                      onDeleted: () =>
                                          setState(() => tags.remove(value)),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Includi nelle statistiche'),
                          subtitle: const Text(
                            'Disattiva per movimenti eccezionali che non vuoi nelle analisi.',
                          ),
                          value: includeInAnalytics,
                          onChanged: (value) =>
                              setState(() => includeInAnalytics = value),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.receipt_long_outlined),
                          title: Text(
                            !receiptRemoved &&
                                    (receipt != null ||
                                        existingReceiptPath != null)
                                ? 'Ricevuta allegata'
                                : 'Aggiungi ricevuta',
                          ),
                          subtitle: const Text('Fotocamera o galleria'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: _chooseReceipt,
                        ),
                        if (widget.refundOfTransactionId != null)
                          const ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.replay_rounded),
                            title: Text(
                              'Questo movimento è un rimborso collegato',
                            ),
                          ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saving ? null : _save,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        widget.editing == null
                            ? Icons.add_rounded
                            : Icons.check_rounded,
                      ),
                label: Text(
                  widget.editing != null
                      ? 'Salva modifiche'
                      : switch (type) {
                          TransactionType.expense => 'Aggiungi spesa',
                          TransactionType.income => 'Aggiungi entrata',
                          TransactionType.transfer => 'Aggiungi trasferimento',
                        },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addTag() {
    final value = tag.text.trim().replaceFirst('#', '');
    if (value.isEmpty || tags.contains(value)) return;
    setState(() {
      tags.add(value);
      tag.clear();
    });
  }
}

class _VoiceListeningSheet extends StatefulWidget {
  const _VoiceListeningSheet({required this.voice, required this.onDevice});

  final VoiceInputService voice;
  final bool onDevice;

  @override
  State<_VoiceListeningSheet> createState() => _VoiceListeningSheetState();
}

class _VoiceListeningSheetState extends State<_VoiceListeningSheet> {
  String partial = '';
  String? error;
  bool ready = false;
  bool finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  Future<void> _begin() async {
    final initialized = await widget.voice.initialize(
      onStatus: (status) {
        if (!mounted) return;
        setState(() => ready = status == 'listening' || ready);
      },
      onError: (message) {
        if (mounted) setState(() => error = _friendlyError(message));
      },
    );
    if (!initialized) {
      if (mounted) {
        setState(
          () => error =
              'Permesso microfono negato o riconoscimento non disponibile.',
        );
      }
      return;
    }
    try {
      await widget.voice.listen(
        onDevice: widget.onDevice,
        onResult: (text, finalResult) {
          if (!mounted) return;
          setState(() => partial = text);
          if (finalResult && text.trim().isNotEmpty && !finished) {
            finished = true;
            Navigator.pop(context, text.trim());
          }
        },
      );
    } catch (exception) {
      if (mounted) setState(() => error = _friendlyError('$exception'));
    }
  }

  String _friendlyError(String raw) {
    final value = raw.toLowerCase();
    if (value.contains('permission'))
      return 'Il permesso microfono non è disponibile.';
    if (value.contains('no_match'))
      return 'Non ho riconosciuto parole. Puoi riprovare.';
    if (value.contains('network'))
      return 'Il recognizer di sistema non è disponibile offline.';
    return 'Riconoscimento vocale non riuscito. Puoi riprovare.';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.mic_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ready ? 'Ti ascolto' : 'Preparo il microfono…',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (widget.onDevice)
              const Chip(
                avatar: Icon(Icons.phonelink_lock_outlined, size: 16),
                label: Text('Sul dispositivo'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          label: partial.isEmpty ? 'In ascolto' : partial,
          child: Text(
            error ?? (partial.isEmpty ? 'Parla normalmente…' : '“$partial”'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () async {
                  await widget.voice.cancel();
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Annulla'),
              ),
            ),
            Expanded(
              child: FilledButton(
                onPressed: partial.trim().isEmpty
                    ? null
                    : () async {
                        final result = partial.trim();
                        await widget.voice.stop();
                        if (context.mounted && !finished) {
                          finished = true;
                          Navigator.pop(context, result);
                        }
                      },
                child: const Text('Termina'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: 10,
    leading: Icon(icon),
    title: Text(label),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(value, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
    onTap: onTap,
  );
}

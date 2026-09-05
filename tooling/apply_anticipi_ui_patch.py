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


# Public person picker helpers ---------------------------------------------------
p = 'lib/screens/advances_screen.dart'
s = read(p)
s = s.replace('_pickPerson', 'showFinancePersonPicker')
s = s.replace('_createPersonDialog', 'showFinancePersonCreator')
write(p, s)


# AppState: preserve Quick Add analytics choice for mixed expenses ---------------
p = 'lib/app_state.dart'
s = read(p)
s = replace_once(
    s,
    "    String? receiptPath,\n  }) async {\n    final id = await AdvanceService(database).createMixedExpense(",
    "    String? receiptPath,\n    bool includeInAnalytics = true,\n  }) async {\n    final id = await AdvanceService(database).createMixedExpense(",
    'mixed analytics param signature',
)
s = replace_once(
    s,
    "      receiptPath: receiptPath,\n    );\n    await refreshCore(includePlanning: true);",
    "      receiptPath: receiptPath,\n      includeInAnalytics: includeInAnalytics,\n    );\n    await refreshCore(includePlanning: true);",
    'mixed analytics param forwarding',
)
write(p, s)


# Quick Add ---------------------------------------------------------------------
p = 'lib/screens/quick_add_page.dart'
s = read(p)
s = replace_once(
    s,
    "import '../models/models.dart';\nimport '../models/quick_capture_models.dart';",
    "import '../models/advance_models.dart';\nimport '../models/models.dart';\nimport '../models/quick_capture_models.dart';",
    'quick add advance model import',
)
s = replace_once(
    s,
    "import 'account_screens.dart';",
    "import 'account_screens.dart';\nimport 'advances_screen.dart';",
    'quick add advances screen import',
)
s = replace_once(
    s,
    "  final tag = TextEditingController();\n  final amountFocus = FocusNode();",
    "  final tag = TextEditingController();\n  final advanceShare = TextEditingController();\n  final amountFocus = FocusNode();",
    'quick add share controller',
)
s = replace_once(
    s,
    "  SmartSuggestion? suggestion;\n",
    "  SmartSuggestion? suggestion;\n  bool advanceShareEnabled = false;\n  int? advancePersonId;\n  AdvanceMatchSuggestion? advanceMatch;\n  int? linkedAdvanceId;\n  bool advanceMatchDismissed = false;\n",
    'quick add advance state',
)
s = replace_once(
    s,
    "    amount.addListener(_scheduleSuggestion);\n    note.addListener(_scheduleSuggestion);",
    "    amount.addListener(_onDraftChanged);\n    note.addListener(_onDraftChanged);\n    advanceShare.addListener(_onDraftChanged);",
    'quick add listeners',
)
s = replace_once(
    s,
    "    amount.removeListener(_scheduleSuggestion);\n    note.removeListener(_scheduleSuggestion);\n    amount.dispose();\n    note.dispose();\n    tag.dispose();",
    "    amount.removeListener(_onDraftChanged);\n    note.removeListener(_onDraftChanged);\n    advanceShare.removeListener(_onDraftChanged);\n    amount.dispose();\n    note.dispose();\n    tag.dispose();\n    advanceShare.dispose();",
    'quick add dispose',
)
old_change = '''  void _changeType(TransactionType value) {
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
'''
new_change = '''  void _changeType(TransactionType value) {
    final state = AppScope.of(context);
    setState(() {
      type = value;
      suggestion = null;
      advanceMatch = null;
      linkedAdvanceId = null;
      advanceMatchDismissed = false;
      if (value != TransactionType.expense) {
        advanceShareEnabled = false;
        advanceShare.clear();
        advancePersonId = null;
      }
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

  void _onDraftChanged() {
    if (!mounted) return;
    setState(() {
      advanceMatchDismissed = false;
      if (linkedAdvanceId != null) linkedAdvanceId = null;
    });
    _scheduleSuggestion();
  }

  void _scheduleSuggestion() {
    if (!mounted || widget.editing != null || !_defaultsSet) return;
    _suggestionDebounce?.cancel();
    _suggestionDebounce = Timer(const Duration(milliseconds: 280), () async {
      if (!mounted) return;
      final state = AppScope.of(context);
      final parsed = Money.parseExpression(amount.text);
      final next = state.smartSuggestion(
        note: note.text,
        type: type,
        amount: parsed,
        date: date,
      );
      AdvanceMatchSuggestion? match;
      if (parsed != null &&
          parsed > 0 &&
          type != TransactionType.transfer &&
          !advanceShareEnabled &&
          linkedAdvanceId == null &&
          !advanceMatchDismissed) {
        match = await state.advanceMatchSuggestion(
          type: type,
          amount: parsed,
          note: note.text,
        );
      }
      if (mounted) {
        setState(() {
          suggestion = next;
          advanceMatch = match;
        });
      }
    });
  }
'''
s = replace_once(s, old_change, new_change, 'quick add schedule and type')
# Add advance matching banner before amount header
banner_marker = '''            Text(
              'IMPORTO',
'''
banner = '''            if (linkedAdvanceId != null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.handshake_outlined),
                title: const Text('Collegato a un anticipo'),
                subtitle: const Text(
                  'Verrà registrato come rimborso/restituzione, non come entrata o spesa.',
                ),
                trailing: TextButton(
                  onPressed: () => setState(() => linkedAdvanceId = null),
                  child: const Text('Annulla'),
                ),
              ),
              const SizedBox(height: 8),
            ] else if (advanceMatch case final match?) ...[
              Builder(
                builder: (context) {
                  final person = state.personById(match.personId);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.link_rounded),
                    title: Text(
                      'Potrebbe essere il rimborso dell’anticipo di ${person?.name ?? 'questa persona'}',
                    ),
                    subtitle: Text(match.reason),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          onPressed: () => setState(() {
                            advanceMatch = null;
                            advanceMatchDismissed = true;
                          }),
                          child: const Text('Non è questo'),
                        ),
                        FilledButton.tonal(
                          onPressed: () => setState(() {
                            linkedAdvanceId = match.advanceId;
                            advanceMatch = null;
                            advanceMatchDismissed = true;
                          }),
                          child: const Text('Collega'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
'''
s = replace_once(s, banner_marker, banner + banner_marker, 'quick add match banner')
# Mixed expense section after account picker
account_block = '''              _PickerRow(
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
'''
mixed_block = '''              _PickerRow(
                icon: account?.isSystem == true
                    ? Icons.help_outline_rounded
                    : accountIcon(account?.iconKey ?? 'wallet'),
                label: 'Conto',
                value: account?.isSystem == true
                    ? 'Non assegnato'
                    : account?.name ?? 'Scegli conto',
                onTap: _chooseAccount,
              ),
              if (type == TransactionType.expense && widget.editing == null) ...[
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.group_outlined),
                  title: const Text('Parte di questa spesa è per qualcun altro'),
                  subtitle: const Text(
                    'Solo la tua quota verrà conteggiata in spese, categorie e budget.',
                  ),
                  value: advanceShareEnabled,
                  onChanged: linkedAdvanceId != null
                      ? null
                      : (value) => setState(() {
                            advanceShareEnabled = value;
                            advanceMatch = null;
                            if (!value) {
                              advanceShare.clear();
                              advancePersonId = null;
                            }
                          }),
                ),
                if (advanceShareEnabled) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline_rounded),
                    title: const Text('Anticipato a'),
                    subtitle: Text(
                      state.personById(advancePersonId)?.name ?? 'Scegli o crea una persona',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      final picked = await showFinancePersonPicker(
                        context,
                        allowCreate: true,
                      );
                      if (picked != null && mounted) {
                        setState(() => advancePersonId = picked);
                      }
                    },
                  ),
                  TextField(
                    controller: advanceShare,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Quota anticipata',
                      suffixText: '€',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final total = Money.parseExpression(amount.text) ?? 0;
                      final advanced = Money.parseExpression(advanceShare.text) ?? 0;
                      final personal = (total - advanced).clamp(0, double.infinity);
                      return FlatMetric(
                        label: 'La mia parte',
                        value: moneyFor(state, personal),
                        icon: Icons.person_rounded,
                      );
                    },
                  ),
                ],
              ],
            ] else ...[
'''
s = replace_once(s, account_block, mixed_block, 'quick add mixed UI')
# Save validation tweaks
s = replace_once(
    s,
    '    if (type != TransactionType.transfer && categoryId == null) {\n      return _error(\'Scegli o crea una categoria.\');\n    }',
    "    if (linkedAdvanceId == null &&\n        type != TransactionType.transfer &&\n        categoryId == null) {\n      return _error('Scegli o crea una categoria.');\n    }\n    double? mixedAdvanceAmount;\n    if (advanceShareEnabled && widget.editing == null) {\n      mixedAdvanceAmount = Money.parseExpression(advanceShare.text);\n      if (type != TransactionType.expense ||\n          mixedAdvanceAmount == null ||\n          mixedAdvanceAmount <= 0 ||\n          mixedAdvanceAmount >= parsed) {\n        return _error('La quota anticipata deve essere maggiore di 0 e minore del totale.');\n      }\n      if (advancePersonId == null) {\n        return _error('Scegli la persona a cui hai anticipato i soldi.');\n      }\n      if (state.accountById(accountId)?.isSystem == true) {\n        return _error('Una spesa condivisa richiede un conto reale.');\n      }\n    }",
    'quick add mixed validation',
)
old_create = '''      if (editing == null) {
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
'''
new_create = '''      if (editing == null) {
        if (linkedAdvanceId != null) {
          await state.recordAdvanceSettlement(
            advanceId: linkedAdvanceId!,
            amount: parsed,
            accountId: accountId!,
            date: date,
            note: note.text.trim().isEmpty ? null : note.text.trim(),
          );
        } else if (advanceShareEnabled && mixedAdvanceAmount != null) {
          await state.createMixedAdvanceExpense(
            personId: advancePersonId!,
            totalAmount: parsed,
            personalAmount: parsed - mixedAdvanceAmount,
            advanceAmount: mixedAdvanceAmount,
            accountId: accountId!,
            categoryId: categoryId!,
            date: date,
            note: note.text.trim().isEmpty ? null : note.text.trim(),
            tags: tags,
            receiptPath: managedReceipt,
            includeInAnalytics: includeInAnalytics,
          );
        } else {
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
        }
      } else {
'''
s = replace_once(s, old_create, new_create, 'quick add create branch')
write(p, s)


# App shell: expose pure Anticipo from the + quick menu --------------------------
p = 'lib/screens/app_shell.dart'
s = read(p)
s = replace_once(s, "import 'account_screens.dart';", "import 'account_screens.dart';\nimport 'advances_screen.dart';", 'app shell import')
menu_marker = '''            if (presets.isNotEmpty) ...[
'''
advance_menu = '''            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.handshake_outlined),
              title: const Text('Anticipo'),
              subtitle: const Text('Soldi da ricevere o da restituire'),
              onTap: () => Navigator.pop(sheetContext, 'advance'),
            ),
'''
s = replace_once(s, menu_marker, advance_menu + menu_marker, 'app shell advance menu')
s = replace_once(
    s,
    '''    if (choice is QuickPreset) {
      await _openQuick(choice.type, preset: choice);
    } else if (choice is TransactionType) {
      await _openQuick(choice);
    }
''',
    '''    if (choice == 'advance') {
      await showAdvanceEditor(context);
    } else if (choice is QuickPreset) {
      await _openQuick(choice.type, preset: choice);
    } else if (choice is TransactionType) {
      await _openQuick(choice);
    }
''',
    'app shell choice',
)
write(p, s)


# Home: compact Anticipi insight -------------------------------------------------
p = 'lib/screens/home_screen.dart'
s = read(p)
s = replace_once(s, "import 'account_screens.dart';", "import 'account_screens.dart';\nimport 'advances_screen.dart';", 'home advances import')
s = replace_once(
    s,
    '''    final state = AppScope.of(context);
    final income = state.monthTotal(TransactionType.income);''',
    '''    final state = AppScope.of(context);
    final income = state.monthTotal(TransactionType.income);''',
    'home stable anchor',
)
# Find existing Per te section in dense home
old_insight = '''          if (_smartInsight(state) case final insight?) ...[
            const SizedBox(height: 28),
            const SectionTitle('Per te'),
            _InsightLine(insight: insight),
          ],
'''
new_insight = '''          if (state.advanceReceivableCents > 0 ||
              state.advancePayableCents > 0 ||
              _smartInsight(state) != null) ...[
            const SizedBox(height: 28),
            const SectionTitle('Per te'),
            if (state.advanceReceivableCents > 0 || state.advancePayableCents > 0)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.handshake_outlined),
                title: const Text('Anticipi'),
                subtitle: Text(
                  '${moneyFor(state, Money.fromCents(state.advanceReceivableCents))} da ricevere · '
                  '${moneyFor(state, Money.fromCents(state.advancePayableCents))} da restituire',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdvancesScreen()),
                ),
              ),
            if (_smartInsight(state) case final insight?)
              _InsightLine(insight: insight),
          ],
'''
if old_insight in s:
    s = replace_once(s, old_insight, new_insight, 'home insight')
else:
    raise RuntimeError('home insight: expected dense Home smart insight block')
write(p, s)


# Canonical analytics ------------------------------------------------------------
p = 'lib/screens/canonical_shell.dart'
s = read(p)
s = replace_once(s, "import 'account_management_screen.dart';", "import 'account_management_screen.dart';\nimport 'advances_screen.dart';", 'analytics advances import')
s = replace_once(
    s,
    '''    final expense = state.periodTotal(TransactionType.expense, from, to);
    final previousExpense = state.periodTotal(''',
    '''    final expense = state.periodTotal(TransactionType.expense, from, to);
    final advanceSettled = state.advanceSettledInPeriodCents(from, to);
    final previousExpense = state.periodTotal(''',
    'analytics settlement total',
)
s = replace_once(
    s,
    ".fold<double>(0, (sum, s) => sum + s.amount);",
    ".fold<double>(\n                0,\n                (sum, s) => sum + state.analyticsAmountForSplit(item.id, s),\n              );",
    'analytics mixed split scaling',
)
analytics_marker = '''          const SizedBox(height: 32),
          const SectionTitle('Dove stai spendendo'),
'''
advance_analytics = '''          const SizedBox(height: 32),
          SectionTitle(
            'Anticipi',
            trailing: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdvancesScreen()),
              ),
              child: const Text('Apri'),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Da ricevere',
                  value: moneyFor(
                    state,
                    Money.fromCents(state.advanceReceivableCents),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _Metric(
                  label: 'Da restituire',
                  value: moneyFor(
                    state,
                    Money.fromCents(state.advancePayableCents),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _Metric(
                  label: 'Regolati',
                  value: moneyFor(state, Money.fromCents(advanceSettled)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const SectionTitle('Dove stai spendendo'),
'''
s = replace_once(s, analytics_marker, advance_analytics, 'analytics advance section')
# Money is now needed directly in this file
s = replace_once(s, "import '../app_state.dart';\nimport '../main.dart';", "import '../app_state.dart';\nimport '../core/money.dart';\nimport '../main.dart';", 'analytics money import')
write(p, s)


# Movimenti ---------------------------------------------------------------------
p = 'lib/screens/root_screen.dart'
s = read(p)
s = replace_once(s, "import 'account_screens.dart';", "import 'account_screens.dart';\nimport 'advances_screen.dart';", 'movements advances import')
s = replace_once(s, '  bool withReceiptOnly = false;\n  late bool unassignedOnly;', '  bool withReceiptOnly = false;\n  bool advancesOnly = false;\n  late bool unassignedOnly;', 'movements advance filter field')
s = replace_once(
    s,
    '      if (withReceiptOnly && item.receiptPath?.isNotEmpty != true) return false;\n      if (unassignedOnly && item.accountId != unassignedId) return false;',
    '      if (withReceiptOnly && item.receiptPath?.isNotEmpty != true) return false;\n      if (advancesOnly && !state.isAdvanceProtectedTransaction(item)) return false;\n      if (unassignedOnly && item.accountId != unassignedId) return false;',
    'movements advance filter apply',
)
s = replace_once(s, '      withReceiptOnly ||\n      unassignedOnly ||', '      withReceiptOnly ||\n      advancesOnly ||\n      unassignedOnly ||', 'movements hasFilters')
s = replace_once(s, '      withReceiptOnly = false;\n      unassignedOnly = false;', '      withReceiptOnly = false;\n      advancesOnly = false;\n      unassignedOnly = false;', 'movements clear')
s = replace_once(
    s,
    '                  if (unassignedOnly)\n                    const Padding(',
    "                  if (advancesOnly)\n                    const Padding(\n                      padding: EdgeInsets.only(right: 8),\n                      child: Chip(label: Text('Anticipi')),\n                    ),\n                  if (unassignedOnly)\n                    const Padding(",
    'movements filter chip',
)
s = replace_once(s, '    var draftReceipt = withReceiptOnly;\n    var draftUnassigned = unassignedOnly;', '    var draftReceipt = withReceiptOnly;\n    var draftAdvances = advancesOnly;\n    var draftUnassigned = unassignedOnly;', 'movements draft filter')
s = replace_once(
    s,
    '''                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Solo Non assegnati'),''',
    '''                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.handshake_outlined),
                    title: const Text('Solo Anticipi'),
                    subtitle: const Text('Include anticipi, rimborsi e restituzioni.'),
                    value: draftAdvances,
                    onChanged: (value) =>
                        setSheetState(() => draftAdvances = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Solo Non assegnati'),''',
    'movements filter switch',
)
s = replace_once(
    s,
    '                              withReceiptOnly = draftReceipt;\n                              unassignedOnly = draftUnassigned;',
    '                              withReceiptOnly = draftReceipt;\n                              advancesOnly = draftAdvances;\n                              unassignedOnly = draftUnassigned;',
    'movements apply advance filter',
)
# Enrich selectable row with advance semantics
build_anchor = '''    final category = state.categoryById(item.categoryId);
    final account = state.accountById(item.accountId);
    return ListTile(
'''
build_enriched = '''    final category = state.categoryById(item.categoryId);
    final account = state.accountById(item.accountId);
    final sourceAdvance = state.advanceForSourceTransaction(item.id);
    final settlementAdvance = state.advanceForSettlementTransaction(item.id);
    final linkedAdvance = sourceAdvance ?? settlementAdvance;
    final person = state.personById(linkedAdvance?.personId);
    final protected = state.isAdvanceProtectedTransaction(item);
    final advanceTitle = switch (item.kind) {
      'advance_origin' when linkedAdvance?.direction.name == 'receivable' =>
        'Anticipo a ${person?.name ?? 'persona'}',
      'advance_origin' => 'Anticipo da ${person?.name ?? 'persona'}',
      'advance_settlement' when linkedAdvance?.direction.name == 'receivable' =>
        'Rimborso da ${person?.name ?? 'persona'}',
      'advance_settlement' => 'Restituzione a ${person?.name ?? 'persona'}',
      'advance_writeoff' => 'Anticipo non recuperato',
      'advance_forgiven_income' => 'Anticipo condonato',
      _ => null,
    };
    return ListTile(
'''
s = replace_once(s, build_anchor, build_enriched, 'movements tile advance state')
s = replace_once(
    s,
    '''      title: Text(
        item.type == TransactionType.transfer
            ? 'Trasferimento'
            : category?.name ?? 'Senza categoria',''',
    '''      title: Text(
        advanceTitle ??
            (item.type == TransactionType.transfer
                ? 'Trasferimento'
                : category?.name ?? 'Senza categoria'),''',
    'movements advance title',
)
s = replace_once(
    s,
    '''      subtitle: Text(
        '${account?.isSystem == true ? 'Non assegnato' : account?.name ?? 'Conto'} · ${DateFormat('dd MMM, HH:mm', 'it_IT').format(item.date)}${item.note?.isNotEmpty == true ? ' · ${item.note}' : ''}',
        maxLines: 2,''',
    '''      subtitle: Text(
        [
          account?.isSystem == true ? 'Non assegnato' : account?.name ?? 'Conto',
          DateFormat('dd MMM, HH:mm', 'it_IT').format(item.date),
          if (item.kind == 'mixed_advance' && sourceAdvance != null)
            'Include ${moneyFor(state, Money.fromCents(sourceAdvance.originalAmountCents))} anticipati a ${person?.name ?? 'persona'}',
          if (linkedAdvance != null && item.kind == 'advance_settlement')
            '${moneyFor(state, Money.fromCents(state.advanceRemainingCents(linkedAdvance.id)))} residui',
          if (item.note?.isNotEmpty == true) item.note!,
        ].join(' · '),
        maxLines: 2,''',
    'movements advance subtitle',
)
# Money import for root screen
s = replace_once(s, "import '../app_state.dart';\nimport '../main.dart';", "import '../app_state.dart';\nimport '../core/money.dart';\nimport '../main.dart';", 'movements money import')
s = replace_once(s, '      onLongPress: onSelect,\n      onTap: selectionMode\n          ? onSelect\n          : () => Navigator.push(', '      onLongPress: protected ? null : onSelect,\n      onTap: selectionMode\n          ? (protected ? null : onSelect)\n          : () => Navigator.push(', 'movements protect selection')
# Route pure advance rows to Advance detail, keep mixed expense as transaction detail
route_old = '''              MaterialPageRoute(
                builder: (_) => TransactionDetailPage(transactionId: item.id),
              ),
            ),
'''
route_new = '''              MaterialPageRoute(
                builder: (_) => linkedAdvance != null && item.kind != 'mixed_advance'
                    ? AdvanceDetailScreen(advanceId: linkedAdvance.id)
                    : TransactionDetailPage(transactionId: item.id),
              ),
            ),
'''
# first occurrence after selectable tile; may also exist elsewhere, use last-ish one by rfind
idx = s.rfind(route_old)
if idx == -1:
    raise RuntimeError('movements advance route: no route block')
s = s[:idx] + route_new + s[idx + len(route_old):]
write(p, s)


# Transaction rows/details -------------------------------------------------------
p = 'lib/screens/transaction_screens.dart'
s = read(p)
s = replace_once(s, "import 'quick_add_page.dart';", "import 'advances_screen.dart';\nimport 'quick_add_page.dart';", 'transaction detail advance import')
# TransactionListTile build enrichment
anchor = '''    final category = state.categoryById(item.categoryId);
    final source = state.accountById(item.accountId);
    final destination = state.accountById(item.toAccountId);
    return ListTile(
'''
enriched = '''    final category = state.categoryById(item.categoryId);
    final source = state.accountById(item.accountId);
    final destination = state.accountById(item.toAccountId);
    final sourceAdvance = state.advanceForSourceTransaction(item.id);
    final settlementAdvance = state.advanceForSettlementTransaction(item.id);
    final linkedAdvance = sourceAdvance ?? settlementAdvance;
    final person = state.personById(linkedAdvance?.personId);
    final advanceTitle = switch (item.kind) {
      'advance_origin' when linkedAdvance?.direction.name == 'receivable' =>
        'Anticipo a ${person?.name ?? 'persona'}',
      'advance_origin' => 'Anticipo da ${person?.name ?? 'persona'}',
      'advance_settlement' when linkedAdvance?.direction.name == 'receivable' =>
        'Rimborso da ${person?.name ?? 'persona'}',
      'advance_settlement' => 'Restituzione a ${person?.name ?? 'persona'}',
      'advance_writeoff' => 'Anticipo non recuperato',
      'advance_forgiven_income' => 'Anticipo condonato',
      _ => null,
    };
    return ListTile(
'''
s = replace_once(s, anchor, enriched, 'transaction list advance state')
s = replace_once(
    s,
    '''      title: Text(
        item.type == TransactionType.transfer
            ? 'Trasferimento'
            : category?.name ?? 'Senza categoria',''',
    '''      title: Text(
        advanceTitle ??
            (item.type == TransactionType.transfer
                ? 'Trasferimento'
                : category?.name ?? 'Senza categoria'),''',
    'transaction list advance title',
)
s = replace_once(
    s,
    '''      onTap: onTap ??
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransactionDetailPage(transactionId: item.id),
            ),
          ),''',
    '''      onTap: onTap ??
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => linkedAdvance != null && item.kind != 'mixed_advance'
                  ? AdvanceDetailScreen(advanceId: linkedAdvance.id)
                  : TransactionDetailPage(transactionId: item.id),
            ),
          ),''',
    'transaction list advance route',
)
# Detail state after account/category declarations
s = replace_once(
    s,
    '''    final category = state.categoryById(item.categoryId);
    final account = state.accountById(item.accountId);
    final destination = state.accountById(item.toAccountId);
    final splits = state.splitsFor(item.id);''',
    '''    final category = state.categoryById(item.categoryId);
    final account = state.accountById(item.accountId);
    final destination = state.accountById(item.toAccountId);
    final splits = state.splitsFor(item.id);
    final sourceAdvance = state.advanceForSourceTransaction(item.id);
    final settlementAdvance = state.advanceForSettlementTransaction(item.id);
    final linkedAdvance = sourceAdvance ?? settlementAdvance;
    final protected = state.isAdvanceProtectedTransaction(item);''',
    'transaction detail advance state',
)
s = replace_once(
    s,
    '''        actions: [
          PopupMenuButton<String>(''',
    '''        actions: [
          if (linkedAdvance != null)
            IconButton(
              tooltip: 'Apri anticipo',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdvanceDetailScreen(advanceId: linkedAdvance.id),
                ),
              ),
              icon: const Icon(Icons.handshake_outlined),
            ),
          if (!protected)
            PopupMenuButton<String>(''',
    'transaction detail protect menu',
)
# Add linked advance metric before note section
metric_marker = '''          if (item.note?.isNotEmpty == true) ...[
'''
metric = '''          if (linkedAdvance != null) ...[
            const SizedBox(height: 16),
            FlatMetric(
              label: 'Anticipo',
              value: state.personById(linkedAdvance.personId)?.name ?? 'Persona',
              icon: Icons.handshake_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdvanceDetailScreen(advanceId: linkedAdvance.id),
                ),
              ),
            ),
          ],
'''
s = replace_once(s, metric_marker, metric + metric_marker, 'transaction detail advance metric')
write(p, s)


# Settings ----------------------------------------------------------------------
p = 'lib/screens/personal_settings_screen.dart'
s = read(p)
s = replace_once(s, "import 'android_widgets_screen.dart';", "import 'android_widgets_screen.dart';\nimport 'advances_screen.dart';", 'settings advances import')
s = replace_once(
    s,
    '''          const SectionTitle('Organizzazione'),
          _Link(
            icon: Icons.category_outlined,''',
    '''          const SectionTitle('Organizzazione'),
          _Link(
            icon: Icons.handshake_outlined,
            title: 'Anticipi',
            subtitle:
                '${state.advances.where((item) => item.closedKind == null && state.advanceRemainingCents(item.id) > 0).length} aperti · persone e storico',
            onTap: () => _open(context, const AdvancesScreen()),
          ),
          _Link(
            icon: Icons.category_outlined,''',
    'settings anticipi link',
)
s = s.replace(
    "subtitle: 'Scadenze, budget, obiettivi e cash-flow',",
    "subtitle: 'Scadenze, anticipi, budget, obiettivi e cash-flow',",
    1,
)
write(p, s)


# Backup manifest counts ---------------------------------------------------------
p = 'lib/services/backup_service.dart'
s = read(p)
s = replace_once(
    s,
    '''    required this.categories,
    required this.attachments,
    required this.sizeBytes,''',
    '''    required this.categories,
    required this.attachments,
    required this.sizeBytes,
    this.people = 0,
    this.advances = 0,''',
    'backup preview ctor',
)
s = replace_once(
    s,
    '''  final int categories;
  final int attachments;
  final int sizeBytes;''',
    '''  final int categories;
  final int attachments;
  final int sizeBytes;
  final int people;
  final int advances;''',
    'backup preview fields',
)
s = replace_once(
    s,
    "    final categoryCount = await _count(database.db, 'categories');\n",
    "    final categoryCount = await _count(database.db, 'categories');\n    final peopleCount = await _count(database.db, 'finance_people');\n    final advanceCount = await _count(database.db, 'advances');\n",
    'backup counts query',
)
s = replace_once(
    s,
    "          'categories': categoryCount,\n          'attachments': files.length,",
    "          'categories': categoryCount,\n          'attachments': files.length,\n          'people': peopleCount,\n          'advances': advanceCount,",
    'backup manifest counts',
)
s = replace_once(
    s,
    '''      categories: _countFromManifest(json, 'categories'),
      attachments: _countFromManifest(json, 'attachments'),
      sizeBytes: file.lengthSync(),''',
    '''      categories: _countFromManifest(json, 'categories'),
      attachments: _countFromManifest(json, 'attachments'),
      sizeBytes: file.lengthSync(),
      people: _countFromManifest(json, 'people'),
      advances: _countFromManifest(json, 'advances'),''',
    'backup preview manifest read',
)
write(p, s)

print('Anticipi UI patch applied.')

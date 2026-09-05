import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../core/money.dart';
import '../main.dart';
import '../models/advance_models.dart';
import '../models/models.dart';
import '../widgets/ui_helpers.dart';

class AdvancesScreen extends StatelessWidget {
  const AdvancesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final open = state.advances
        .where((item) => item.closedKind == null)
        .toList();
    final closed = state.advances
        .where(
          (item) =>
              item.closedKind != null ||
              state.advanceRemainingCents(item.id) == 0,
        )
        .toList();
    final receivable = open
        .where((item) => item.direction == AdvanceDirection.receivable)
        .toList();
    final payable = open
        .where((item) => item.direction == AdvanceDirection.payable)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anticipi'),
        actions: [
          IconButton(
            tooltip: 'Gestisci persone',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FinancePeopleScreen()),
            ),
            icon: const Icon(Icons.people_outline_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAdvanceEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Anticipo'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FlatMetric(
                  label: 'DA RICEVERE',
                  value: state.hideBalance
                      ? '••••'
                      : moneyFor(
                          state,
                          Money.fromCents(state.advanceReceivableCents),
                        ),
                  icon: Icons.call_received_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FlatMetric(
                  label: 'DA RESTITUIRE',
                  value: state.hideBalance
                      ? '••••'
                      : moneyFor(
                          state,
                          Money.fromCents(state.advancePayableCents),
                        ),
                  icon: Icons.call_made_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FlatMetric(
            label: 'SALDO NETTO ANTICIPI',
            value: state.hideBalance
                ? '••••'
                : moneyFor(state, Money.fromCents(state.advanceNetCents)),
            icon: Icons.balance_rounded,
          ),
          const SizedBox(height: 32),
          const SectionTitle('Da ricevere'),
          if (receivable.isEmpty)
            const Text('Nessun anticipo da ricevere.')
          else
            ...receivable.map((item) => _AdvanceRow(advance: item)),
          const SizedBox(height: 32),
          const SectionTitle('Da restituire'),
          if (payable.isEmpty)
            const Text('Nessun anticipo da restituire.')
          else
            ...payable.map((item) => _AdvanceRow(advance: item)),
          const SizedBox(height: 32),
          const SectionTitle('Saldati e storico'),
          if (closed.isEmpty)
            const Text('Lo storico comparirà qui quando chiudi un anticipo.')
          else
            ...closed
                .take(30)
                .map((item) => _AdvanceRow(advance: item, closed: true)),
        ],
      ),
    );
  }
}

class _AdvanceRow extends StatelessWidget {
  const _AdvanceRow({required this.advance, this.closed = false});

  final Advance advance;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final person = state.personById(advance.personId);
    final remaining = state.advanceRemainingCents(advance.id);
    final settled = advance.originalAmountCents - remaining;
    final status = state.advanceStatus(advance);
    final due = advance.dueDate;
    final statusText = switch (status) {
      AdvanceStatus.open => advance.direction.label,
      AdvanceStatus.partial =>
        advance.direction == AdvanceDirection.receivable
            ? 'Parziale · da ricevere'
            : 'Parziale · da restituire',
      AdvanceStatus.overdue => 'Scaduto',
      AdvanceStatus.settled => 'Saldato',
      AdvanceStatus.cancelled => 'Annullato',
      AdvanceStatus.writtenOff => 'Non recuperato',
      AdvanceStatus.forgiven => 'Condonato',
    };
    return Semantics(
      button: true,
      label:
          '${person?.name ?? 'Persona'}, ${Money.fromCents(remaining).toStringAsFixed(2)} euro ${advance.direction.label.toLowerCase()}, $statusText',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        minVerticalPadding: 10,
        leading: Icon(
          advance.direction == AdvanceDirection.receivable
              ? Icons.call_received_rounded
              : Icons.call_made_rounded,
        ),
        title: Text(
          person?.name ?? 'Persona',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            if (closed)
              statusText
            else
              '${moneyFor(state, Money.fromCents(remaining))} ${advance.direction.label.toLowerCase()}',
            if (settled > 0 && remaining > 0)
              '${moneyFor(state, Money.fromCents(settled))} regolati su ${moneyFor(state, advance.originalAmount)}',
            if (due != null && remaining > 0) _dueLabel(due),
          ].join(' · '),
        ),
        trailing: closed
            ? const Icon(Icons.chevron_right_rounded)
            : Text(
                state.hideBalance
                    ? '••••'
                    : moneyFor(state, Money.fromCents(remaining)),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdvanceDetailScreen(advanceId: advance.id),
          ),
        ),
      ),
    );
  }

  String _dueLabel(DateTime due) {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final target = DateTime(due.year, due.month, due.day);
    final diff = target.difference(day).inDays;
    if (diff < 0) return 'Scaduto da ${diff.abs()} g';
    if (diff == 0) return 'Scade oggi';
    if (diff == 1) return 'Scade domani';
    return 'Scade tra $diff giorni';
  }
}

class AdvanceDetailScreen extends StatelessWidget {
  const AdvanceDetailScreen({required this.advanceId, super.key});

  final int advanceId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final advance = state.advances
        .where((item) => item.id == advanceId)
        .firstOrNull;
    if (advance == null) {
      return const Scaffold(body: Center(child: Text('Anticipo non trovato')));
    }
    final person = state.personById(advance.personId);
    final remaining = state.advanceRemainingCents(advance.id);
    final settlements = state.settlementsForAdvance(advance.id);
    final sourceAccount = state.accountById(advance.sourceAccountId);
    final status = state.advanceStatus(advance);
    final canSettle = advance.closedKind == null && remaining > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(person?.name ?? 'Anticipo'),
        actions: [
          IconButton(
            tooltip: 'Promemoria e scadenza',
            onPressed: canSettle ? () => _editDates(context, advance) : null,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Text(
            advance.direction.label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          Text(
            state.hideBalance
                ? '••••'
                : moneyFor(state, Money.fromCents(remaining)),
            style: Theme.of(context).textTheme.displaySmall,
          ),
          Text(
            remaining == 0
                ? 'Saldato su ${moneyFor(state, advance.originalAmount)}'
                : 'residui su ${moneyFor(state, advance.originalAmount)}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          FlatMetric(
            label: 'Stato',
            value: _statusLabel(status),
            icon: status == AdvanceStatus.overdue
                ? Icons.warning_amber_rounded
                : Icons.info_outline_rounded,
          ),
          if (advance.dueDate != null) ...[
            const Divider(height: 1),
            FlatMetric(
              label: 'Scadenza',
              value: DateFormat(
                'd MMMM yyyy',
                'it_IT',
              ).format(advance.dueDate!),
              icon: Icons.event_outlined,
            ),
          ],
          if (advance.reminderDate != null) ...[
            const Divider(height: 1),
            FlatMetric(
              label: 'Promemoria',
              value: DateFormat(
                'd MMMM yyyy',
                'it_IT',
              ).format(advance.reminderDate!),
              icon: Icons.notifications_none_rounded,
            ),
          ],
          const SizedBox(height: 28),
          const SectionTitle('Cronologia'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add_circle_outline_rounded),
            title: Text(
              advance.direction == AdvanceDirection.receivable
                  ? 'Anticipati ${moneyFor(state, advance.originalAmount)}'
                  : 'Ricevuti ${moneyFor(state, advance.originalAmount)}',
            ),
            subtitle: Text(
              [
                DateFormat('d MMM yyyy', 'it_IT').format(advance.createdAt),
                if (sourceAccount != null) sourceAccount.name,
              ].join(' · '),
            ),
          ),
          ...settlements.map((settlement) {
            final account = state.accountById(settlement.accountId);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline_rounded),
              title: Text(
                advance.direction == AdvanceDirection.receivable
                    ? 'Ricevuti ${moneyFor(state, settlement.amount)}'
                    : 'Restituiti ${moneyFor(state, settlement.amount)}',
              ),
              subtitle: Text(
                [
                  DateFormat('d MMM yyyy', 'it_IT').format(settlement.date),
                  if (account != null) account.name,
                  if (settlement.note?.isNotEmpty == true) settlement.note!,
                ].join(' · '),
              ),
            );
          }),
          if (advance.note?.isNotEmpty == true) ...[
            const SizedBox(height: 24),
            const SectionTitle('Nota'),
            Text(advance.note!),
          ],
          if (canSettle) ...[
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => showSettlementEditor(context, advance),
              icon: const Icon(Icons.check_rounded),
              label: Text(
                advance.direction == AdvanceDirection.receivable
                    ? 'Registra rimborso'
                    : 'Registra restituzione',
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _closeWithoutRecovery(context, advance),
              child: Text(
                advance.direction == AdvanceDirection.receivable
                    ? 'Non verrà restituito'
                    : 'È stato condonato',
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(AdvanceStatus status) => switch (status) {
    AdvanceStatus.open => 'Aperto',
    AdvanceStatus.partial => 'Parzialmente regolato',
    AdvanceStatus.overdue => 'Scaduto',
    AdvanceStatus.settled => 'Saldato',
    AdvanceStatus.cancelled => 'Annullato',
    AdvanceStatus.writtenOff => 'Non recuperato',
    AdvanceStatus.forgiven => 'Condonato',
  };

  Future<void> _editDates(BuildContext context, Advance advance) async {
    final state = AppScope.of(context);
    DateTime? due = advance.dueDate;
    DateTime? reminder = advance.reminderDate;
    final result = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Promemoria', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Scadenza'),
                subtitle: Text(
                  due == null
                      ? 'Nessuna'
                      : DateFormat('d MMM yyyy', 'it_IT').format(due!),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    initialDate:
                        due ?? DateTime.now().add(const Duration(days: 7)),
                  );
                  if (picked != null) setSheetState(() => due = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_none_rounded),
                title: const Text('Data promemoria'),
                subtitle: Text(
                  reminder == null
                      ? 'Nessuna'
                      : DateFormat('d MMM yyyy', 'it_IT').format(reminder!),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    initialDate:
                        reminder ??
                        due ??
                        DateTime.now().add(const Duration(days: 7)),
                  );
                  if (picked != null) setSheetState(() => reminder = picked);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => setSheetState(() {
                      due = null;
                      reminder = null;
                    }),
                    child: const Text('Rimuovi date'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Salva'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (result == true) {
      await state.updateAdvanceDates(
        advance.id,
        dueDate: due,
        reminderDate: reminder,
      );
    }
  }

  Future<void> _closeWithoutRecovery(
    BuildContext context,
    Advance advance,
  ) async {
    final state = AppScope.of(context);
    final remaining = state.advanceRemainingCents(advance.id);
    if (remaining <= 0) return;
    final recognize = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          advance.direction == AdvanceDirection.receivable
              ? 'Non verrà restituito?'
              : 'Anticipo condonato?',
        ),
        content: Text(
          advance.direction == AdvanceDirection.receivable
              ? 'Restano ${moneyFor(state, Money.fromCents(remaining))}. Vuoi registrarli come una tua spesa?'
              : 'Restano ${moneyFor(state, Money.fromCents(remaining))}. Vuoi registrarli come una tua entrata?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Chiudi senza statistica'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Registra'),
          ),
        ],
      ),
    );
    if (recognize == null || !context.mounted) return;
    int? categoryId;
    int? accountId;
    if (recognize) {
      final type = advance.direction == AdvanceDirection.receivable
          ? TransactionType.expense
          : TransactionType.income;
      categoryId = await _pickCategory(context, type);
      if (categoryId == null || !context.mounted) return;
      accountId = await _pickAccount(context);
      if (accountId == null || !context.mounted) return;
    }
    await state.closeAdvanceWithoutRecovery(
      advance.id,
      recognizeInAnalytics: recognize,
      categoryId: categoryId,
      accountId: accountId,
    );
    if (context.mounted) Navigator.pop(context);
  }
}

Future<void> showAdvanceEditor(
  BuildContext context, {
  AdvanceDirection? initialDirection,
}) async {
  final state = AppScope.of(context);
  var direction = initialDirection ?? AdvanceDirection.receivable;
  final amount = TextEditingController();
  final note = TextEditingController();
  int? personId = state.people.where((item) => !item.archived).firstOrNull?.id;
  int? accountId = state.activeAccounts
      .where((item) => !item.isLocked)
      .firstOrNull
      ?.id;
  DateTime? dueDate;
  DateTime? reminderDate;

  final saved = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nuovo anticipo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              SegmentedButton<AdvanceDirection>(
                segments: const [
                  ButtonSegment(
                    value: AdvanceDirection.receivable,
                    icon: Icon(Icons.call_received_rounded),
                    label: Text('Ho anticipato'),
                  ),
                  ButtonSegment(
                    value: AdvanceDirection.payable,
                    icon: Icon(Icons.call_made_rounded),
                    label: Text('Mi hanno anticipato'),
                  ),
                ],
                selected: {direction},
                onSelectionChanged: (value) =>
                    setSheetState(() => direction = value.first),
              ),
              const SizedBox(height: 6),
              Text(
                direction.actionSubtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Importo',
                  suffixText: '€',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('Persona'),
                subtitle: Text(
                  state.personById(personId)?.name ?? 'Scegli o crea',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final picked = await _pickPerson(context, allowCreate: true);
                  if (picked != null) setSheetState(() => personId = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text(
                  direction == AdvanceDirection.receivable
                      ? 'Pagato da'
                      : 'Ricevuto su',
                ),
                subtitle: Text(
                  state.accountById(accountId)?.name ?? 'Scegli conto',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final picked = await _pickAccount(context);
                  if (picked != null) setSheetState(() => accountId = picked);
                },
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('Promemoria e dettagli'),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Scadenza'),
                    subtitle: Text(
                      dueDate == null
                          ? 'Nessuna'
                          : DateFormat('d MMM yyyy', 'it_IT').format(dueDate!),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 3650),
                        ),
                        initialDate:
                            dueDate ??
                            DateTime.now().add(const Duration(days: 7)),
                      );
                      if (picked != null) setSheetState(() => dueDate = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_none_rounded),
                    title: const Text('Promemoria'),
                    subtitle: Text(
                      reminderDate == null
                          ? 'Nessuno'
                          : DateFormat(
                              'd MMM yyyy',
                              'it_IT',
                            ).format(reminderDate!),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 3650),
                        ),
                        initialDate:
                            reminderDate ??
                            dueDate ??
                            DateTime.now().add(const Duration(days: 7)),
                      );
                      if (picked != null)
                        setSheetState(() => reminderDate = picked);
                    },
                  ),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(
                      labelText: 'Nota opzionale',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final parsed = Money.parseExpression(amount.text);
                    if (parsed == null ||
                        parsed <= 0 ||
                        personId == null ||
                        accountId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Completa importo, persona e conto.'),
                        ),
                      );
                      return;
                    }
                    try {
                      await state.createPureAdvance(
                        direction: direction,
                        personId: personId!,
                        amount: parsed,
                        accountId: accountId!,
                        date: DateTime.now(),
                        dueDate: dueDate,
                        reminderDate: reminderDate,
                        note: note.text,
                      );
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error.toString().replaceFirst('Bad state: ', ''),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Salva anticipo'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  amount.dispose();
  note.dispose();
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Anticipo registrato.')));
  }
}

Future<void> showSettlementEditor(BuildContext context, Advance advance) async {
  final state = AppScope.of(context);
  final remaining = state.advanceRemainingCents(advance.id);
  final amount = TextEditingController(
    text: Money.fromCents(remaining).toStringAsFixed(2),
  );
  final note = TextEditingController();
  int? accountId = state.activeAccounts
      .where((item) => !item.isLocked)
      .firstOrNull
      ?.id;
  var date = DateTime.now();
  final saved = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                advance.direction == AdvanceDirection.receivable
                    ? 'Registra rimborso'
                    : 'Registra restituzione',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('Residuo: ${moneyFor(state, Money.fromCents(remaining))}'),
              const SizedBox(height: 16),
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: advance.direction == AdvanceDirection.receivable
                      ? 'Importo ricevuto'
                      : 'Importo restituito',
                  suffixText: '€',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text(
                  advance.direction == AdvanceDirection.receivable
                      ? 'Ricevuto su'
                      : 'Restituito da',
                ),
                subtitle: Text(
                  state.accountById(accountId)?.name ?? 'Scegli conto',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final picked = await _pickAccount(context);
                  if (picked != null) setSheetState(() => accountId = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Data'),
                subtitle: Text(DateFormat('d MMM yyyy', 'it_IT').format(date)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDate: date,
                  );
                  if (picked != null) setSheetState(() => date = picked);
                },
              ),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Nota opzionale'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final parsed = Money.parseExpression(amount.text);
                    if (parsed == null ||
                        parsed <= 0 ||
                        Money.toCents(parsed) > remaining ||
                        accountId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Inserisci un importo valido entro il residuo e scegli un conto.',
                          ),
                        ),
                      );
                      return;
                    }
                    try {
                      await state.recordAdvanceSettlement(
                        advanceId: advance.id,
                        amount: parsed,
                        accountId: accountId!,
                        date: date,
                        note: note.text,
                      );
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error.toString().replaceFirst('Bad state: ', ''),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Salva'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  amount.dispose();
  note.dispose();
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Anticipo aggiornato.')));
  }
}

class FinancePeopleScreen extends StatelessWidget {
  const FinancePeopleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final people = state.people;
    return Scaffold(
      appBar: AppBar(title: const Text('Persone')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createPersonDialog(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Persona'),
      ),
      body: people.isEmpty
          ? const EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'Nessuna persona',
              subtitle:
                  'Le persone servono solo per organizzare gli anticipi e restano sul dispositivo.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: people.map((person) {
                final open = state.advances
                    .where(
                      (item) =>
                          item.personId == person.id &&
                          item.closedKind == null &&
                          state.advanceRemainingCents(item.id) > 0,
                    )
                    .length;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(person.name),
                  subtitle: Text(
                    open == 0
                        ? 'Nessun anticipo aperto'
                        : '$open anticipi aperti',
                  ),
                  trailing: person.archived ? const Text('Archiviata') : null,
                );
              }).toList(),
            ),
    );
  }
}

Future<int?> _pickPerson(
  BuildContext context, {
  bool allowCreate = false,
}) async {
  final state = AppScope.of(context);
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
          Text('Persona', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...state.people
              .where((item) => !item.archived)
              .map(
                (person) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(person.name),
                  onTap: () => Navigator.pop(sheetContext, person.id),
                ),
              ),
          if (allowCreate)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_add_alt_1_rounded),
              title: const Text('Nuova persona'),
              onTap: () async {
                final id = await _createPersonDialog(sheetContext);
                if (id != null && sheetContext.mounted)
                  Navigator.pop(sheetContext, id);
              },
            ),
        ],
      ),
    ),
  );
}

Future<int?> _createPersonDialog(BuildContext context) async {
  final state = AppScope.of(context);
  final controller = TextEditingController();
  final id = await showDialog<int>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Nuova persona'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Nome'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              final result = await state.createFinancePerson(controller.text);
              if (dialogContext.mounted) Navigator.pop(dialogContext, result);
            } catch (error) {
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      error.toString().replaceFirst('Bad state: ', ''),
                    ),
                  ),
                );
              }
            }
          },
          child: const Text('Crea'),
        ),
      ],
    ),
  );
  controller.dispose();
  return id;
}

Future<int?> _pickAccount(BuildContext context) async {
  final state = AppScope.of(context);
  final accounts = state.activeAccounts
      .where((item) => !item.isLocked)
      .toList();
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
          Text('Conto', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...accounts.map(
            (account) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                accountIcon(account.iconKey),
                color: Color(account.colorValue),
              ),
              title: Text(account.name),
              onTap: () => Navigator.pop(sheetContext, account.id),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<int?> _pickCategory(BuildContext context, TransactionType type) async {
  final state = AppScope.of(context);
  final categories = state.categoriesFor(type);
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
          Text('Categoria', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...categories.map(
            (category) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                categoryIcon(category.iconKey),
                color: Color(category.colorValue),
              ),
              title: Text(category.name),
              onTap: () => Navigator.pop(sheetContext, category.id),
            ),
          ),
        ],
      ),
    ),
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

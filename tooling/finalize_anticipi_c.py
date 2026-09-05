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


# Advances UI: edit/cancel, settlement maintenance, people maintenance ----------
p = 'lib/screens/advances_screen.dart'
s = read(p)

# Detail app bar: add edit/cancel menu while preserving notification shortcut.
old = r'''        actions: [
          IconButton(
            tooltip: 'Promemoria e scadenza',
            onPressed: canSettle ? () => _editDates(context, advance) : null,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],'''
new = r'''        actions: [
          IconButton(
            tooltip: 'Promemoria e scadenza',
            onPressed: canSettle ? () => _editDates(context, advance) : null,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          if (advance.closedKind == null)
            PopupMenuButton<String>(
              tooltip: 'Azioni anticipo',
              onSelected: (value) async {
                if (value == 'edit') {
                  await showAdvanceMetadataEditor(context, advance);
                } else if (value == 'cancel') {
                  final confirmed = await confirmDestructiveAction(
                    context,
                    title: 'Annullare questo anticipo?',
                    message: advance.sourceTransactionId == null
                        ? 'La posizione verrà chiusa come annullata.'
                        : 'Se è un anticipo puro, il movimento di cassa originale verrà annullato. Le spese miste restano come acquisto personale.',
                    confirmLabel: 'Annulla anticipo',
                  );
                  if (!confirmed) return;
                  try {
                    await state.cancelAdvance(advance.id);
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
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Modifica')),
                PopupMenuItem(
                  value: 'cancel',
                  child: Text('Annulla anticipo'),
                ),
              ],
            ),
        ],'''
s = replace_once(s, old, new, 'advance detail actions')

# Settlement timeline gets edit/delete menu.
old = r'''              subtitle: Text(
                [
                  DateFormat('d MMM yyyy', 'it_IT').format(settlement.date),
                  if (account != null) account.name,
                  if (settlement.note?.isNotEmpty == true) settlement.note!,
                ].join(' · '),
              ),
            );'''
new = r'''              subtitle: Text(
                [
                  DateFormat('d MMM yyyy', 'it_IT').format(settlement.date),
                  if (account != null) account.name,
                  if (settlement.note?.isNotEmpty == true) settlement.note!,
                ].join(' · '),
              ),
              trailing: advance.closedKind == null
                  ? PopupMenuButton<String>(
                      tooltip: 'Azioni rimborso',
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await showSettlementEditor(
                            context,
                            advance,
                            editing: settlement,
                          );
                        } else if (value == 'delete') {
                          final confirmed = await confirmDestructiveAction(
                            context,
                            title: 'Eliminare questo rimborso?',
                            message:
                                'Il saldo del conto e il residuo dell’anticipo verranno ripristinati automaticamente.',
                          );
                          if (confirmed) {
                            await state.deleteAdvanceSettlement(settlement.id);
                          }
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Modifica')),
                        PopupMenuItem(value: 'delete', child: Text('Elimina')),
                      ],
                    )
                  : null,
            );'''
s = replace_once(s, old, new, 'settlement timeline actions')

# Settlement editor supports edit mode.
s = replace_once(
    s,
    'Future<void> showSettlementEditor(BuildContext context, Advance advance) async {',
    'Future<void> showSettlementEditor(\n  BuildContext context,\n  Advance advance, {\n  AdvanceSettlement? editing,\n}) async {',
    'settlement editor signature',
)
s = replace_once(
    s,
    """  final remaining = state.advanceRemainingCents(advance.id);
  final amount = TextEditingController(
    text: Money.fromCents(remaining).toStringAsFixed(2),
  );
  final note = TextEditingController();
  int? accountId = state.activeAccounts
      .where((item) => !item.isLocked)
      .firstOrNull
      ?.id;
  var date = DateTime.now();""",
    """  final remaining = state.advanceRemainingCents(advance.id);
  final available = remaining + (editing?.amountCents ?? 0);
  final amount = TextEditingController(
    text: Money.fromCents(editing?.amountCents ?? remaining).toStringAsFixed(2),
  );
  final note = TextEditingController(text: editing?.note ?? '');
  int? accountId =
      editing?.accountId ??
      state.activeAccounts.where((item) => !item.isLocked).firstOrNull?.id;
  var date = editing?.date ?? DateTime.now();""",
    'settlement editor initial values',
)
s = s.replace(
    "Text('Residuo: ${moneyFor(state, Money.fromCents(remaining))}')",
    "Text('Disponibile: ${moneyFor(state, Money.fromCents(available))}')",
    1,
)
s = s.replace('Money.toCents(parsed) > remaining', 'Money.toCents(parsed) > available', 1)
old = r'''                      await state.recordAdvanceSettlement(
                        advanceId: advance.id,
                        amount: parsed,
                        accountId: accountId!,
                        date: date,
                        note: note.text,
                      );'''
new = r'''                      if (editing == null) {
                        await state.recordAdvanceSettlement(
                          advanceId: advance.id,
                          amount: parsed,
                          accountId: accountId!,
                          date: date,
                          note: note.text,
                        );
                      } else {
                        await state.updateAdvanceSettlement(
                          settlement: editing,
                          amount: parsed,
                          accountId: accountId!,
                          date: date,
                          note: note.text,
                        );
                      }'''
s = replace_once(s, old, new, 'settlement editor save mode')

# Person list becomes navigable and manageable.
old = r'''                  trailing: person.archived ? const Text('Archiviata') : null,
                );'''
new = r'''                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FinancePersonDetailScreen(
                        personId: person.id,
                      ),
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Azioni persona',
                    onSelected: (value) async {
                      if (value == 'rename') {
                        await showFinancePersonRename(context, person);
                      } else if (value == 'archive') {
                        try {
                          await state.archiveFinancePerson(
                            person.id,
                            !person.archived,
                          );
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
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('Rinomina'),
                      ),
                      PopupMenuItem(
                        value: 'archive',
                        child: Text(
                          person.archived ? 'Ripristina' : 'Archivia',
                        ),
                      ),
                    ],
                  ),
                );'''
s = replace_once(s, old, new, 'finance person list actions')

# Add person detail screen and rename dialog before picker.
marker = 'Future<int?> showFinancePersonPicker('
person_detail = r'''class FinancePersonDetailScreen extends StatelessWidget {
  const FinancePersonDetailScreen({required this.personId, super.key});

  final int personId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final person = state.personById(personId);
    if (person == null) {
      return const Scaffold(body: Center(child: Text('Persona non trovata')));
    }
    final items = state.advances
        .where((item) => item.personId == personId)
        .toList();
    var receivable = 0;
    var payable = 0;
    for (final item in items.where((item) => item.closedKind == null)) {
      final remaining = state.advanceRemainingCents(item.id);
      if (item.direction == AdvanceDirection.receivable) {
        receivable += remaining;
      } else {
        payable += remaining;
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(person.name),
        actions: [
          IconButton(
            tooltip: 'Rinomina persona',
            onPressed: () => showFinancePersonRename(context, person),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Row(
            children: [
              Expanded(
                child: FlatMetric(
                  label: 'Da ricevere',
                  value: state.hideBalance
                      ? '••••'
                      : moneyFor(state, Money.fromCents(receivable)),
                  icon: Icons.call_received_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FlatMetric(
                  label: 'Da restituire',
                  value: state.hideBalance
                      ? '••••'
                      : moneyFor(state, Money.fromCents(payable)),
                  icon: Icons.call_made_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const SectionTitle('Storico'),
          if (items.isEmpty)
            const Text('Nessun anticipo con questa persona.')
          else
            ...items.map((item) => _AdvanceRow(
                  advance: item,
                  closed: item.closedKind != null ||
                      state.advanceRemainingCents(item.id) == 0,
                )),
        ],
      ),
    );
  }
}

Future<void> showFinancePersonRename(
  BuildContext context,
  FinancePerson person,
) async {
  final state = AppScope.of(context);
  final controller = TextEditingController(text: person.name);
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Rinomina persona'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Nome'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Salva'),
        ),
      ],
    ),
  );
  if (saved == true) {
    try {
      await state.renameFinancePerson(person.id, controller.text);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    }
  }
  controller.dispose();
}

'''
s = replace_once(s, marker, person_detail + marker, 'finance person detail screen')

# Metadata editor before settlement editor.
marker = 'Future<void> showSettlementEditor('
metadata = r'''Future<void> showAdvanceMetadataEditor(
  BuildContext context,
  Advance advance,
) async {
  final state = AppScope.of(context);
  var personId = advance.personId;
  var dueDate = advance.dueDate;
  var reminderDate = advance.reminderDate;
  final note = TextEditingController(text: advance.note ?? '');
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
                'Modifica anticipo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('Persona'),
                subtitle: Text(state.personById(personId)?.name ?? 'Scegli'),
                onTap: () async {
                  final picked = await showFinancePersonPicker(context);
                  if (picked != null) setSheetState(() => personId = picked);
                },
              ),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Nota opzionale'),
              ),
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
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    initialDate: dueDate ?? DateTime.now(),
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
                      : DateFormat('d MMM yyyy', 'it_IT').format(reminderDate!),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    initialDate: reminderDate ?? dueDate ?? DateTime.now(),
                  );
                  if (picked != null) setSheetState(() => reminderDate = picked);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Salva modifiche'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (saved == true) {
    await state.updateAdvanceDetails(
      advanceId: advance.id,
      personId: personId,
      dueDate: dueDate,
      reminderDate: reminderDate,
      note: note.text,
    );
  }
  note.dispose();
}

'''
s = replace_once(s, marker, metadata + marker, 'advance metadata editor')
write(p, s)

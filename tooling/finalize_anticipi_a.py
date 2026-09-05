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


# Quick Add: analyzer fix + manual alternative matching ------------------------
p = 'lib/screens/quick_add_page.dart'
s = read(p)
s = replace_once(
    s,
    """                      final personal = (total - advanced).clamp(
                        0,
                        double.infinity,
                      );""",
    """                      final personal = (total - advanced)
                          .clamp(0, double.infinity)
                          .toDouble();""",
    'quick add personal amount double',
)

# Add a deterministic manual picker for alternate compatible advances.
marker = """  Future<void> _previewSuggestion() async {"""
helper = r'''  Future<void> _chooseAdvanceToLink() async {
    final state = AppScope.of(context);
    final parsed = Money.parseExpression(amount.text);
    if (parsed == null || parsed <= 0 || type == TransactionType.transfer) return;
    final cents = Money.toCents(parsed);
    final expectedDirection = type == TransactionType.income
        ? AdvanceDirection.receivable
        : AdvanceDirection.payable;
    final candidates = state.advances
        .where(
          (item) =>
              item.direction == expectedDirection &&
              item.closedKind == null &&
              state.advanceRemainingCents(item.id) >= cents,
        )
        .toList();
    if (candidates.isEmpty) {
      _error('Nessun anticipo compatibile con questo movimento.');
      return;
    }
    final picked = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          Text(
            'Collega a un anticipo',
            style: Theme.of(sheetContext).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ...candidates.map((advance) {
            final person = state.personById(advance.personId);
            final remaining = state.advanceRemainingCents(advance.id);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.handshake_outlined),
              title: Text(person?.name ?? 'Persona'),
              subtitle: Text(
                '${moneyFor(state, Money.fromCents(remaining))} ${advance.direction.label.toLowerCase()}',
              ),
              onTap: () => Navigator.pop(sheetContext, advance.id),
            );
          }),
        ],
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        linkedAdvanceId = picked;
        advanceMatch = null;
        advanceMatchDismissed = true;
      });
    }
  }

'''
s = replace_once(s, marker, helper + marker, 'quick add alternate advance helper')

# Add an "Altro" action beside deterministic match to resolve a different candidate.
old = """                        FilledButton.tonal(
                          onPressed: () => setState(() {
                            linkedAdvanceId = match.advanceId;
                            advanceMatch = null;
                            advanceMatchDismissed = true;
                          }),
                          child: const Text('Collega'),
                        ),"""
new = """                        TextButton(
                          onPressed: _chooseAdvanceToLink,
                          child: const Text('Altro'),
                        ),
                        FilledButton.tonal(
                          onPressed: () => setState(() {
                            linkedAdvanceId = match.advanceId;
                            advanceMatch = null;
                            advanceMatchDismissed = true;
                          }),
                          child: const Text('Collega'),
                        ),"""
s = replace_once(s, old, new, 'quick add alternate match action')
write(p, s)


# Home: preserve Smart insight + Anticipi and respect hideBalance ---------------
p = 'lib/screens/home_screen.dart'
s = read(p)
s = replace_once(
    s,
    '    final insight = _smartInsight(state);',
    '    final smartInsight = _smartInsight(state);',
    'home smart insight local',
)
s = s.replace('_smartInsight(state) != null', 'smartInsight != null')
s = s.replace(
    'if (_smartInsight(state) case final insight?)',
    'if (smartInsight case final insight?)',
)
old = """                    subtitle: Text(
                      '${moneyFor(state, Money.fromCents(state.advanceReceivableCents))} da ricevere · '
                      '${moneyFor(state, Money.fromCents(state.advancePayableCents))} da restituire',
                    ),"""
new = """                    subtitle: Text(
                      state.hideBalance
                          ? '•••• da ricevere · •••• da restituire'
                          : '${moneyFor(state, Money.fromCents(state.advanceReceivableCents))} da ricevere · '
                                '${moneyFor(state, Money.fromCents(state.advancePayableCents))} da restituire',
                    ),"""
s = replace_once(s, old, new, 'home Anticipi hide balance')
write(p, s)

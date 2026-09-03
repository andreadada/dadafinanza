part of 'root_screen.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final months = List.generate(6, (i) {
      final now = DateTime.now();
      return DateTime(now.year, now.month - (5 - i));
    });
    final top = state.topExpenseCategories();

    return Scaffold(
      appBar: AppBar(title: const Text('Analisi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          const SectionTitle('Ultimi 6 mesi'),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= months.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('MMM', 'it_IT').format(months[i]),
                            style: const TextStyle(color: AppTheme.muted),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(months.length, (i) {
                  final month = months[i];
                  final income = state.monthTotal(
                    TransactionType.income,
                    month: month,
                  );
                  final expense = state.monthTotal(
                    TransactionType.expense,
                    month: month,
                  );
                  return BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: income,
                        width: 10,
                        borderRadius: BorderRadius.circular(5),
                        color: const Color(0xFF7CA7FF),
                      ),
                      BarChartRodData(
                        toY: expense,
                        width: 10,
                        borderRadius: BorderRadius.circular(5),
                        color: const Color(0xFFFF7A7A),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: Color(0xFF7CA7FF), label: 'Entrate'),
              SizedBox(width: 18),
              _LegendDot(color: Color(0xFFFF7A7A), label: 'Spese'),
            ],
          ),
          const SizedBox(height: 34),
          const SectionTitle('Categorie del mese'),
          if (top.isEmpty)
            const _EmptyCard(
              icon: Icons.donut_large_rounded,
              title: 'Nessun dato da analizzare',
              subtitle: 'Le categorie compariranno quando registri le prime spese.',
            )
          else
            ...List.generate(top.length, (index) {
              final entry = top[index];
              final max = top.first.value;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          categoryIcon(entry.key.iconKey),
                          color: Color(entry.key.colorValue),
                          size: 25,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.key.name,
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  Text(money(entry.value)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: entry.value / max,
                                minHeight: 5,
                                color: Color(entry.key.colorValue),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index != top.length - 1) const Divider(height: 1),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: AppTheme.muted)),
        ],
      );
}

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  Future<void> _addAccount(BuildContext context) async {
    final state = AppScope.of(context);
    final name = TextEditingController();
    final balance = TextEditingController(text: '0');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nuovo conto',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nome',
                hintText: 'Es. Portafoglio',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: balance,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Saldo iniziale',
                suffixText: '€',
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final accountName = name.text.trim();
                  if (accountName.isEmpty) return;
                  final value =
                      double.tryParse(balance.text.replaceAll(',', '.')) ?? 0;
                  await state.addAccount(accountName, value, 0xFF8E8E93);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Crea conto'),
              ),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    balance.dispose();
  }

  Future<void> _deleteAccount(BuildContext context, Account account) async {
    final state = AppScope.of(context);
    final movementCount = state.transactionCountForAccount(account.id);
    final recurringCount = state.recurringCountForAccount(account.id);
    final impact = [
      if (movementCount > 0) '$movementCount moviment${movementCount == 1 ? 'o' : 'i'}',
      if (recurringCount > 0)
        '$recurringCount pagamento${recurringCount == 1 ? ' regolare' : 'i regolari'}',
    ].join(' e ');

    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Eliminare “${account.name}”?',
      message: impact.isEmpty
          ? 'Il conto verrà eliminato definitivamente.'
          : 'Verranno eliminati anche $impact collegati a questo conto. Gli eventuali giroconti verranno annullati e i saldi degli altri conti corretti. L’operazione non può essere annullata.',
    );
    if (confirmed) await state.deleteAccount(account);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final allBalances =
        state.accounts.fold<double>(0, (sum, account) => sum + account.balance);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conti'),
        actions: [
          IconButton(
            tooltip: 'Crea conto',
            onPressed: () => _addAccount(context),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          const Text(
            'PATRIMONIO',
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.hideBalance ? '••••••' : money(state.totalBalance),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Tutti i conti: ${state.hideBalance ? '••••' : money(allBalances)}',
            style: const TextStyle(color: AppTheme.muted),
          ),
          if (state.accounts.length > 1) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const QuickAddPage(initialTypeName: 'transfer'),
                  ),
                ),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Nuovo giroconto'),
              ),
            ),
          ],
          const SizedBox(height: 30),
          Row(
            children: [
              const Expanded(child: SectionTitle('I tuoi conti')),
              TextButton.icon(
                onPressed: () => _addAccount(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nuovo'),
              ),
            ],
          ),
          if (state.accounts.isEmpty)
            _EmptyCard(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Nessun conto',
              subtitle: 'Crea il primo conto per iniziare a registrare movimenti.',
              action: FilledButton.icon(
                onPressed: () => _addAccount(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crea conto'),
              ),
            )
          else
            ...List.generate(state.accounts.length, (index) {
              final account = state.accounts[index];
              return Column(
                children: [
                  ListTile(
                    minVerticalPadding: 12,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: Text(
                      account.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      account.includeInTotal
                          ? 'Incluso nel totale'
                          : 'Escluso dal totale',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state.hideBalance ? '••••' : money(account.balance),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Azioni per ${account.name}',
                          onSelected: (value) async {
                            if (value == 'toggle') {
                              await state.setAccountIncluded(
                                account,
                                !account.includeInTotal,
                              );
                            } else if (value == 'delete') {
                              if (context.mounted) {
                                await _deleteAccount(context, account);
                              }
                            }
                          },
                          itemBuilder: (menuContext) => [
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(
                                account.includeInTotal
                                    ? 'Escludi dal totale'
                                    : 'Includi nel totale',
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Elimina conto',
                                style: TextStyle(
                                  color: Theme.of(menuContext).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (index != state.accounts.length - 1)
                    const Divider(height: 1),
                ],
              );
            }),
        ],
      ),
    );
  }
}

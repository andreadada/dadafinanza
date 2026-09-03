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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          const SectionTitle('Ultimi 6 mesi'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
              child: SizedBox(
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
          const SizedBox(height: 28),
          const SectionTitle('Categorie del mese'),
          if (top.isEmpty)
            const _EmptyCard(
              icon: Icons.donut_large_rounded,
              title: 'Nessun dato da analizzare',
              subtitle: 'Le categorie compariranno quando registri le prime spese.',
            )
          else
            ...top.map((entry) {
              final max = top.first.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(entry.key.colorValue)
                                .withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            categoryIcon(entry.key.iconKey),
                            color: Color(entry.key.colorValue),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.key.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(money(entry.value)),
                                ],
                              ),
                              const SizedBox(height: 9),
                              LinearProgressIndicator(
                                value: entry.value / max,
                                minHeight: 6,
                                color: Color(entry.key.colorValue),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuovo conto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: balance,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Saldo iniziale',
                suffixText: '€',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              final value =
                  double.tryParse(balance.text.replaceAll(',', '.')) ?? 0;
              if (name.text.trim().isEmpty) return;
              await state.addAccount(
                name.text.trim(),
                value,
                0xFF8E8E93,
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Crea'),
          ),
        ],
      ),
    );
    name.dispose();
    balance.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final allBalances =
        state.accounts.fold<double>(0, (sum, a) => sum + a.balance);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conti'),
        actions: [
          IconButton(
            onPressed: () => _addAccount(context),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 9),
                  Text(
                    state.hideBalance ? '••••••' : money(state.totalBalance),
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Tutti i conti: ${state.hideBalance ? '••••' : money(allBalances)}',
                    style: const TextStyle(color: AppTheme.muted),
                  ),
                  if (state.accounts.length > 1) ...[
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const QuickAddPage(
                            initialTypeName: 'transfer',
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Nuovo giroconto'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          const SectionTitle('I tuoi conti'),
          if (state.accounts.isEmpty)
            _EmptyCard(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Nessun conto',
              subtitle:
                  'Crea il primo conto. Il saldo iniziale è impostato a 0 €.',
              action: FilledButton.icon(
                onPressed: () => _addAccount(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crea conto'),
              ),
            )
          else
            ...state.accounts.map(
              (account) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.account_balance_wallet_outlined),
                    ),
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
                          onSelected: (value) {
                            if (value == 'toggle') {
                              state.setAccountIncluded(
                                account,
                                !account.includeInTotal,
                              );
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(
                                account.includeInTotal
                                    ? 'Escludi dal totale'
                                    : 'Includi nel totale',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

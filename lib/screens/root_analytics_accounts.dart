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
          const SectionTitle('Entrate vs spese'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
              child: SizedBox(
                height: 260,
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= months.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(DateFormat('MMM', 'it_IT').format(months[i])),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: List.generate(months.length, (i) {
                      final month = months[i];
                      final income = state.monthTotal(TransactionType.income, month: month);
                      final expense = state.monthTotal(TransactionType.expense, month: month);
                      return BarChartGroupData(
                        x: i,
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(toY: income, width: 10, borderRadius: BorderRadius.circular(5), color: const Color(0xFF27D398)),
                          BarChartRodData(toY: expense, width: 10, borderRadius: BorderRadius.circular(5), color: const Color(0xFFFFA12F)),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionTitle('Categorie questo mese'),
          if (top.isEmpty)
            const _EmptyCard(icon: Icons.donut_large_rounded, title: 'Dati insufficienti', subtitle: 'Le categorie compariranno appena inizi a registrare spese.')
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
                        CircleAvatar(backgroundColor: Color(entry.key.colorValue), child: Icon(categoryIcon(entry.key.iconKey), color: Colors.white)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [Expanded(child: Text(entry.key.name, style: const TextStyle(fontWeight: FontWeight.w800))), Text(money(entry.value))]),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(value: entry.value / max, borderRadius: BorderRadius.circular(10)),
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

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  Future<void> _addAccount(BuildContext context) async {
    final state = AppScope.of(context);
    final name = TextEditingController();
    final balance = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuovo conto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nome')),
            const SizedBox(height: 10),
            TextField(controller: balance, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Saldo iniziale', suffixText: '€')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          FilledButton(
            onPressed: () async {
              final value = double.tryParse(balance.text.replaceAll(',', '.')) ?? 0;
              if (name.text.trim().isEmpty) return;
              await state.addAccount(name.text.trim(), value, 0xFF3E8E75);
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
    final allBalances = state.accounts.fold<double>(0, (sum, a) => sum + a.balance);
    return Scaffold(
      appBar: AppBar(title: const Text('Conti'), actions: [IconButton(onPressed: () => _addAccount(context), icon: const Icon(Icons.add_rounded))]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('Saldo incluso nel totale', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Text(state.hideBalance ? '••••••' : money(state.totalBalance), style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('Patrimonio su tutti i conti: ${state.hideBalance ? '••••' : money(allBalances)}'),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QuickAddPage(initialTypeName: 'transfer'))),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Nuovo giroconto'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('I tuoi conti'),
          ...state.accounts.map((account) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    leading: CircleAvatar(backgroundColor: Color(account.colorValue), child: const Icon(Icons.account_balance_rounded, color: Colors.white)),
                    title: Text(account.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(account.includeInTotal ? 'Incluso nel totale' : 'Escluso dal totale'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.hideBalance ? '••••' : money(account.balance), style: const TextStyle(fontWeight: FontWeight.w900)),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'toggle') state.setAccountIncluded(account, !account.includeInTotal);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'toggle', child: Text(account.includeInTotal ? 'Escludi dal totale' : 'Includi nel totale')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

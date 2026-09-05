import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/csv_service.dart';
import '../services/data_integrity_service.dart';
import '../widgets/finance_quick_action.dart';
import '../widgets/ui_helpers.dart';
import 'account_screens.dart' show showAccountEditor;
import 'quick_add_page.dart';
import 'transaction_screens.dart';

class AccountManagementScreen extends StatelessWidget {
  const AccountManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conti'),
        actions: [
          IconButton(
            tooltip: 'Nuovo conto',
            onPressed: () => showAccountEditor(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Text('PATRIMONIO', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(
            state.hideBalance ? '••••••' : moneyFor(state, state.totalBalance),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 28),
          if (state.activeAccounts.isEmpty)
            EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Nessun conto',
              subtitle: 'Crea il primo conto per iniziare.',
              action: FilledButton.icon(
                onPressed: () => showAccountEditor(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crea conto'),
              ),
            )
          else
            ...state.activeAccounts.map(
              (account) => _AccountTile(account: account),
            ),
          if (state.archivedAccounts.isNotEmpty) ...[
            const SizedBox(height: 32),
            SectionTitle(
              'Archiviati',
              trailing: Text('${state.archivedAccounts.length}'),
            ),
            ...state.archivedAccounts.map(
              (account) => _AccountTile(account: account),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});
  final Account account;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 12,
      leading: Icon(
        accountIcon(account.iconKey),
        color: Color(account.colorValue),
      ),
      title: Text(
        account.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [
          account.accountType.label,
          if (account.isArchived) 'Archiviato',
          if (account.isLocked) 'Bloccato',
          if (!account.includeInTotal) 'Fuori patrimonio',
        ].join(' · '),
      ),
      trailing: Text(
        state.hideBalance || account.hideBalance
            ? '••••'
            : moneyFor(state, account.balance),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SafeAccountDetailScreen(accountId: account.id),
        ),
      ),
    );
  }
}

class SafeAccountDetailScreen extends StatelessWidget {
  const SafeAccountDetailScreen({required this.accountId, super.key});
  final int accountId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final account = state.accountById(accountId);
    if (account == null) {
      return const Scaffold(body: Center(child: Text('Conto non trovato')));
    }
    final transactions = state.transactions
        .where(
          (item) =>
              item.accountId == account.id || item.toAccountId == account.id,
        )
        .toList();
    final recent = transactions.take(8).toList();
    final income = state.accountMonthTotal(account.id, TransactionType.income);
    final expense = state.accountMonthTotal(
      account.id,
      TransactionType.expense,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Azioni conto',
            onSelected: (value) async {
              if (value == 'edit') {
                await showAccountEditor(context, existing: account);
              } else if (value == 'reconcile') {
                await _reconcile(context, state, account);
              } else if (value == 'export') {
                await _export(context, state, account);
              } else if (value == 'archive') {
                if (account.isArchived) {
                  await state.updateAccount(
                    account.copyWith(isArchived: false),
                  );
                } else {
                  await DataIntegrityService.archiveAccount(state, account);
                }
              } else if (value == 'delete' && context.mounted) {
                await _delete(context, state, account);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('Modifica dettagli'),
              ),
              if (!account.isArchived && !account.isLocked)
                const PopupMenuItem(
                  value: 'reconcile',
                  child: Text('Riconcilia saldo'),
                ),
              const PopupMenuItem(
                value: 'export',
                child: Text('Esporta movimenti CSV'),
              ),
              PopupMenuItem(
                value: 'archive',
                child: Text(
                  account.isArchived ? 'Ripristina conto' : 'Archivia conto',
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Elimina se vuoto'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Text(
            account.accountType.label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            state.hideBalance || account.hideBalance
                ? '••••••'
                : moneyFor(state, account.balance),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 6),
          Text(
            account.lastReconciledAt == null
                ? 'Mai riconciliato'
                : 'Ultimo controllo ${DateFormat('dd MMM yyyy', 'it_IT').format(account.lastReconciledAt!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          if (transactions.length >= 2)
            _AccountTrend(account: account, items: transactions),
          if (!account.isArchived) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FinanceQuickAction(
                    icon: Icons.arrow_upward_rounded,
                    label: 'Spesa',
                    semanticLabel: 'Nuova spesa da ${account.name}',
                    onTap: account.isLocked
                        ? null
                        : () => _openQuick(
                            context,
                            account,
                            TransactionType.expense,
                          ),
                  ),
                ),
                Expanded(
                  child: FinanceQuickAction(
                    icon: Icons.arrow_downward_rounded,
                    label: 'Entrata',
                    semanticLabel: 'Nuova entrata su ${account.name}',
                    onTap: account.isLocked
                        ? null
                        : () => _openQuick(
                            context,
                            account,
                            TransactionType.income,
                          ),
                  ),
                ),
                Expanded(
                  child: FinanceQuickAction(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Trasferisci',
                    semanticLabel: 'Nuovo trasferimento da ${account.name}',
                    onTap: account.isLocked
                        ? null
                        : () => _openQuick(
                            context,
                            account,
                            TransactionType.transfer,
                          ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          const SectionTitle('Questo mese'),
          FlatMetric(
            label: 'Entrate',
            value: moneyFor(state, income),
            icon: Icons.arrow_downward_rounded,
            color: context.financeColors.positive,
          ),
          const Divider(height: 1),
          FlatMetric(
            label: 'Spese',
            value: moneyFor(state, expense),
            icon: Icons.arrow_upward_rounded,
            color: context.financeColors.negative,
          ),
          const Divider(height: 1),
          FlatMetric(
            label: 'Cash flow',
            value: moneyFor(state, income - expense, signed: true),
            icon: Icons.compare_arrows_rounded,
          ),
          const SizedBox(height: 28),
          SectionTitle(
            'Movimenti recenti',
            trailing: Text('${transactions.length}'),
          ),
          if (recent.isEmpty)
            const Text('Nessun movimento')
          else
            ...recent.map((item) => TransactionListTile(item: item)),
        ],
      ),
    );
  }

  void _openQuick(BuildContext context, Account account, TransactionType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuickAddPage(
          initialTypeName: type.name,
          initialAccountId: account.id,
        ),
      ),
    );
  }

  Future<void> _reconcile(
    BuildContext context,
    AppState state,
    Account account,
  ) async {
    final controller = TextEditingController(
      text: account.balance.toStringAsFixed(2),
    );
    final actual = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Riconcilia saldo',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Saldo DadaFinanza: ${moneyFor(state, account.balance)}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Saldo reale',
                suffixText: '€',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final value = double.tryParse(
                    controller.text.replaceAll(',', '.'),
                  );
                  if (value != null) Navigator.pop(sheetContext, value);
                },
                child: const Text('Continua'),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (actual == null || !context.mounted) return;
    final difference = actual - account.balance;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Conferma riconciliazione'),
            content: Text(
              'Saldo attuale: ${moneyFor(state, account.balance)}\nSaldo reale: ${moneyFor(state, actual)}\nDifferenza: ${moneyFor(state, difference, signed: true)}\n\nLa differenza sarà registrata come rettifica fuori dalle statistiche.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Riconcilia'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await DataIntegrityService.reconcileAccount(
      state,
      account: account,
      actualBalance: actual,
    );
  }

  Future<void> _delete(
    BuildContext context,
    AppState state,
    Account account,
  ) async {
    if (state.transactionCountForAccount(account.id) > 0 ||
        state.recurring.any(
          (item) =>
              item.accountId == account.id || item.toAccountId == account.id,
        )) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Il conto contiene storico'),
          content: const Text(
            'Per proteggere lo storico finanziario un conto con movimenti o ricorrenze non viene eliminato. Puoi archiviarlo e continuare a consultare i dati.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Chiudi'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await DataIntegrityService.archiveAccount(state, account);
              },
              child: const Text('Archivia conto'),
            ),
          ],
        ),
      );
      return;
    }
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Eliminare “${account.name}”?',
      message: 'Il conto è vuoto e può essere eliminato in sicurezza.',
    );
    if (!confirmed) return;
    await DataIntegrityService.deleteEmptyAccount(state, account);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _export(
    BuildContext context,
    AppState state,
    Account account,
  ) async {
    final csv = const CsvService().export(state, accountId: account.id);
    final output = await FilePicker.saveFile(
      dialogTitle: 'Esporta ${account.name}',
      fileName:
          '${account.name.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')}.csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );
    if (context.mounted && output != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movimenti del conto esportati.')),
      );
    }
  }


}

class _AccountTrend extends StatelessWidget {
  const _AccountTrend({required this.account, required this.items});
  final Account account;
  final List<FinanceTransaction> items;

  @override
  Widget build(BuildContext context) {
    final chronological = items.reversed.toList();
    var value = account.openingBalance;
    final spots = <FlSpot>[FlSpot(0, value)];
    for (var index = 0; index < chronological.length; index++) {
      final item = chronological[index];
      if (item.accountId == account.id) {
        value += switch (item.type) {
          TransactionType.expense => -item.amount,
          TransactionType.income => item.amount,
          TransactionType.transfer => -item.amount,
        };
      }
      if (item.type == TransactionType.transfer &&
          item.toAccountId == account.id) {
        value += item.amount;
      }
      spots.add(FlSpot((index + 1).toDouble(), value));
    }
    return SizedBox(
      height: 84,
      child: Semantics(
        label: 'Andamento del saldo del conto',
        child: LineChart(
          LineChartData(
            titlesData: const FlTitlesData(show: false),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                dotData: const FlDotData(show: false),
                barWidth: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

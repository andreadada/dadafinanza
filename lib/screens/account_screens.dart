import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../main.dart';
import '../models/models.dart';
import '../widgets/ui_helpers.dart';
import 'quick_add_page.dart';
import 'transaction_screens.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final active = state.activeAccounts;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conti'),
        actions: [
          IconButton(tooltip: 'Nuovo conto', onPressed: () => showAccountEditor(context), icon: const Icon(Icons.add_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Text('PATRIMONIO', style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.1)),
          const SizedBox(height: 6),
          Text(state.hideBalance ? '••••••' : moneyFor(state, state.totalBalance), style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 28),
          if (active.isEmpty)
            EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Nessun conto',
              subtitle: 'Crea un conto oppure registra un movimento come Non assegnato.',
              action: FilledButton.icon(onPressed: () => showAccountEditor(context), icon: const Icon(Icons.add_rounded), label: const Text('Crea conto')),
            )
          else
            ...active.map((account) => Column(children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                minVerticalPadding: 12,
                leading: CircleAvatar(backgroundColor: Color(account.colorValue).withValues(alpha: .14), child: Icon(accountIcon(account.iconKey), color: Color(account.colorValue))),
                title: Row(children: [Expanded(child: Text(account.name, style: const TextStyle(fontWeight: FontWeight.w800))), if (account.isLocked) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.lock_rounded, size: 16))]),
                subtitle: Text(account.accountType.label),
                trailing: Text(state.hideBalance || account.hideBalance ? '••••' : moneyFor(state, account.balance), style: const TextStyle(fontWeight: FontWeight.w800)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountDetailPage(accountId: account.id))),
              ),
              const Divider(height: 1),
            ])),
          if (state.archivedAccounts.isNotEmpty) ...[
            const SizedBox(height: 28),
            SectionTitle('Archiviati', trailing: Text('${state.archivedAccounts.length}')),
            ...state.archivedAccounts.map((account) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(accountIcon(account.iconKey)),
              title: Text(account.name),
              subtitle: const Text('Conto archiviato'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountDetailPage(accountId: account.id))),
            )),
          ],
        ],
      ),
    );
  }
}

class AccountDetailPage extends StatelessWidget {
  const AccountDetailPage({required this.accountId, super.key});
  final int accountId;

  Future<void> _delete(BuildContext context, Account account, AppState state) async {
    final movementCount = state.transactionCountForAccount(account.id);
    final recurringCount = state.recurringCountForAccount(account.id);
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Eliminare “${account.name}”?',
      message: 'Il conto ha $movementCount movimenti e $recurringCount ricorrenti collegati. Archiviare è l’opzione consigliata. Eliminando definitivamente, i movimenti collegati verranno rimossi e i saldi degli altri conti verranno corretti.',
      confirmLabel: 'Elimina definitivamente',
    );
    if (!confirmed) return;
    await state.deleteAccount(account);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final account = state.accountById(accountId);
    if (account == null) return const Scaffold(body: Center(child: Text('Conto non trovato')));
    final movement = state.transactions.where((t) => t.accountId == account.id || t.toAccountId == account.id).take(8).toList();
    final recurring = state.recurring.where((r) => r.accountId == account.id && r.enabled).take(4).toList();
    final income = state.accountMonthTotal(account.id, TransactionType.income);
    final expense = state.accountMonthTotal(account.id, TransactionType.expense);
    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Azioni conto',
            onSelected: (value) async {
              if (value == 'edit') await showAccountEditor(context, existing: account);
              if (value == 'lock') await state.updateAccount(account.copyWith(isLocked: !account.isLocked));
              if (value == 'archive') await state.updateAccount(account.copyWith(isArchived: !account.isArchived));
              if (value == 'total') await state.updateAccount(account.copyWith(includeInTotal: !account.includeInTotal));
              if (value == 'analytics') await state.updateAccount(account.copyWith(includeInAnalytics: !account.includeInAnalytics));
              if (value == 'hide') await state.updateAccount(account.copyWith(hideBalance: !account.hideBalance));
              if (value == 'delete' && context.mounted) await _delete(context, account, state);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Modifica conto')),
              PopupMenuItem(value: 'lock', child: Text(account.isLocked ? 'Sblocca conto' : 'Blocca conto')),
              PopupMenuItem(value: 'archive', child: Text(account.isArchived ? 'Ripristina conto' : 'Archivia conto')),
              PopupMenuItem(value: 'total', child: Text(account.includeInTotal ? 'Escludi dal patrimonio' : 'Includi nel patrimonio')),
              PopupMenuItem(value: 'analytics', child: Text(account.includeInAnalytics ? 'Escludi dalle statistiche' : 'Includi nelle statistiche')),
              PopupMenuItem(value: 'hide', child: Text(account.hideBalance ? 'Mostra saldo' : 'Nascondi saldo')),
              PopupMenuItem(value: 'delete', child: Text('Elimina conto', style: TextStyle(color: Theme.of(context).colorScheme.error))),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          Row(children: [
            CircleAvatar(radius: 28, backgroundColor: Color(account.colorValue).withValues(alpha: .14), child: Icon(accountIcon(account.iconKey), color: Color(account.colorValue), size: 28)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(account.accountType.label, style: Theme.of(context).textTheme.bodyMedium),
              Text(state.hideBalance || account.hideBalance ? '••••••' : moneyFor(state, account.balance), style: Theme.of(context).textTheme.headlineLarge),
            ])),
            if (account.isLocked) const Chip(avatar: Icon(Icons.lock_rounded, size: 16), label: Text('Bloccato')),
          ]),
          if (account.note?.isNotEmpty == true) ...[const SizedBox(height: 10), Text(account.note!)],
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _QuickAccountAction(icon: Icons.arrow_upward_rounded, label: 'Spesa', onTap: account.isLocked || account.isArchived ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuickAddPage(initialTypeName: 'expense', initialAccountId: account.id))))),
            const SizedBox(width: 8),
            Expanded(child: _QuickAccountAction(icon: Icons.arrow_downward_rounded, label: 'Entrata', onTap: account.isLocked || account.isArchived ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuickAddPage(initialTypeName: 'income', initialAccountId: account.id))))),
            const SizedBox(width: 8),
            Expanded(child: _QuickAccountAction(icon: Icons.swap_horiz_rounded, label: 'Trasferisci', onTap: account.isLocked || account.isArchived ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuickAddPage(initialTypeName: 'transfer', initialAccountId: account.id))))),
          ]),
          const SizedBox(height: 28),
          const SectionTitle('Questo mese'),
          FlatMetric(label: 'Entrate', value: moneyFor(state, income), icon: Icons.arrow_downward_rounded, color: transactionColor(context, TransactionType.income)),
          const Divider(height: 1),
          FlatMetric(label: 'Spese', value: moneyFor(state, expense), icon: Icons.arrow_upward_rounded, color: transactionColor(context, TransactionType.expense)),
          const Divider(height: 1),
          FlatMetric(label: 'Cash flow', value: moneyFor(state, income - expense, signed: true), icon: Icons.compare_arrows_rounded),
          const SizedBox(height: 28),
          SectionTitle('Movimenti recenti', trailing: Text('${state.transactionCountForAccount(account.id)}')),
          if (movement.isEmpty)
            const EmptyState(icon: Icons.receipt_long_outlined, title: 'Nessun movimento', subtitle: 'I movimenti di questo conto compariranno qui.')
          else
            ...movement.map((t) => TransactionListTile(item: t)),
          if (recurring.isNotEmpty) ...[
            const SizedBox(height: 28),
            const SectionTitle('Prossimi ricorrenti'),
            ...recurring.map((r) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.repeat_rounded), title: Text(r.name), subtitle: Text(DateFormat('dd MMM', 'it_IT').format(r.nextDate)), trailing: Text(moneyFor(state, r.amount)))),
          ],
        ],
      ),
    );
  }
}

class _QuickAccountAction extends StatelessWidget {
  const _QuickAccountAction({required this.icon, required this.label, required this.onTap});
  final IconData icon; final String label; final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, size: 18), label: Text(label), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)));
}

Future<Account?> showAccountEditor(BuildContext context, {Account? existing}) async {
  final state = AppScope.of(context);
  final name = TextEditingController(text: existing?.name ?? '');
  final balance = TextEditingController(text: (existing?.balance ?? 0).toStringAsFixed(2));
  final note = TextEditingController(text: existing?.note ?? '');
  var type = existing?.accountType ?? AccountType.checking;
  var iconKey = existing?.iconKey ?? 'wallet';
  var color = Color(existing?.colorValue ?? categoryPalette.first.toARGB32());
  var includeInTotal = existing?.includeInTotal ?? true;
  var includeInAnalytics = existing?.includeInAnalytics ?? true;
  var hideBalance = existing?.hideBalance ?? false;

  final result = await showModalBottomSheet<Account>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(builder: (context, setSheetState) => Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(existing == null ? 'Nuovo conto' : 'Modifica conto', style: Theme.of(context).textTheme.titleLarge),
        TextField(controller: name, autofocus: existing == null, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nome')),
        DropdownButtonFormField<AccountType>(initialValue: type, decoration: const InputDecoration(labelText: 'Tipo'), items: AccountType.values.map((item) => DropdownMenuItem(value: item, child: Text(item.label))).toList(), onChanged: (value) => setSheetState(() => type = value ?? type)),
        TextField(controller: balance, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: InputDecoration(labelText: existing == null ? 'Saldo iniziale' : 'Saldo / riconciliazione', suffixText: '€')),
        ListTile(contentPadding: EdgeInsets.zero, leading: Icon(accountIcon(iconKey), color: color), title: const Text('Icona'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () async { final picked = await showIconPicker(context, options: accountIconOptions, selected: iconKey); if (picked != null) setSheetState(() => iconKey = picked); }),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: categoryPalette.map((item) => InkWell(customBorder: const CircleBorder(), onTap: () => setSheetState(() => color = item), child: SizedBox.square(dimension: 44, child: Center(child: Container(width: 28, height: 28, decoration: BoxDecoration(color: item, shape: BoxShape.circle), child: item == color ? const Icon(Icons.check_rounded, size: 17, color: Colors.white) : null))))).toList()),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Includi nel patrimonio'), value: includeInTotal, onChanged: (value) => setSheetState(() => includeInTotal = value)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Includi nelle statistiche'), value: includeInAnalytics, onChanged: (value) => setSheetState(() => includeInAnalytics = value)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Nascondi saldo del conto'), value: hideBalance, onChanged: (value) => setSheetState(() => hideBalance = value)),
        TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Nota opzionale')),
        const SizedBox(height: 22),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () async {
          final accountName = name.text.trim(); final parsed = double.tryParse(balance.text.replaceAll(',', '.'));
          if (accountName.isEmpty || parsed == null) return;
          if (existing == null) {
            final created = await state.addAccount(name: accountName, balance: parsed, colorValue: color.toARGB32(), iconKey: iconKey, type: type, includeInTotal: includeInTotal, includeInAnalytics: includeInAnalytics, hideBalance: hideBalance, note: note.text.trim().isEmpty ? null : note.text.trim());
            if (context.mounted) Navigator.pop(context, created);
          } else {
            final edited = existing.copyWith(name: accountName, balance: parsed, colorValue: color.toARGB32(), iconKey: iconKey, accountType: type, includeInTotal: includeInTotal, includeInAnalytics: includeInAnalytics, hideBalance: hideBalance, note: note.text.trim().isEmpty ? null : note.text.trim());
            await state.updateAccount(edited);
            if (context.mounted) Navigator.pop(context, edited);
          }
        }, child: Text(existing == null ? 'Crea conto' : 'Salva modifiche'))),
      ])),
    )),
  );
  name.dispose(); balance.dispose(); note.dispose();
  return result;
}

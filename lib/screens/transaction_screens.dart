import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../main.dart';
import '../models/models.dart';
import '../widgets/ui_helpers.dart';
import 'quick_add_page.dart';

class TransactionListTile extends StatelessWidget {
  const TransactionListTile({
    required this.item,
    this.selected = false,
    this.onLongPress,
    super.key,
  });
  final FinanceTransaction item;
  final bool selected;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final category = state.categoryById(item.categoryId);
    final account = state.accountById(item.accountId);
    final unassigned = account?.isSystem == true;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 10,
      selected: selected,
      leading: CircleAvatar(
        backgroundColor: (category == null
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Color(category.colorValue).withValues(alpha: .13)),
        child: Icon(
          category == null
              ? (item.type == TransactionType.transfer
                    ? Icons.swap_horiz_rounded
                    : Icons.receipt_long_rounded)
              : categoryIcon(category.iconKey),
          color: category == null ? null : Color(category.colorValue),
        ),
      ),
      title: Text(
        item.type == TransactionType.transfer
            ? 'Trasferimento'
            : (category?.name ?? 'Senza categoria'),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${unassigned ? 'Non assegnato' : account?.name ?? 'Conto'} · ${DateFormat('dd MMM, HH:mm', 'it_IT').format(item.date)}${item.note?.isNotEmpty == true ? ' · ${item.note}' : ''}',
      ),
      trailing: Text(
        item.type == TransactionType.expense
            ? '-${moneyFor(state, item.amount)}'
            : item.type == TransactionType.income
            ? '+${moneyFor(state, item.amount)}'
            : moneyFor(state, item.amount),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: transactionColor(context, item.type),
        ),
      ),
      onLongPress: onLongPress,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionDetailPage(transactionId: item.id),
        ),
      ),
    );
  }
}

class TransactionDetailPage extends StatelessWidget {
  const TransactionDetailPage({required this.transactionId, super.key});
  final int transactionId;

  Future<void> _delete(
    BuildContext context,
    FinanceTransaction item,
    AppState state,
  ) async {
    final confirmed =
        !state.confirmDelete ||
        await confirmDestructiveAction(
          context,
          title: 'Eliminare il movimento?',
          message: 'Il saldo del conto verrà ricalcolato automaticamente.',
        );
    if (!confirmed) return;
    await state.deleteTransaction(item);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _editSimple(
    BuildContext context,
    FinanceTransaction item,
    AppState state, {
    TransactionType? type,
    int? categoryId,
    int? accountId,
    bool? includeInAnalytics,
  }) async {
    final next = item.copyWith(
      type: type ?? item.type,
      categoryId: categoryId ?? item.categoryId,
      accountId: accountId ?? item.accountId,
      includeInAnalytics: includeInAnalytics ?? item.includeInAnalytics,
      updatedAt: DateTime.now(),
    );
    try {
      await state.updateTransaction(item, next);
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final item = state.transactionById(transactionId);
    if (item == null)
      return const Scaffold(body: Center(child: Text('Movimento non trovato')));
    final category = state.categoryById(item.categoryId);
    final account = state.accountById(item.accountId);
    final destination = state.accountById(item.toAccountId);
    final splits = state.splitsFor(item.id);
    final refundOf = state.transactionById(item.refundOfTransactionId);
    final refunded = state.refundsFor(item.id);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimento'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Azioni movimento',
            onSelected: (value) async {
              if (value == 'edit')
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuickAddPage(editing: item),
                  ),
                );
              if (value == 'duplicate') {
                await state.duplicateTransaction(item);
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Movimento duplicato.')),
                  );
              }
              if (value == 'toggle_analytics')
                await _editSimple(
                  context,
                  item,
                  state,
                  includeInAnalytics: !item.includeInAnalytics,
                );
              if (value == 'expense')
                await _editSimple(
                  context,
                  item,
                  state,
                  type: TransactionType.expense,
                );
              if (value == 'income')
                await _editSimple(
                  context,
                  item,
                  state,
                  type: TransactionType.income,
                );
              if (value == 'split' && context.mounted)
                await showSplitEditor(context, item);
              if (value == 'refund' && context.mounted)
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuickAddPage(
                      initialTypeName: 'income',
                      refundOfTransactionId: item.id,
                    ),
                  ),
                );
              if (value == 'recurring' && context.mounted) {
                final account = state.accountById(item.accountId);
                if (account == null ||
                    account.isLocked ||
                    account.isArchived ||
                    account.isSystem) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Assegna il movimento a un conto attivo prima di creare una ricorrenza.',
                      ),
                    ),
                  );
                } else {
                  await state.addRecurring(
                    name: category?.name ?? item.note ?? 'Movimento ricorrente',
                    amount: item.amount,
                    type: item.type == TransactionType.transfer
                        ? TransactionType.expense
                        : item.type,
                    accountId: item.accountId,
                    categoryId: item.categoryId,
                    frequency: 'Mensile',
                    nextDate: DateTime(
                      item.date.year,
                      item.date.month + 1,
                      item.date.day,
                    ),
                    note: item.note,
                  );
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Ricorrenza mensile creata. Puoi modificarla in Pianifica.',
                        ),
                      ),
                    );
                }
              }
              if (value == 'delete' && context.mounted)
                await _delete(context, item, state);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Modifica')),
              const PopupMenuItem(value: 'duplicate', child: Text('Duplica')),
              if (item.type != TransactionType.expense)
                const PopupMenuItem(
                  value: 'expense',
                  child: Text('Trasforma in spesa'),
                ),
              if (item.type != TransactionType.income)
                const PopupMenuItem(
                  value: 'income',
                  child: Text('Trasforma in entrata'),
                ),
              if (item.type != TransactionType.transfer)
                const PopupMenuItem(
                  value: 'split',
                  child: Text('Dividi movimento'),
                ),
              if (item.type == TransactionType.expense)
                const PopupMenuItem(
                  value: 'refund',
                  child: Text('Registra rimborso'),
                ),
              if (item.type != TransactionType.transfer)
                const PopupMenuItem(
                  value: 'recurring',
                  child: Text('Rendi ricorrente'),
                ),
              PopupMenuItem(
                value: 'toggle_analytics',
                child: Text(
                  item.includeInAnalytics
                      ? 'Escludi dalle statistiche'
                      : 'Includi nelle statistiche',
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Elimina',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
        children: [
          Text(
            item.type.label.toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(letterSpacing: 1.1),
          ),
          const SizedBox(height: 6),
          Text(
            item.type == TransactionType.expense
                ? '-${moneyFor(state, item.amount)}'
                : item.type == TransactionType.income
                ? '+${moneyFor(state, item.amount)}'
                : moneyFor(state, item.amount),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: transactionColor(context, item.type),
            ),
          ),
          const SizedBox(height: 22),
          FlatMetric(
            label: 'Categoria',
            value:
                category?.name ??
                (item.type == TransactionType.transfer
                    ? 'Trasferimento'
                    : 'Senza categoria'),
            icon: category == null
                ? Icons.category_outlined
                : categoryIcon(category.iconKey),
          ),
          const Divider(height: 1),
          FlatMetric(
            label: item.type == TransactionType.transfer ? 'Da' : 'Conto',
            value: account?.isSystem == true
                ? 'Non assegnato'
                : account?.name ?? '—',
            icon: account == null
                ? Icons.account_balance_wallet_outlined
                : accountIcon(account.iconKey),
          ),
          if (destination != null) ...[
            const Divider(height: 1),
            FlatMetric(
              label: 'A',
              value: destination.name,
              icon: accountIcon(destination.iconKey),
            ),
          ],
          const Divider(height: 1),
          FlatMetric(
            label: 'Data',
            value: DateFormat('dd MMMM yyyy, HH:mm', 'it_IT').format(item.date),
            icon: Icons.calendar_today_outlined,
          ),
          if (!item.includeInAnalytics) ...[
            const Divider(height: 1),
            const FlatMetric(
              label: 'Statistiche',
              value: 'Escluso',
              icon: Icons.visibility_off_outlined,
            ),
          ],
          if (item.note?.isNotEmpty == true) ...[
            const SizedBox(height: 24),
            const SectionTitle('Nota'),
            Text(item.note!),
          ],
          if (item.tags.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionTitle('Tag'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.tags
                  .map((tag) => Chip(label: Text('#$tag')))
                  .toList(),
            ),
          ],
          if (item.receiptPath?.isNotEmpty == true) ...[
            const SizedBox(height: 24),
            const SectionTitle('Ricevuta'),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(
                File(item.receiptPath!),
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.broken_image_outlined),
                  title: Text('Ricevuta non disponibile'),
                ),
              ),
            ),
          ],
          if (splits.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionTitle('Divisione'),
            ...splits.map(
              (split) => FlatMetric(
                label:
                    state.categoryById(split.categoryId)?.name ?? 'Categoria',
                value: moneyFor(state, split.amount),
                icon: categoryIcon(
                  state.categoryById(split.categoryId)?.iconKey ?? 'category',
                ),
              ),
            ),
          ],
          if (refundOf != null) ...[
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.replay_rounded),
              title: const Text('Rimborso collegato'),
              subtitle: Text('Rimborso del movimento #${refundOf.id}'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TransactionDetailPage(transactionId: refundOf.id),
                ),
              ),
            ),
          ],
          if (refunded > 0) ...[
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.replay_circle_filled_rounded),
              title: Text('Rimborsato ${moneyFor(state, refunded)}'),
              subtitle: Text(
                'Spesa effettiva ${moneyFor(state, state.effectiveExpense(item))}',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showSplitEditor(
  BuildContext context,
  FinanceTransaction item,
) async {
  final state = AppScope.of(context);
  final expenseCategories = state.categoriesFor(TransactionType.expense);
  if (expenseCategories.length < 2) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Servono almeno due categorie di spesa per dividere il movimento.',
        ),
      ),
    );
    return;
  }
  final existing = state.splitsFor(item.id);
  final rows = <_SplitDraft>[];
  if (existing.isEmpty) {
    rows.add(
      _SplitDraft(
        categoryId: expenseCategories.first.id,
        controller: TextEditingController(),
      ),
    );
    rows.add(
      _SplitDraft(
        categoryId: expenseCategories[1].id,
        controller: TextEditingController(),
      ),
    );
  } else {
    for (final split in existing)
      rows.add(
        _SplitDraft(
          categoryId: split.categoryId,
          controller: TextEditingController(
            text: split.amount.toStringAsFixed(2),
          ),
        ),
      );
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dividi ${moneyFor(state, item.amount)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ...List.generate(rows.length, (index) {
                final row = rows[index];
                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: row.categoryId,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                        ),
                        items: expenseCategories
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            row.categoryId = value ?? row.categoryId,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: row.controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Importo',
                          suffixText: '€',
                        ),
                      ),
                    ),
                    if (rows.length > 2)
                      IconButton(
                        tooltip: 'Rimuovi',
                        onPressed: () => setSheetState(() {
                          rows[index].controller.dispose();
                          rows.removeAt(index);
                        }),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
                  ],
                );
              }),
              TextButton.icon(
                onPressed: () => setSheetState(
                  () => rows.add(
                    _SplitDraft(
                      categoryId: expenseCategories.first.id,
                      controller: TextEditingController(),
                    ),
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Aggiungi parte'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final values = <TransactionSplit>[];
                    for (final row in rows) {
                      final value = double.tryParse(
                        row.controller.text.replaceAll(',', '.'),
                      );
                      if (value == null || value <= 0) return;
                      values.add(
                        TransactionSplit(
                          id: 0,
                          transactionId: item.id,
                          amount: value,
                          categoryId: row.categoryId,
                        ),
                      );
                    }
                    try {
                      await state.replaceSplits(item.id, values, item.amount);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              e.toString().replaceFirst('Bad state: ', ''),
                            ),
                          ),
                        );
                    }
                  },
                  child: const Text('Salva divisione'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  for (final row in rows) row.controller.dispose();
}

class _SplitDraft {
  _SplitDraft({required this.categoryId, required this.controller});
  int categoryId;
  final TextEditingController controller;
}

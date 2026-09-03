import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_helpers.dart';

class QuickAddPage extends StatefulWidget {
  const QuickAddPage({
    this.initialCategoryName,
    this.initialTypeName,
    super.key,
  });

  final String? initialCategoryName;
  final String? initialTypeName;

  @override
  State<QuickAddPage> createState() => _QuickAddPageState();
}

class _QuickAddPageState extends State<QuickAddPage> {
  final amount = TextEditingController();
  final note = TextEditingController();
  final tag = TextEditingController();
  final picker = ImagePicker();

  late TransactionType type;
  int? accountId;
  int? toAccountId;
  int? categoryId;
  DateTime date = DateTime.now();
  final tags = <String>[];
  XFile? receipt;
  bool saving = false;
  bool _defaultsSet = false;

  @override
  void initState() {
    super.initState();
    type = switch (widget.initialTypeName) {
      'income' => TransactionType.income,
      'transfer' => TransactionType.transfer,
      _ => TransactionType.expense,
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_defaultsSet) {
      _defaultsSet = true;
      _setDefaults();
    }
  }

  void _setDefaults() {
    final state = AppScope.of(context);
    if (state.accounts.isNotEmpty) {
      accountId ??= state.accounts.first.id;
      if (state.accounts.length > 1) toAccountId ??= state.accounts[1].id;
    }
    final categories = state.categoriesFor(type);
    if (widget.initialCategoryName != null) {
      for (final category in categories) {
        if (category.name.toLowerCase() ==
            widget.initialCategoryName!.toLowerCase()) {
          categoryId = category.id;
          break;
        }
      }
    }
    categoryId ??= categories.firstOrNull?.id;
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    tag.dispose();
    super.dispose();
  }

  void _changeType(TransactionType value) {
    final state = AppScope.of(context);
    setState(() {
      type = value;
      categoryId = state.categoriesFor(value).firstOrNull?.id;
      if (value == TransactionType.transfer && state.accounts.length > 1) {
        toAccountId ??= state.accounts.where((a) => a.id != accountId).first.id;
      }
    });
  }

  Future<void> _createAccount() async {
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
                  final initial =
                      double.tryParse(balance.text.replaceAll(',', '.')) ?? 0;
                  await state.addAccount(accountName, initial, 0xFF8E8E93);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  if (mounted) {
                    setState(() {
                      accountId = state.accounts.last.id;
                      if (type == TransactionType.transfer &&
                          state.accounts.length > 1) {
                        toAccountId = state.accounts
                            .where((a) => a.id != accountId)
                            .first
                            .id;
                      }
                    });
                  }
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

  Future<void> _createCategory() async {
    if (type == TransactionType.transfer) return;
    final created = await showCategoryCreator(
      context,
      AppScope.of(context),
      initialType: type,
      lockType: true,
    );
    if (created != null && mounted) {
      setState(() => categoryId = created.id);
    }
  }

  Future<void> _pickReceipt(ImageSource source) async {
    final result = await picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (result != null && mounted) setState(() => receipt = result);
  }

  Future<void> _save() async {
    final state = AppScope.of(context);
    final parsed = double.tryParse(amount.text.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un importo maggiore di 0.')),
      );
      return;
    }
    if (accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scegli o crea un conto.')),
      );
      return;
    }
    if (type != TransactionType.transfer && categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scegli o crea una categoria.')),
      );
      return;
    }
    if (type == TransactionType.transfer &&
        (toAccountId == null || toAccountId == accountId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scegli due conti diversi.')),
      );
      return;
    }

    setState(() => saving = true);
    await state.addTransaction(
      type: type,
      amount: parsed,
      accountId: accountId!,
      toAccountId: type == TransactionType.transfer ? toAccountId : null,
      categoryId: type == TransactionType.transfer ? null : categoryId,
      date: date,
      note: note.text.trim().isEmpty ? null : note.text.trim(),
      tags: tags,
      receiptPath: receipt?.path,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final categories = type == TransactionType.transfer
        ? const <Category>[]
        : state.categoriesFor(type);
    final canSave = state.accounts.isNotEmpty &&
        (type == TransactionType.transfer
            ? state.accounts.length > 1
            : categories.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (type) {
          TransactionType.expense => 'Nuova spesa',
          TransactionType.income => 'Nuova entrata',
          TransactionType.transfer => 'Nuovo giroconto',
        }),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          SegmentedButton<TransactionType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: TransactionType.expense,
                icon: Icon(Icons.arrow_upward_rounded),
                label: Text('Spesa'),
              ),
              ButtonSegment(
                value: TransactionType.income,
                icon: Icon(Icons.arrow_downward_rounded),
                label: Text('Entrata'),
              ),
              ButtonSegment(
                value: TransactionType.transfer,
                icon: Icon(Icons.swap_horiz_rounded),
                label: Text('Giroconto'),
              ),
            ],
            selected: {type},
            onSelectionChanged: (value) => _changeType(value.first),
          ),
          const SizedBox(height: 28),
          Semantics(
            label: 'Importo del movimento in euro',
            textField: true,
            child: TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                  ),
              decoration: const InputDecoration(
                hintText: '0,00',
                suffixText: '€',
                suffixStyle: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.muted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          _SectionHeader(
            title: 'Conto',
            action: TextButton.icon(
              onPressed: _createAccount,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nuovo conto'),
            ),
          ),
          if (state.accounts.isEmpty)
            _InlineMessage(
              icon: Icons.account_balance_wallet_outlined,
              text: 'Non hai ancora conti. Creane uno per continuare.',
              actionLabel: 'Crea conto',
              onTap: _createAccount,
            )
          else
            DropdownButtonFormField<int>(
              initialValue: accountId,
              hint: const Text('Scegli un conto'),
              items: state.accounts
                  .map(
                    (account) => DropdownMenuItem(
                      value: account.id,
                      child: Text(
                        '${account.name}  ·  ${money(account.balance)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                accountId = value;
                if (toAccountId == value) {
                  toAccountId = state.accounts
                      .where((a) => a.id != value)
                      .firstOrNull
                      ?.id;
                }
              }),
            ),
          if (type == TransactionType.transfer) ...[
            const SizedBox(height: 18),
            if (state.accounts.length < 2)
              _InlineMessage(
                icon: Icons.swap_horiz_rounded,
                text: 'Per un giroconto servono almeno due conti.',
                actionLabel: 'Aggiungi conto',
                onTap: _createAccount,
              )
            else
              DropdownButtonFormField<int>(
                key: ValueKey('destination-$accountId-$toAccountId'),
                initialValue: toAccountId,
                decoration: const InputDecoration(labelText: 'Destinazione'),
                items: state.accounts
                    .where((a) => a.id != accountId)
                    .map(
                      (account) => DropdownMenuItem(
                        value: account.id,
                        child: Text(account.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => toAccountId = value),
              ),
          ],
          if (type != TransactionType.transfer) ...[
            const SizedBox(height: 30),
            _SectionHeader(
              title: 'Categoria',
              action: TextButton.icon(
                onPressed: _createCategory,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nuova'),
              ),
            ),
            if (categories.isEmpty)
              _InlineMessage(
                icon: Icons.category_outlined,
                text: 'Nessuna categoria ${type == TransactionType.expense ? 'di spesa' : 'di entrata'}.',
                actionLabel: 'Crea categoria',
                onTap: _createCategory,
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 24) / 4;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: [
                      ...categories.map(
                        (category) => _CategoryChoice(
                          width: width,
                          category: category,
                          selected: category.id == categoryId,
                          onTap: () => setState(() => categoryId = category.id),
                        ),
                      ),
                      _NewCategoryChoice(width: width, onTap: _createCategory),
                    ],
                  );
                },
              ),
          ],
          const SizedBox(height: 32),
          const SectionTitle('Dettagli'),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDate: date,
              );
              if (picked != null) {
                setState(() => date = DateTime(
                      picked.year,
                      picked.month,
                      picked.day,
                      DateTime.now().hour,
                      DateTime.now().minute,
                    ));
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Data')),
                  Text(
                    DateFormat('dd/MM/yyyy').format(date),
                    style: const TextStyle(color: AppTheme.muted),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          TextField(
            controller: note,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nota opzionale',
              hintText: 'Aggiungi una nota',
            ),
          ),
          const SizedBox(height: 24),
          const SectionTitle('Tag'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: tag,
                  onSubmitted: (_) => _addTag(),
                  decoration: const InputDecoration(
                    hintText: 'Netflix, Vinted, aperitivo…',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Aggiungi tag',
                onPressed: _addTag,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags
                  .map(
                    (value) => InputChip(
                      label: Text(value),
                      onDeleted: () => setState(() => tags.remove(value)),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          const SectionTitle('Ricevuta'),
          if (receipt == null)
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _pickReceipt(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Fotocamera'),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  onPressed: () => _pickReceipt(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galleria'),
                ),
              ],
            )
          else
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(
                    File(receipt!.path),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton.filled(
                    tooltip: 'Rimuovi ricevuta',
                    onPressed: () => setState(() => receipt = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton.icon(
          onPressed: saving || !canSave ? null : _save,
          icon: saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: Text(saving ? 'Salvataggio…' : 'Salva'),
        ),
      ),
    );
  }

  void _addTag() {
    final value = tag.text.trim();
    if (value.isEmpty || tags.contains(value)) return;
    setState(() {
      tags.add(value);
      tag.clear();
    });
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action});

  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          action,
        ],
      );
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, color: AppTheme.muted, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
            TextButton(onPressed: onTap, child: Text(actionLabel)),
          ],
        ),
      );
}

class _CategoryChoice extends StatelessWidget {
  const _CategoryChoice({
    required this.width,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(category.colorValue);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Categoria ${category.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: width,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withValues(alpha: .10) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(categoryIcon(category.iconKey), color: color, size: 27),
              const SizedBox(height: 7),
              Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              if (selected) ...[
                const SizedBox(height: 4),
                const Icon(Icons.check_circle_rounded, size: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NewCategoryChoice extends StatelessWidget {
  const _NewCategoryChoice({required this.width, required this.onTap});

  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Crea nuova categoria',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: width,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Column(
                children: [
                  Icon(Icons.add_circle_outline_rounded, size: 27),
                  SizedBox(height: 7),
                  Text(
                    'Nuova',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

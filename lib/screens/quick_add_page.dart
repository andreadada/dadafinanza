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
      if (state.accounts.length > 1) {
        toAccountId ??= state.accounts[1].id;
      }
    }
    final categories = state.categoriesFor(type);
    if (widget.initialCategoryName != null) {
      for (final c in categories) {
        if (c.name.toLowerCase() == widget.initialCategoryName!.toLowerCase()) {
          categoryId = c.id;
          break;
        }
      }
    }
    categoryId ??= categories.isEmpty ? null : categories.first.id;
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    tag.dispose();
    super.dispose();
  }

  void _changeType(TransactionType value) {
    setState(() {
      type = value;
      final categories = AppScope.of(context).categoriesFor(value);
      categoryId = categories.isEmpty ? null : categories.first.id;
    });
  }

  Future<void> _createFirstAccount() async {
    final state = AppScope.of(context);
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crea un conto'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Es. Portafoglio'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              await state.addAccount(
                controller.text.trim(),
                0,
                0xFF8E8E93,
              );
              if (context.mounted) Navigator.pop(context);
              if (mounted && state.accounts.isNotEmpty) {
                setState(() => accountId = state.accounts.first.id);
              }
            },
            child: const Text('Crea a 0 €'),
          ),
        ],
      ),
    );
    controller.dispose();
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
    if (parsed == null || parsed <= 0 || accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci un importo valido e scegli il conto.'),
        ),
      );
      return;
    }
    if (type != TransactionType.transfer && categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crea e scegli una categoria.')),
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
      appBar: AppBar(title: const Text('Nuovo movimento')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<TransactionType>(
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
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppTheme.border),
            ),
            child: TextField(
              controller: amount,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                  ),
              decoration: const InputDecoration(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
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
          const SizedBox(height: 26),
          const SectionTitle('Conto'),
          if (state.accounts.isEmpty)
            _SetupNotice(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Serve un conto',
              subtitle: 'Crealo ora con saldo iniziale 0 €.',
              label: 'Crea conto',
              onTap: _createFirstAccount,
            )
          else
            DropdownButtonFormField<int>(
              initialValue: accountId,
              hint: const Text('Seleziona conto'),
              items: state.accounts
                  .map(
                    (a) => DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.name}  •  ${money(a.balance)}'),
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
          if (type == TransactionType.transfer && state.accounts.length > 1) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('destination-$accountId-$toAccountId'),
              initialValue: toAccountId,
              hint: const Text('Conto di destinazione'),
              decoration: const InputDecoration(labelText: 'Destinazione'),
              items: state.accounts
                  .where((a) => a.id != accountId)
                  .map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => toAccountId = value),
            ),
          ],
          if (type == TransactionType.transfer && state.accounts.length == 1) ...[
            const SizedBox(height: 12),
            const _SetupNotice(
              icon: Icons.swap_horiz_rounded,
              title: 'Serve un secondo conto',
              subtitle: 'Un giroconto richiede un conto di origine e uno di arrivo.',
            ),
          ],
          if (type != TransactionType.transfer) ...[
            const SizedBox(height: 26),
            const SectionTitle('Categoria'),
            if (categories.isEmpty)
              const _SetupNotice(
                icon: Icons.category_outlined,
                title: 'Nessuna categoria',
                subtitle: 'Creala da Altro → Categorie scegliendo anche l’icona.',
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: categories.map((category) {
                  final selected = category.id == categoryId;
                  final color = Color(category.colorValue);
                  return InkWell(
                    onTap: () => setState(() => categoryId = category.id),
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 104,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: .08)
                            : AppTheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected ? Colors.white : AppTheme.border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: .18),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              categoryIcon(category.iconKey),
                              color: color,
                              size: 21,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            category.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
          const SizedBox(height: 26),
          const SectionTitle('Dettagli'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Data'),
                  trailing: Text(DateFormat('dd/MM/yyyy').format(date)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: date,
                    );
                    if (picked != null) {
                      setState(
                        () => date = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          DateTime.now().hour,
                          DateTime.now().minute,
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: note,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.notes_rounded),
                      hintText: 'Nota opzionale',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionTitle('Tag'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: tag,
                  onSubmitted: (_) => _addTag(),
                  decoration: const InputDecoration(
                    hintText: 'Es. Netflix, Vinted, Aperitivo',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _addTag,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
          const SizedBox(height: 22),
          const SectionTitle('Ricevuta'),
          if (receipt == null)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickReceipt(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Scatta'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickReceipt(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galleria'),
                  ),
                ),
              ],
            )
          else
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(
                    File(receipt!.path),
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filled(
                    onPressed: () => setState(() => receipt = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: saving || !canSave ? null : _save,
          icon: saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: Text(
            saving ? 'Salvataggio…' : 'Salva movimento',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
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

class _SetupNotice extends StatelessWidget {
  const _SetupNotice({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.label,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (label != null && onTap != null)
              TextButton(onPressed: onTap, child: Text(label!)),
          ],
        ),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

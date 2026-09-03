import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_helpers.dart';

class QuickAddPage extends StatefulWidget {
  const QuickAddPage({this.initialCategoryName, this.initialTypeName, super.key});

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

  Future<void> _pickReceipt(ImageSource source) async {
    final result = await picker.pickImage(source: source, imageQuality: 82, maxWidth: 1800);
    if (result != null && mounted) setState(() => receipt = result);
  }

  Future<void> _save() async {
    final state = AppScope.of(context);
    final parsed = double.tryParse(amount.text.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0 || accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inserisci un importo valido e scegli il conto.')));
      return;
    }
    if (type != TransactionType.transfer && categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scegli una categoria.')));
      return;
    }
    if (type == TransactionType.transfer && (toAccountId == null || toAccountId == accountId)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scegli due conti diversi per il giroconto.')));
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
    final categories = type == TransactionType.transfer ? const <Category>[] : state.categoriesFor(type);
    return Scaffold(
      appBar: AppBar(title: const Text('Nuovo movimento')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          SegmentedButton<TransactionType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: TransactionType.expense, icon: Icon(Icons.remove_rounded), label: Text('Spesa')),
              ButtonSegment(value: TransactionType.income, icon: Icon(Icons.add_rounded), label: Text('Entrata')),
              ButtonSegment(value: TransactionType.transfer, icon: Icon(Icons.swap_horiz_rounded), label: Text('Giroconto')),
            ],
            selected: {type},
            onSelectionChanged: (value) => _changeType(value.first),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w900),
            decoration: const InputDecoration(hintText: '0,00', suffixText: '€', suffixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 24),
          const SectionTitle('Conto'),
          DropdownButtonFormField<int>(
            initialValue: accountId,
            hint: const Text('Seleziona conto'),
            items: state.accounts.map((a) => DropdownMenuItem(value: a.id, child: Row(mainAxisSize: MainAxisSize.min, children: [CircleAvatar(radius: 9, backgroundColor: Color(a.colorValue)), const SizedBox(width: 10), Text('${a.name} • ${money(a.balance)}')]))).toList(),
            onChanged: (value) => setState(() {
              accountId = value;
              if (toAccountId == value) {
                toAccountId = state.accounts.where((a) => a.id != value).firstOrNull?.id;
              }
            }),
          ),
          if (type == TransactionType.transfer) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              key: ValueKey('destination-$accountId-$toAccountId'),
              initialValue: toAccountId,
              hint: const Text('Conto di destinazione'),
              decoration: const InputDecoration(labelText: 'Destinazione'),
              items: state.accounts.where((a) => a.id != accountId).map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
              onChanged: (value) => setState(() => toAccountId = value),
            ),
          ],
          if (type != TransactionType.transfer) ...[
            const SizedBox(height: 24),
            const SectionTitle('Categoria'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: categories.map((category) {
                final selected = category.id == categoryId;
                return InkWell(
                  onTap: () => setState(() => categoryId = category.id),
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 102,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
                    decoration: BoxDecoration(
                      color: selected ? Color(category.colorValue).withValues(alpha: .24) : const Color(0xFF13201B),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: selected ? Color(category.colorValue) : Colors.white.withValues(alpha: .06), width: selected ? 1.8 : 1),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(backgroundColor: Color(category.colorValue), child: Icon(categoryIcon(category.iconKey), color: Colors.white)),
                        const SizedBox(height: 8),
                        Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 24),
          const SectionTitle('Dettagli'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_today_rounded),
                  title: const Text('Data'),
                  trailing: Text(DateFormat('dd/MM/yyyy').format(date)),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: date);
                    if (picked != null) setState(() => date = DateTime(picked.year, picked.month, picked.day, DateTime.now().hour, DateTime.now().minute));
                  },
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(controller: note, minLines: 1, maxLines: 3, decoration: const InputDecoration(prefixIcon: Icon(Icons.notes_rounded), hintText: 'Nota opzionale')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Tag'),
          Row(
            children: [
              Expanded(child: TextField(controller: tag, onSubmitted: (_) => _addTag(), decoration: const InputDecoration(hintText: 'Es. Netflix, Vinted, Aperitivo'))),
              const SizedBox(width: 8),
              IconButton.filledTonal(onPressed: _addTag, icon: const Icon(Icons.add_rounded)),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: tags.map((value) => InputChip(label: Text(value), onDeleted: () => setState(() => tags.remove(value)))).toList()),
          ],
          const SizedBox(height: 20),
          const SectionTitle('Ricevuta / foto'),
          if (receipt == null)
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => _pickReceipt(ImageSource.camera), icon: const Icon(Icons.photo_camera_rounded), label: const Text('Scatta'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(onPressed: () => _pickReceipt(ImageSource.gallery), icon: const Icon(Icons.photo_library_rounded), label: const Text('Galleria'))),
              ],
            )
          else
            Stack(
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(File(receipt!.path), height: 170, width: double.infinity, fit: BoxFit.cover)),
                Positioned(top: 8, right: 8, child: IconButton.filled(onPressed: () => setState(() => receipt = null), icon: const Icon(Icons.close_rounded))),
              ],
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: type == TransactionType.expense ? const Color(0xFFFFB72B) : AppTheme.seed, foregroundColor: Colors.black),
          onPressed: saving ? null : _save,
          icon: saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
          label: Text(saving ? 'Salvataggio…' : 'Salva movimento', style: const TextStyle(fontWeight: FontWeight.w900)),
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

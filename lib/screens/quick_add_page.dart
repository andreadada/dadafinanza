import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../main.dart';
import '../models/models.dart';
import '../widgets/ui_helpers.dart';
import 'account_screens.dart';

class QuickAddPage extends StatefulWidget {
  const QuickAddPage({
    this.initialCategoryName,
    this.initialTypeName,
    this.initialAccountId,
    this.editing,
    this.refundOfTransactionId,
    super.key,
  });
  final String? initialCategoryName;
  final String? initialTypeName;
  final int? initialAccountId;
  final FinanceTransaction? editing;
  final int? refundOfTransactionId;

  @override State<QuickAddPage> createState() => _QuickAddPageState();
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
  String? existingReceiptPath;
  bool includeInAnalytics = true;
  bool expanded = false;
  bool saving = false;
  bool _defaultsSet = false;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    type = editing?.type ?? switch (widget.initialTypeName) {
      'income' => TransactionType.income,
      'transfer' => TransactionType.transfer,
      _ => TransactionType.expense,
    };
    if (editing != null) {
      amount.text = editing.amount.toStringAsFixed(2);
      note.text = editing.note ?? '';
      tags.addAll(editing.tags);
      accountId = editing.accountId;
      toAccountId = editing.toAccountId;
      categoryId = editing.categoryId;
      date = editing.date;
      includeInAnalytics = editing.includeInAnalytics;
      existingReceiptPath = editing.receiptPath;
      expanded = editing.note?.isNotEmpty == true || editing.tags.isNotEmpty || editing.receiptPath != null || !editing.includeInAnalytics;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_defaultsSet) { _defaultsSet = true; _setDefaults(); }
  }

  void _setDefaults() {
    if (widget.editing != null) return;
    final state = AppScope.of(context);
    final active = state.activeAccounts.where((a) => !a.isLocked).toList();
    accountId ??= widget.initialAccountId;
    accountId ??= active.firstOrNull?.id;
    if (accountId == null && state.allowUnassigned) accountId = state.unassignedAccount?.id;
    if (type == TransactionType.transfer) {
      final alternatives = active.where((a) => a.id != accountId).toList();
      toAccountId ??= alternatives.firstOrNull?.id;
    }
    final categories = state.categoriesFor(type);
    if (widget.initialCategoryName != null) {
      categoryId = categories.where((c) => c.name.toLowerCase() == widget.initialCategoryName!.toLowerCase()).firstOrNull?.id;
    }
    categoryId ??= categories.firstOrNull?.id;
  }

  @override void dispose() { amount.dispose(); note.dispose(); tag.dispose(); super.dispose(); }

  void _changeType(TransactionType value) {
    final state = AppScope.of(context);
    setState(() {
      type = value;
      categoryId = value == TransactionType.transfer ? null : state.categoriesFor(value).firstOrNull?.id;
      if (value == TransactionType.transfer) {
        final active = state.activeAccounts.where((a) => !a.isLocked && a.id != accountId).toList();
        toAccountId = active.firstOrNull?.id;
      }
    });
  }

  Future<void> _pickReceipt() async {
    final result = await picker.pickImage(source: ImageSource.camera, imageQuality: 82, maxWidth: 1800);
    if (result != null && mounted) setState(() => receipt = result);
  }

  Future<void> _save() async {
    final state = AppScope.of(context);
    final parsed = double.tryParse(amount.text.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return _error('Inserisci un importo maggiore di 0.');
    if (accountId == null) return _error('Scegli un conto o usa Non assegnato.');
    if (type == TransactionType.transfer && (toAccountId == null || toAccountId == accountId)) return _error('Scegli due conti diversi.');
    if (type != TransactionType.transfer && categoryId == null) return _error('Scegli o crea una categoria.');
    setState(() => saving = true);
    try {
      final editing = widget.editing;
      if (editing == null) {
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
          includeInAnalytics: includeInAnalytics,
          refundOfTransactionId: widget.refundOfTransactionId,
        );
      } else {
        final updated = editing.copyWith(
          type: type,
          amount: parsed,
          accountId: accountId!,
          toAccountId: toAccountId,
          categoryId: categoryId,
          date: date,
          note: note.text.trim().isEmpty ? null : note.text.trim(),
          tags: tags,
          receiptPath: receipt?.path ?? existingReceiptPath,
          includeInAnalytics: includeInAnalytics,
          updatedAt: DateTime.now(),
        );
        await state.updateTransaction(editing, updated);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) { setState(() => saving = false); _error(e.toString().replaceFirst('Bad state: ', '')); }
    }
  }

  void _error(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _chooseCategory() async {
    final state = AppScope.of(context);
    final values = state.categoriesFor(type);
    final picked = await showModalBottomSheet<int?>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        shrinkWrap: true,
        children: [
          Text('Categoria', style: Theme.of(context).textTheme.titleLarge),
          ...values.map((c) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(categoryIcon(c.iconKey), color: Color(c.colorValue)), title: Text(c.name), trailing: categoryId == c.id ? const Icon(Icons.check_rounded) : null, onTap: () => Navigator.pop(context, c.id))),
          const Divider(),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.add_rounded), title: const Text('Nuova categoria'), onTap: () => Navigator.pop(context, -1)),
        ],
      )),
    );
    if (picked == -1 && mounted) {
      final created = await showCategoryCreator(context, state, initialType: type, lockType: true);
      if (created != null) setState(() => categoryId = created.id);
    } else if (picked != null) setState(() => categoryId = picked);
  }

  Future<void> _chooseAccount({bool destination = false}) async {
    final state = AppScope.of(context);
    final current = destination ? toAccountId : accountId;
    final options = state.activeAccounts.where((a) => !a.isLocked && (!destination || a.id != accountId)).toList();
    final picked = await showModalBottomSheet<int?>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          Text(destination ? 'Conto destinazione' : 'Conto', style: Theme.of(context).textTheme.titleLarge),
          if (!destination && state.allowUnassigned && state.unassignedAccount != null)
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.help_outline_rounded), title: const Text('Non assegnato'), subtitle: const Text('Potrai scegliere il conto in seguito'), trailing: current == state.unassignedAccount!.id ? const Icon(Icons.check_rounded) : null, onTap: () => Navigator.pop(context, state.unassignedAccount!.id)),
          ...options.map((a) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(accountIcon(a.iconKey), color: Color(a.colorValue)), title: Text(a.name), subtitle: Text(a.accountType.label), trailing: current == a.id ? const Icon(Icons.check_rounded) : null, onTap: () => Navigator.pop(context, a.id))),
          if (!destination) ...[const Divider(), ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.add_rounded), title: const Text('Nuovo conto'), onTap: () => Navigator.pop(context, -1))],
        ],
      )),
    );
    if (picked == -1 && mounted) {
      final created = await showAccountEditor(context);
      if (created != null) setState(() => accountId = created.id);
    } else if (picked != null) setState(() { if (destination) toAccountId = picked; else { accountId = picked; if (toAccountId == picked) toAccountId = null; } });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final category = state.categoryById(categoryId);
    final account = state.accountById(accountId);
    final destination = state.accountById(toAccountId);
    return Scaffold(
      appBar: AppBar(title: Text(widget.editing == null ? 'Nuovo movimento' : 'Modifica movimento')),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          Text('IMPORTO', style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.2)),
          TextField(
            controller: amount,
            autofocus: widget.editing == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 48),
            decoration: const InputDecoration(hintText: '0,00', suffixText: '€'),
          ),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: SegmentedButton<TransactionType>(
            showSelectedIcon: false,
            segments: const [ButtonSegment(value: TransactionType.expense, label: Text('Spesa')), ButtonSegment(value: TransactionType.income, label: Text('Entrata')), ButtonSegment(value: TransactionType.transfer, label: Text('Trasferimento'))],
            selected: {type},
            onSelectionChanged: (value) => _changeType(value.first),
          )),
          const SizedBox(height: 24),
          if (type != TransactionType.transfer) ...[
            _PickerRow(icon: category == null ? Icons.category_outlined : categoryIcon(category.iconKey), label: 'Categoria', value: category?.name ?? 'Scegli categoria', onTap: _chooseCategory),
            const Divider(height: 1),
            _PickerRow(icon: account?.isSystem == true ? Icons.help_outline_rounded : accountIcon(account?.iconKey ?? 'wallet'), label: 'Conto', value: account?.isSystem == true ? 'Non assegnato' : account?.name ?? 'Scegli conto', onTap: _chooseAccount),
          ] else ...[
            _PickerRow(icon: accountIcon(account?.iconKey ?? 'wallet'), label: 'Da', value: account?.name ?? 'Scegli conto', onTap: _chooseAccount),
            const Divider(height: 1),
            _PickerRow(icon: accountIcon(destination?.iconKey ?? 'wallet'), label: 'A', value: destination?.name ?? 'Scegli destinazione', onTap: () => _chooseAccount(destination: true)),
          ],
          const Divider(height: 1),
          _PickerRow(icon: Icons.calendar_today_outlined, label: 'Data', value: DateFormat('dd MMM yyyy, HH:mm', 'it_IT').format(date), onTap: () async {
            final picked = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 3650)), initialDate: date);
            if (picked != null && mounted) setState(() => date = DateTime(picked.year, picked.month, picked.day, date.hour, date.minute));
          }),
          const SizedBox(height: 18),
          TextButton.icon(onPressed: () => setState(() => expanded = !expanded), icon: Icon(expanded ? Icons.expand_less_rounded : Icons.add_rounded), label: Text(expanded ? 'Nascondi dettagli' : 'Aggiungi dettagli')),
          AnimatedSize(duration: const Duration(milliseconds: 180), child: expanded ? Column(children: [
            TextField(controller: note, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nota opzionale')),
            const SizedBox(height: 12),
            Row(children: [Expanded(child: TextField(controller: tag, decoration: const InputDecoration(labelText: 'Aggiungi tag', hintText: 'Es. VacanzaRoma'), onSubmitted: (_) => _addTag())), IconButton(tooltip: 'Aggiungi tag', onPressed: _addTag, icon: const Icon(Icons.add_rounded))]),
            if (tags.isNotEmpty) Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 8, runSpacing: 8, children: tags.map((t) => InputChip(label: Text('#$t'), onDeleted: () => setState(() => tags.remove(t)))).toList())),
            const SizedBox(height: 8),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Includi nelle statistiche'), value: includeInAnalytics, onChanged: (value) => setState(() => includeInAnalytics = value)),
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.receipt_long_outlined), title: Text(receipt != null || existingReceiptPath != null ? 'Ricevuta allegata' : 'Aggiungi ricevuta'), trailing: const Icon(Icons.camera_alt_outlined), onTap: _pickReceipt),
            if (widget.refundOfTransactionId != null) const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.replay_rounded), title: Text('Questo movimento è un rimborso collegato')),
          ]) : const SizedBox.shrink()),
          const SizedBox(height: 28),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(widget.editing == null ? Icons.add_rounded : Icons.check_rounded),
            label: Text(widget.editing != null ? 'Salva modifiche' : switch (type) { TransactionType.expense => 'Aggiungi spesa', TransactionType.income => 'Aggiungi entrata', TransactionType.transfer => 'Aggiungi trasferimento' }),
          )),
        ],
      )),
    );
  }

  void _addTag() {
    final value = tag.text.trim().replaceFirst('#', '');
    if (value.isEmpty || tags.contains(value)) return;
    setState(() { tags.add(value); tag.clear(); });
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({required this.icon, required this.label, required this.value, required this.onTap});
  final IconData icon; final String label; final String value; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(contentPadding: EdgeInsets.zero, minVerticalPadding: 10, leading: Icon(icon), title: Text(label), trailing: Row(mainAxisSize: MainAxisSize.min, children: [ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: Text(value, overflow: TextOverflow.ellipsis)), const SizedBox(width: 6), const Icon(Icons.chevron_right_rounded)]), onTap: onTap);
}

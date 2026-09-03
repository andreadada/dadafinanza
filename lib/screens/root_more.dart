part of 'root_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Altro')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            _MoreTile(icon: Icons.repeat_rounded, title: 'Pagamenti regolari', subtitle: 'Abbonamenti, rate e accrediti ricorrenti', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringScreen()))),
            _MoreTile(icon: Icons.category_rounded, title: 'Categorie', subtitle: 'Personalizza colori e categorie', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen()))),
            _MoreTile(icon: Icons.notifications_active_outlined, title: 'Promemoria', subtitle: 'Scadenze e controlli da non dimenticare', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersScreen()))),
            _MoreTile(icon: Icons.settings_rounded, title: 'Impostazioni', subtitle: 'Budget, privacy e widget Android', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
            const SizedBox(height: 18),
            const Card(
              child: ListTile(
                leading: Icon(Icons.lock_rounded),
                title: Text('Dati privati e locali', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('Nessun account obbligatorio: il database resta sul dispositivo.'),
              ),
            ),
          ],
        ),
      );
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(child: Icon(icon)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onTap,
          ),
        ),
      );
}

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final state = AppScope.of(context);
    if (state.accounts.isEmpty) return;
    final name = TextEditingController();
    final amount = TextEditingController();
    TransactionType type = TransactionType.expense;
    int accountId = state.accounts.first.id;
    int? categoryId = state.categoriesFor(type).firstOrNull?.id;
    String frequency = 'Mensile';
    DateTime nextDate = DateTime.now();
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Pagamento regolare'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome')),
                const SizedBox(height: 10),
                TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Importo', suffixText: '€')),
                const SizedBox(height: 10),
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(value: TransactionType.expense, label: Text('Spesa')),
                    ButtonSegment(value: TransactionType.income, label: Text('Entrata')),
                  ],
                  selected: {type},
                  onSelectionChanged: (value) => setDialogState(() {
                    type = value.first;
                    categoryId = state.categoriesFor(type).firstOrNull?.id;
                  }),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: accountId,
                  decoration: const InputDecoration(labelText: 'Conto'),
                  items: state.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                  onChanged: (value) => accountId = value ?? accountId,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: state.categoriesFor(type).map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (value) => categoryId = value,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: frequency,
                  decoration: const InputDecoration(labelText: 'Frequenza'),
                  items: const ['Settimanale', 'Mensile', 'Trimestrale', 'Annuale'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                  onChanged: (value) => frequency = value ?? frequency,
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Prossima data'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(nextDate)),
                  trailing: const Icon(Icons.calendar_month_rounded),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)), initialDate: nextDate);
                    if (picked != null) setDialogState(() => nextDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
            FilledButton(
              onPressed: () async {
                final parsed = double.tryParse(amount.text.replaceAll(',', '.'));
                if (name.text.trim().isEmpty || parsed == null || parsed <= 0) return;
                await state.addRecurring(name: name.text.trim(), amount: parsed, type: type, accountId: accountId, categoryId: categoryId, frequency: frequency, nextDate: nextDate);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    amount.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Pagamenti regolari'), actions: [IconButton(onPressed: () => _add(context), icon: const Icon(Icons.add_rounded))]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: state.recurring.isEmpty
            ? const [_EmptyCard(icon: Icons.repeat_rounded, title: 'Nessun pagamento regolare', subtitle: 'Aggiungi abbonamenti, rate o entrate ricorrenti.')]
            : state.recurring.map((item) {
                final category = state.categoryById(item.categoryId);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: SwitchListTile(
                      value: item.enabled,
                      onChanged: (value) => state.setRecurringEnabled(item, value),
                      secondary: CircleAvatar(backgroundColor: category == null ? null : Color(category.colorValue), child: Icon(category == null ? Icons.repeat_rounded : categoryIcon(category.iconKey), color: Colors.white)),
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${item.frequency} • prossima ${DateFormat('d MMM', 'it_IT').format(item.nextDate)}'),
                    ),
                  ),
                );
              }).toList(),
      ),
    );
  }
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final state = AppScope.of(context);
    final controller = TextEditingController();
    TransactionType type = TransactionType.expense;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuova categoria'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Nome')),
              const SizedBox(height: 12),
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(value: TransactionType.expense, label: Text('Spesa')),
                  ButtonSegment(value: TransactionType.income, label: Text('Entrata')),
                ],
                selected: {type},
                onSelectionChanged: (value) => setDialogState(() => type = value.first),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
            FilledButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                await state.addCategory(name: controller.text.trim(), type: type, iconKey: 'category', colorValue: 0xFF3F9279);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Aggiungi'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Categorie'), actions: [IconButton(onPressed: () => _add(context), icon: const Icon(Icons.add_rounded))]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: TransactionType.values.where((t) => t != TransactionType.transfer).expand((type) sync* {
          yield Padding(padding: const EdgeInsets.only(top: 8, bottom: 12), child: Text(type == TransactionType.expense ? 'SPESE' : 'ENTRATE', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)));
          for (final category in state.categoriesFor(type)) {
            yield Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Color(category.colorValue), child: Icon(categoryIcon(category.iconKey), color: Colors.white)),
                  title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  trailing: category.quickOrder == null ? null : const Icon(Icons.bolt_rounded, color: AppTheme.seed),
                ),
              ),
            );
          }
        }).toList(),
      ),
    );
  }
}

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final upcoming = state.recurring.where((r) => r.enabled).take(5).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Promemoria')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _EmptyCard(
            icon: Icons.notifications_active_outlined,
            title: 'Promemoria intelligenti',
            subtitle: 'Questa sezione usa i pagamenti regolari come scadenze. Le notifiche locali verranno collegate nella fase successiva.',
          ),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionTitle('Prossime scadenze'),
            ...upcoming.map((r) => Card(child: ListTile(leading: const Icon(Icons.event_rounded), title: Text(r.name), subtitle: Text(DateFormat('EEEE d MMMM', 'it_IT').format(r.nextDate)), trailing: Text(money(r.amount))))),
          ],
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TextEditingController? budget;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    budget ??= TextEditingController(text: AppScope.of(context).monthlyBudget.toStringAsFixed(0));
  }

  @override
  void dispose() {
    budget?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            value: state.hideBalance,
            onChanged: state.setHideBalance,
            secondary: const Icon(Icons.visibility_off_rounded),
            title: const Text('Nascondi saldi'),
            subtitle: const Text('Oscura gli importi nelle schermate principali.'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.savings_rounded),
            title: const Text('Budget mensile'),
            subtitle: TextField(
              controller: budget!,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixText: '€'),
              onSubmitted: (value) {
                final parsed = double.tryParse(value.replaceAll(',', '.'));
                if (parsed != null && parsed > 0) state.setMonthlyBudget(parsed);
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.widgets_rounded),
            title: const Text('Widget Android'),
            subtitle: const Text('Mostra saldo e scorciatoie per registrare velocemente le spese dalla Home.'),
            trailing: IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: state.syncWidget),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.shield_rounded),
            title: Text('Privacy'),
            subtitle: Text('Database SQLite locale. Nessun cloud o login richiesto nella versione privata.'),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Icon(icon, size: 38, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

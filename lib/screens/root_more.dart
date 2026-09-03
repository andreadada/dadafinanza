part of 'root_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Altro')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            _MoreTile(
              icon: Icons.category_outlined,
              title: 'Categorie',
              subtitle: 'Crea, personalizza o elimina categorie',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategoriesScreen()),
              ),
            ),
            const Divider(height: 1),
            _MoreTile(
              icon: Icons.repeat_rounded,
              title: 'Pagamenti regolari',
              subtitle: 'Abbonamenti, rate e accrediti ricorrenti',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecurringScreen()),
              ),
            ),
            const Divider(height: 1),
            _MoreTile(
              icon: Icons.notifications_none_rounded,
              title: 'Promemoria',
              subtitle: 'Scadenze da tenere sotto controllo',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RemindersScreen()),
              ),
            ),
            const Divider(height: 1),
            _MoreTile(
              icon: Icons.settings_outlined,
              title: 'Impostazioni',
              subtitle: 'Budget, privacy e widget Android',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            const SizedBox(height: 34),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.lock_outline_rounded),
              title: Text(
                'Privato sul dispositivo',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('Nessun account obbligatorio. Il database resta locale.'),
            ),
          ],
        ),
      );
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        minVerticalPadding: 12,
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
        onTap: onTap,
      );
}

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final state = AppScope.of(context);
    if (state.accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crea prima un conto.')),
      );
      return;
    }

    final name = TextEditingController();
    final amount = TextEditingController();
    var type = TransactionType.expense;
    var accountId = state.accounts.first.id;
    int? categoryId = state.categoriesFor(type).firstOrNull?.id;
    var frequency = 'Mensile';
    var nextDate = DateTime.now();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nuovo pagamento regolare',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Importo',
                    suffixText: '€',
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<TransactionType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: Text('Spesa'),
                    ),
                    ButtonSegment(
                      value: TransactionType.income,
                      label: Text('Entrata'),
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged: (value) => setSheetState(() {
                    type = value.first;
                    categoryId = state.categoriesFor(type).firstOrNull?.id;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: accountId,
                  decoration: const InputDecoration(labelText: 'Conto'),
                  items: state.accounts
                      .map(
                        (account) => DropdownMenuItem(
                          value: account.id,
                          child: Text(account.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => accountId = value ?? accountId,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('category-$type-$categoryId'),
                        initialValue: categoryId,
                        decoration: const InputDecoration(labelText: 'Categoria'),
                        items: state
                            .categoriesFor(type)
                            .map(
                              (category) => DropdownMenuItem(
                                value: category.id,
                                child: Text(category.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => categoryId = value,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Nuova categoria',
                      onPressed: () async {
                        final created = await showCategoryCreator(
                          context,
                          state,
                          initialType: type,
                          lockType: true,
                        );
                        if (created != null) {
                          setSheetState(() => categoryId = created.id);
                        }
                      },
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: frequency,
                  decoration: const InputDecoration(labelText: 'Frequenza'),
                  items: const ['Settimanale', 'Mensile', 'Trimestrale', 'Annuale']
                      .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) => frequency = value ?? frequency,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Prossima data'),
                  trailing: Text(DateFormat('dd/MM/yyyy').format(nextDate)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      initialDate: nextDate,
                    );
                    if (picked != null) {
                      setSheetState(() => nextDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final parsed =
                          double.tryParse(amount.text.replaceAll(',', '.'));
                      if (name.text.trim().isEmpty ||
                          parsed == null ||
                          parsed <= 0) {
                        return;
                      }
                      await state.addRecurring(
                        name: name.text.trim(),
                        amount: parsed,
                        type: type,
                        accountId: accountId,
                        categoryId: categoryId,
                        frequency: frequency,
                        nextDate: nextDate,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Salva'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    name.dispose();
    amount.dispose();
  }

  Future<void> _delete(BuildContext context, RecurringPayment item) async {
    final state = AppScope.of(context);
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Eliminare “${item.name}”?',
      message: 'Il pagamento regolare verrà eliminato definitivamente.',
    );
    if (confirmed) await state.deleteRecurring(item);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagamenti regolari'),
        actions: [
          IconButton(
            tooltip: 'Nuovo pagamento regolare',
            onPressed: () => _add(context),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: state.recurring.isEmpty
            ? [
                _EmptyCard(
                  icon: Icons.repeat_rounded,
                  title: 'Nessun pagamento regolare',
                  subtitle: 'Aggiungi abbonamenti, rate o entrate ricorrenti.',
                  action: FilledButton.icon(
                    onPressed: () => _add(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Aggiungi'),
                  ),
                ),
              ]
            : List.generate(state.recurring.length, (index) {
                final item = state.recurring[index];
                final category = state.categoryById(item.categoryId);
                return Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        category == null
                            ? Icons.repeat_rounded
                            : categoryIcon(category.iconKey),
                        color: category == null
                            ? AppTheme.muted
                            : Color(category.colorValue),
                      ),
                      title: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${item.frequency} · ${DateFormat('d MMM', 'it_IT').format(item.nextDate)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: item.enabled,
                            onChanged: (value) =>
                                state.setRecurringEnabled(item, value),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Azioni per ${item.name}',
                            onSelected: (value) {
                              if (value == 'delete') _delete(context, item);
                            },
                            itemBuilder: (menuContext) => [
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Elimina',
                                  style: TextStyle(
                                    color: Theme.of(menuContext).colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (index != state.recurring.length - 1)
                      const Divider(height: 1),
                  ],
                );
              }),
      ),
    );
  }
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  Future<void> _add(BuildContext context) async {
    await showCategoryCreator(context, AppScope.of(context));
  }

  Future<void> _delete(BuildContext context, Category category) async {
    final state = AppScope.of(context);
    final linked = state.transactionCountForCategory(category.id);
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Eliminare “${category.name}”?',
      message: linked == 0
          ? 'La categoria verrà eliminata definitivamente.'
          : 'La categoria verrà eliminata, ma i $linked movimenti già registrati resteranno nello storico come “Senza categoria”.',
    );
    if (confirmed) await state.deleteCategory(category);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorie'),
        actions: [
          IconButton(
            tooltip: 'Nuova categoria',
            onPressed: () => _add(context),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          if (state.categories.isEmpty)
            _EmptyCard(
              icon: Icons.category_outlined,
              title: 'Nessuna categoria',
              subtitle: 'Creane una scegliendo nome, colore e icona.',
              action: FilledButton.icon(
                onPressed: () => _add(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuova categoria'),
              ),
            )
          else
            ...TransactionType.values
                .where((type) => type != TransactionType.transfer)
                .expand((type) sync* {
              final items = state.categoriesFor(type);
              if (items.isEmpty) return;
              yield Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 6),
                child: Text(
                  type == TransactionType.expense ? 'SPESE' : 'ENTRATE',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    fontSize: 11,
                  ),
                ),
              );
              for (var index = 0; index < items.length; index++) {
                final category = items[index];
                yield ListTile(
                  minVerticalPadding: 11,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    categoryIcon(category.iconKey),
                    color: Color(category.colorValue),
                  ),
                  title: Text(
                    category.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${state.transactionCountForCategory(category.id)} movimenti',
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Azioni per ${category.name}',
                    onSelected: (value) {
                      if (value == 'delete') _delete(context, category);
                    },
                    itemBuilder: (menuContext) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Elimina categoria',
                          style: TextStyle(
                            color: Theme.of(menuContext).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                if (index != items.length - 1) {
                  yield const Divider(height: 1);
                }
              }
              yield const SizedBox(height: 18);
            }),
        ],
      ),
    );
  }
}

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final upcoming = state.recurring.where((item) => item.enabled).take(5).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Promemoria')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          const _EmptyCard(
            icon: Icons.notifications_none_rounded,
            title: 'Promemoria',
            subtitle:
                'Per ora qui vengono mostrate le prossime scadenze dei pagamenti regolari. Le notifiche locali saranno collegate successivamente.',
          ),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 28),
            const SectionTitle('Prossime scadenze'),
            ...List.generate(upcoming.length, (index) {
              final item = upcoming[index];
              return Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(item.name),
                    subtitle: Text(
                      DateFormat('EEEE d MMMM', 'it_IT').format(item.nextDate),
                    ),
                    trailing: Text(money(item.amount)),
                  ),
                  if (index != upcoming.length - 1) const Divider(height: 1),
                ],
              );
            }),
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
    budget ??= TextEditingController(
      text: AppScope.of(context).monthlyBudget.toStringAsFixed(0),
    );
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: state.hideBalance,
            onChanged: state.setHideBalance,
            secondary: const Icon(Icons.visibility_off_outlined),
            title: const Text('Nascondi saldi'),
            subtitle: const Text('Oscura gli importi nelle schermate principali.'),
          ),
          const Divider(height: 1),
          const SizedBox(height: 18),
          const Text(
            'Budget mensile',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          TextField(
            controller: budget!,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: '0',
              suffixText: '€',
            ),
            onSubmitted: (value) {
              final parsed = double.tryParse(value.replaceAll(',', '.'));
              if (parsed != null && parsed >= 0) state.setMonthlyBudget(parsed);
            },
          ),
          const SizedBox(height: 6),
          const Text(
            '0 € disattiva il budget.',
            style: TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.widgets_outlined),
            title: const Text('Widget Android'),
            subtitle: const Text(
              'Saldo e scorciatoie sulle prime quattro categorie di spesa.',
            ),
            trailing: IconButton(
              tooltip: 'Aggiorna widget',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: state.syncWidget,
            ),
          ),
          const Divider(height: 1),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.shield_outlined),
            title: Text('Privacy'),
            subtitle: Text('Database SQLite locale. Nessun cloud o login richiesto.'),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: AppTheme.muted),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 5),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      );
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

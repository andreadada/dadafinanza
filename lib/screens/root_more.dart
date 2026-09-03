part of 'root_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Altro')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            _MoreTile(
              icon: Icons.category_outlined,
              title: 'Categorie',
              subtitle: 'Nome, colore e tante icone diverse',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategoriesScreen()),
              ),
            ),
            _MoreTile(
              icon: Icons.repeat_rounded,
              title: 'Pagamenti regolari',
              subtitle: 'Abbonamenti, rate e accrediti ricorrenti',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecurringScreen()),
              ),
            ),
            _MoreTile(
              icon: Icons.notifications_none_rounded,
              title: 'Promemoria',
              subtitle: 'Scadenze e controlli da non dimenticare',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RemindersScreen()),
              ),
            ),
            _MoreTile(
              icon: Icons.settings_outlined,
              title: 'Impostazioni',
              subtitle: 'Budget, privacy e widget Android',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            const SizedBox(height: 18),
            const Card(
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                leading: Icon(Icons.lock_outline_rounded),
                title: Text(
                  'Privato sul dispositivo',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'Nessun account obbligatorio. Il database resta locale.',
                ),
              ),
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
            onTap: onTap,
          ),
        ),
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
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Importo',
                    suffixText: '€',
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<TransactionType>(
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
                  onSelectionChanged: (value) => setDialogState(() {
                    type = value.first;
                    categoryId = state.categoriesFor(type).firstOrNull?.id;
                  }),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: accountId,
                  decoration: const InputDecoration(labelText: 'Conto'),
                  items: state.accounts
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => accountId = value ?? accountId,
                ),
                if (state.categoriesFor(type).isNotEmpty) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: categoryId,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: state
                        .categoriesFor(type)
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => categoryId = value,
                  ),
                ],
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: frequency,
                  decoration: const InputDecoration(labelText: 'Frequenza'),
                  items: const [
                    'Settimanale',
                    'Mensile',
                    'Trimestrale',
                    'Annuale',
                  ]
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                      .toList(),
                  onChanged: (value) => frequency = value ?? frequency,
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Prossima data'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(nextDate)),
                  trailing: const Icon(Icons.calendar_month_rounded),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      initialDate: nextDate,
                    );
                    if (picked != null) {
                      setDialogState(() => nextDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () async {
                final parsed = double.tryParse(amount.text.replaceAll(',', '.'));
                if (name.text.trim().isEmpty || parsed == null || parsed <= 0) {
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
      appBar: AppBar(
        title: const Text('Pagamenti regolari'),
        actions: [
          IconButton(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: state.recurring.isEmpty
            ? const [
                _EmptyCard(
                  icon: Icons.repeat_rounded,
                  title: 'Nessun pagamento regolare',
                  subtitle: 'Aggiungi abbonamenti, rate o entrate ricorrenti.',
                ),
              ]
            : state.recurring.map((item) {
                final category = state.categoryById(item.categoryId);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: SwitchListTile(
                      value: item.enabled,
                      onChanged: (value) => state.setRecurringEnabled(item, value),
                      secondary: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: category == null
                              ? Colors.white.withValues(alpha: .08)
                              : Color(category.colorValue).withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          category == null
                              ? Icons.repeat_rounded
                              : categoryIcon(category.iconKey),
                          color: category == null
                              ? Colors.white
                              : Color(category.colorValue),
                        ),
                      ),
                      title: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${item.frequency} • prossima ${DateFormat('d MMM', 'it_IT').format(item.nextDate)}',
                      ),
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
    String iconKey = categoryIconOptions.first.key;
    Color color = categoryPalette.first;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .78,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nuova categoria',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(categoryIcon(iconKey), color: color, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Nome categoria',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<TransactionType>(
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
                      onSelectionChanged: (value) =>
                          setSheetState(() => type = value.first),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Colore',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: categoryPalette.map((item) {
                      final selected = item == color;
                      return InkWell(
                        onTap: () => setSheetState(() => color = item),
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: item,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: selected
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 17,
                                  color: item.computeLuminance() > .6
                                      ? Colors.black
                                      : Colors.white,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Icona',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        '${categoryIconOptions.length} disponibili',
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 9,
                        crossAxisSpacing: 9,
                      ),
                      itemCount: categoryIconOptions.length,
                      itemBuilder: (context, index) {
                        final option = categoryIconOptions[index];
                        final selected = option.key == iconKey;
                        return Tooltip(
                          message: option.label,
                          child: InkWell(
                            onTap: () =>
                                setSheetState(() => iconKey = option.key),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white.withValues(alpha: .12)
                                    : AppTheme.surfaceRaised,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected ? Colors.white : AppTheme.border,
                                ),
                              ),
                              child: Icon(
                                option.icon,
                                color: selected ? Colors.white : AppTheme.muted,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        if (controller.text.trim().isEmpty) return;
                        await state.addCategory(
                          name: controller.text.trim(),
                          type: type,
                          iconKey: iconKey,
                          colorValue: color.toARGB32(),
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Crea categoria'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorie'),
        actions: [
          IconButton(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          if (state.categories.isEmpty)
            _EmptyCard(
              icon: Icons.category_outlined,
              title: 'Nessuna categoria',
              subtitle:
                  'Creane una e scegli tra decine di icone per riconoscerla subito.',
              action: FilledButton.icon(
                onPressed: () => _add(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuova categoria'),
              ),
            )
          else
            ...TransactionType.values
                .where((t) => t != TransactionType.transfer)
                .expand((type) sync* {
              final items = state.categoriesFor(type);
              if (items.isEmpty) return;
              yield Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 12),
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
              for (final category in items) {
                yield Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Color(category.colorValue)
                              .withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          categoryIcon(category.iconKey),
                          color: Color(category.colorValue),
                        ),
                      ),
                      title: Text(
                        category.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                );
              }
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
    final upcoming = state.recurring.where((r) => r.enabled).take(5).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Promemoria')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _EmptyCard(
            icon: Icons.notifications_none_rounded,
            title: 'Promemoria intelligenti',
            subtitle:
                'Questa sezione usa i pagamenti regolari come scadenze. Le notifiche locali verranno collegate nella fase successiva.',
          ),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionTitle('Prossime scadenze'),
            ...upcoming.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_outlined),
                    title: Text(r.name),
                    subtitle: Text(
                      DateFormat('EEEE d MMMM', 'it_IT').format(r.nextDate),
                    ),
                    trailing: Text(money(r.amount)),
                  ),
                ),
              ),
            ),
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
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              value: state.hideBalance,
              onChanged: state.setHideBalance,
              secondary: const Icon(Icons.visibility_off_outlined),
              title: const Text('Nascondi saldi'),
              subtitle: const Text('Oscura gli importi nelle schermate principali.'),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Budget mensile',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    controller: budget!,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(suffixText: '€'),
                    onSubmitted: (value) {
                      final parsed = double.tryParse(value.replaceAll(',', '.'));
                      if (parsed != null && parsed >= 0) {
                        state.setMonthlyBudget(parsed);
                      }
                    },
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    '0 € disattiva il budget.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.widgets_outlined),
              title: const Text('Widget Android'),
              subtitle: const Text(
                'Saldo e scorciatoie sulle prime quattro categorie di spesa.',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: state.syncWidget,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Card(
            child: ListTile(
              leading: Icon(Icons.shield_outlined),
              title: Text('Privacy'),
              subtitle: Text(
                'Database SQLite locale. Nessun cloud o login richiesto.',
              ),
            ),
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
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, size: 27),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (action != null) ...[
                const SizedBox(height: 16),
                action!,
              ],
            ],
          ),
        ),
      );
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

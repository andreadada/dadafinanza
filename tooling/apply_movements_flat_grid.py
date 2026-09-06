from pathlib import Path

path = Path('lib/screens/account_context_transactions_screen.dart')
text = path.read_text()

old_selector = """          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<_MovementView>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _MovementView.list,
                    icon: Icon(Icons.view_list_rounded),
                    label: Text('Lista'),
                  ),
                  ButtonSegment(
                    value: _MovementView.grouped,
                    icon: Icon(Icons.category_outlined),
                    label: Text('Raggruppata'),
                  ),
                ],
                selected: {view},
                onSelectionChanged: (value) =>
                    setState(() => view = value.first),
              ),
            ),
          ),
"""
new_selector = """          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
            child: Row(
              children: [
                _ViewTab(
                  label: 'Lista',
                  selected: view == _MovementView.list,
                  onTap: () => setState(() => view = _MovementView.list),
                ),
                const SizedBox(width: 28),
                _ViewTab(
                  label: 'Raggruppata',
                  selected: view == _MovementView.grouped,
                  onTap: () => setState(() => view = _MovementView.grouped),
                ),
              ],
            ),
          ),
"""
if old_selector not in text:
    raise SystemExit('selector block not found')
text = text.replace(old_selector, new_selector, 1)

old_grouped = """                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final category = state.categoryById(group.categoryId);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        minVerticalPadding: 10,
                        leading: Icon(
                          group.type == TransactionType.transfer
                              ? Icons.swap_horiz_rounded
                              : category == null
                              ? Icons.receipt_long_outlined
                              : categoryIcon(category.iconKey),
                          color: category == null
                              ? transactionColor(context, group.type)
                              : Color(category.colorValue),
                        ),
                        title: Text(
                          group.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${group.count} ${group.count == 1 ? 'movimento' : 'movimenti'} · '
                          '${group.percentage.toStringAsFixed(0)}% ${_typeShareLabel(group.type)}',
                        ),
                        trailing: Text(
                          _groupAmount(state, group),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: transactionColor(context, group.type),
                          ),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _GroupedMovementsPage(
                              title: group.title,
                              ids: group.transactionIds,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
"""
new_grouped = """                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 18,
                          childAspectRatio: 1.34,
                        ),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final category = state.categoryById(group.categoryId);
                      final color = category == null
                          ? transactionColor(context, group.type)
                          : Color(category.colorValue);
                      final icon = group.type == TransactionType.transfer
                          ? Icons.swap_horiz_rounded
                          : category == null
                          ? Icons.receipt_long_outlined
                          : categoryIcon(category.iconKey);
                      return _GroupedCategoryTile(
                        title: group.title,
                        icon: icon,
                        color: color,
                        amount: _groupAmount(state, group),
                        percentage:
                            '${group.percentage.toStringAsFixed(0)}% ${_typeShareLabel(group.type)}',
                        count:
                            '${group.count} ${group.count == 1 ? 'movimento' : 'movimenti'}',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _GroupedMovementsPage(
                              title: group.title,
                              ids: group.transactionIds,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
"""
if old_grouped not in text:
    raise SystemExit('grouped list block not found')
text = text.replace(old_grouped, new_grouped, 1)

insert_before = """class _GroupedMovementsPage extends StatelessWidget {
"""
widgets = """class _ViewTab extends StatelessWidget {
  const _ViewTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                width: selected ? 32 : 0,
                height: 2,
                decoration: BoxDecoration(
                  color: selected ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupedCategoryTile extends StatelessWidget {
  const _GroupedCategoryTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.amount,
    required this.percentage,
    required this.count,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String amount;
  final String percentage;
  final String count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$title, $amount, $percentage, $count',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              amount,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              percentage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              count,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

"""
if insert_before not in text:
    raise SystemExit('grouped page marker not found')
text = text.replace(insert_before, widgets + insert_before, 1)

path.write_text(text)

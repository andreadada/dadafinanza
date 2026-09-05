import 'package:flutter/material.dart';

import '../main.dart';
import '../models/models.dart';
import 'ui_helpers.dart';

/// Shared account context used by Home, Movimenti and Analisi.
/// `selectedAccountId == null` means the aggregate "Totale" scope.
class AccountScopeSelector extends StatelessWidget {
  const AccountScopeSelector({
    required this.selectedAccountId,
    required this.onChanged,
    super.key,
  });

  final int? selectedAccountId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final selected = state.accountById(selectedAccountId);
    final label = selected?.name ?? 'Totale';

    return Semantics(
      button: true,
      label: 'Filtro conto: $label',
      hint: 'Tocca per cambiare conto',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final choice = await showModalBottomSheet<int>(
            context: context,
            useSafeArea: true,
            showDragHandle: true,
            builder: (sheetContext) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visualizza conto',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minVerticalPadding: 10,
                    leading: const Icon(Icons.all_inclusive_rounded),
                    title: const Text('Totale'),
                    subtitle: const Text('Tutti i conti insieme'),
                    trailing: selectedAccountId == null
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () => Navigator.pop(sheetContext, 0),
                  ),
                  if (state.activeAccounts.isNotEmpty) const Divider(height: 1),
                  ...state.activeAccounts.map(
                    (account) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      minVerticalPadding: 10,
                      leading: Icon(
                        accountIcon(account.iconKey),
                        color: Color(account.colorValue),
                      ),
                      title: Text(account.name),
                      subtitle: Text(account.accountType.label),
                      trailing: selectedAccountId == account.id
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => Navigator.pop(sheetContext, account.id),
                    ),
                  ),
                ],
              ),
            ),
          );
          if (choice == null) return;
          onChanged(choice == 0 ? null : choice);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

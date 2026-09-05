import 'package:flutter/material.dart';

import '../app_state.dart';
import '../main.dart';
import 'ui_helpers.dart';

class AccountContextSelector extends StatelessWidget {
  const AccountContextSelector({
    required this.accountId,
    required this.onChanged,
    super.key,
  });

  final int? accountId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final selected = state.accountById(accountId);
    final label = selected == null || selected.isArchived || selected.isSystem
        ? 'Totale'
        : selected.name;

    return PopupMenuButton<int>(
      tooltip: 'Seleziona conto',
      initialValue: selected == null ? 0 : selected.id,
      onSelected: (value) => onChanged(value == 0 ? null : value),
      itemBuilder: (context) => [
        const PopupMenuItem<int>(
          value: 0,
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined),
              SizedBox(width: 12),
              Text('Totale'),
            ],
          ),
        ),
        ...state.activeAccounts.map(
          (account) => PopupMenuItem<int>(
            value: account.id,
            child: Row(
              children: [
                Icon(
                  accountIcon(account.iconKey),
                  color: Color(account.colorValue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

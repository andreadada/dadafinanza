import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/models.dart';
import '../services/account_context_service.dart';
import '../widgets/account_context_selector.dart';
import '../widgets/finance_quick_action.dart';
import '../widgets/ui_helpers.dart';
import 'account_management_screen.dart';
import 'account_screens.dart' show showAccountEditor;
import 'personal_settings_screen.dart';
import 'planning_screens.dart';
import 'quick_add_page.dart';
import 'root_screen.dart' as advanced;
import 'transaction_screens.dart';

class AccountContextHomeScreen extends StatelessWidget {
  const AccountContextHomeScreen({
    required this.accountId,
    required this.onAccountChanged,
    super.key,
  });

  final int? accountId;
  final ValueChanged<int?> onAccountChanged;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final selectedAccount = state.accountById(accountId);
    final effectiveAccountId =
        selectedAccount == null ||
            selectedAccount.isArchived ||
            selectedAccount.isSystem
        ? null
        : selectedAccount.id;
    final income = AccountContextService.monthTotal(
      state,
      effectiveAccountId,
      TransactionType.income,
    );
    final expense = AccountContextService.monthTotal(
      state,
      effectiveAccountId,
      TransactionType.expense,
    );
    final balance = AccountContextService.balanceFor(state, effectiveAccountId);
    final recent = AccountContextService.transactionsFor(
      state,
      effectiveAccountId,
    )..sort((a, b) => b.date.compareTo(a.date));
    final upcoming = AccountContextService.recurringFor(
      state,
      effectiveAccountId,
    );
    final visibleAccounts = effectiveAccountId == null
        ? state.activeAccounts.take(4).toList()
        : state.activeAccounts
              .where((item) => item.id == effectiveAccountId)
              .toList();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AccountContextSelector(
                accountId: effectiveAccountId,
                onChanged: onAccountChanged,
              ),
              Text(
                DateFormat('MMMM yyyy', 'it_IT').format(DateTime.now()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: state.hideBalance ? 'Mostra saldi' : 'Nascondi saldi',
              onPressed: () => state.setHideBalance(!state.hideBalance),
              icon: Icon(
                state.hideBalance
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
            IconButton(
              tooltip: 'Dashboard avanzata',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const advanced.HomeScreen()),
              ),
              icon: const Icon(Icons.dashboard_customize_outlined),
            ),
            IconButton(
              tooltip: 'Impostazioni',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PersonalSettingsScreen(),
                ),
              ),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
          sliver: SliverList.list(
            children: [
              if (state.userAccounts.isEmpty) ...[
                _SetupBlock(
                  onAccount: () => showAccountEditor(context),
                  onMovement: () => _openQuick(
                    context,
                    TransactionType.expense,
                    effectiveAccountId,
                  ),
                ),
                const SizedBox(height: 32),
              ],
              Text(
                'PATRIMONIO',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              Text(
                state.hideBalance ? '••••••' : moneyFor(state, balance),
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'Entrate',
                      value: state.hideBalance
                          ? '••••'
                          : moneyFor(state, income),
                      color: context.financeColors.positive,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Metric(
                      label: 'Spese',
                      value: state.hideBalance
                          ? '••••'
                          : moneyFor(state, expense),
                      color: context.financeColors.negative,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Metric(
                      label: 'Disponibile',
                      value: state.hideBalance
                          ? '••••'
                          : moneyFor(
                              state,
                              effectiveAccountId == null
                                  ? state.safeToSpend
                                  : balance,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FinanceQuickAction(
                      icon: Icons.arrow_upward_rounded,
                      label: 'Spesa',
                      color: context.financeColors.negative,
                      onTap: () => _openQuick(
                        context,
                        TransactionType.expense,
                        effectiveAccountId,
                      ),
                    ),
                  ),
                  Expanded(
                    child: FinanceQuickAction(
                      icon: Icons.arrow_downward_rounded,
                      label: 'Entrata',
                      color: context.financeColors.positive,
                      onTap: () => _openQuick(
                        context,
                        TransactionType.income,
                        effectiveAccountId,
                      ),
                    ),
                  ),
                  Expanded(
                    child: FinanceQuickAction(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Trasferisci',
                      onTap: () => _openQuick(
                        context,
                        TransactionType.transfer,
                        effectiveAccountId,
                      ),
                    ),
                  ),
                ],
              ),
              if (effectiveAccountId == null && state.unassignedCount > 0) ...[
                const SizedBox(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.rule_folder_outlined,
                    color: context.financeColors.warning,
                  ),
                  title: Text(
                    '${state.unassignedCount} movimenti da assegnare',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Completa il conto per mantenere saldi e analisi ordinati.',
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SectionTitle(
                effectiveAccountId == null ? 'Conti' : 'Conto selezionato',
                trailing: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountManagementScreen(),
                    ),
                  ),
                  child: const Text('Tutti'),
                ),
              ),
              if (visibleAccounts.isEmpty)
                EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Nessun conto',
                  subtitle: 'Aggiungi il conto che usi davvero.',
                  action: TextButton.icon(
                    onPressed: () => showAccountEditor(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Crea conto'),
                  ),
                )
              else
                ...visibleAccounts.map(
                  (account) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    minVerticalPadding: 10,
                    leading: Icon(
                      accountIcon(account.iconKey),
                      color: Color(account.colorValue),
                    ),
                    title: Text(account.name),
                    subtitle: Text(account.accountType.label),
                    trailing: Text(
                      state.hideBalance || account.hideBalance
                          ? '••••'
                          : moneyFor(state, account.balance),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SafeAccountDetailScreen(accountId: account.id),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              const SectionTitle('Ultimi movimenti'),
              if (recent.isEmpty)
                const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Nessun movimento',
                  subtitle: 'Registra una spesa o un’entrata per iniziare.',
                )
              else
                ...recent
                    .take(5)
                    .map((item) => TransactionListTile(item: item)),
              const SizedBox(height: 32),
              SectionTitle(
                'Prossime scadenze',
                trailing: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RecurringScreen()),
                  ),
                  child: const Text('Apri'),
                ),
              ),
              if (upcoming.isEmpty)
                const Text('Nessuna scadenza prevista')
              else
                ...upcoming
                    .take(3)
                    .map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.repeat_rounded,
                          color: transactionColor(context, item.type),
                        ),
                        title: Text(item.name),
                        subtitle: Text(
                          DateFormat(
                            'EEE d MMM',
                            'it_IT',
                          ).format(item.nextDate),
                        ),
                        trailing: Text(
                          state.hideBalance
                              ? '••••'
                              : moneyFor(state, item.amount),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openQuick(
    BuildContext context,
    TransactionType type,
    int? selectedAccountId,
  ) async {
    final state = AppScope.of(context);
    int? account = selectedAccountId;
    if (account == null) {
      final key = switch (type) {
        TransactionType.expense => 'preferred_expense_account',
        TransactionType.income => 'preferred_income_account',
        TransactionType.transfer => 'preferred_transfer_source',
      };
      account = int.tryParse(await state.database.getSetting(key) ?? '');
    }
    var destination = type == TransactionType.transfer
        ? int.tryParse(
            await state.database.getSetting('preferred_transfer_destination') ??
                '',
          )
        : null;
    if (destination == account) destination = null;
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuickAddPage(
          initialTypeName: type.name,
          initialAccountId: account,
          initialToAccountId: destination,
        ),
      ),
    );
  }
}

class _SetupBlock extends StatelessWidget {
  const _SetupBlock({required this.onAccount, required this.onMovement});
  final VoidCallback onAccount;
  final VoidCallback onMovement;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Configura DadaFinanza',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Text('Parti dal primo conto oppure registra subito un movimento.'),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        children: [
          FilledButton.icon(
            onPressed: onAccount,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crea primo conto'),
          ),
          TextButton.icon(
            onPressed: onMovement,
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Registra movimento'),
          ),
        ],
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 3),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: color),
        ),
      ),
    ],
  );
}

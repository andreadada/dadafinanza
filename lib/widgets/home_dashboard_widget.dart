import 'package:flutter/material.dart';

import '../main.dart';
import '../models/models.dart';
import '../screens/account_management_screen.dart';
import '../screens/account_screens.dart' show showAccountEditor;
import '../screens/canonical_shell.dart' show CanonicalDashboardWidget;
import 'ui_helpers.dart';

/// Renders a dashboard configuration on the canonical Home.
///
/// The older canonical dashboard intentionally returned an empty widget for a
/// handful of metrics because those metrics used to be hard-coded in Home.
/// This adapter makes those metrics configurable too, so enable/disable,
/// ordering and size from "Personalizza Home" have an actual effect.
class HomeDashboardWidget extends StatelessWidget {
  const HomeDashboardWidget({required this.config, super.key});

  final DashboardWidgetConfig config;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final type = config.type;

    switch (type) {
      case DashboardWidgetType.totalBalance:
        return _MetricBlock(
          config: config,
          title: 'PATRIMONIO',
          value: state.hideBalance
              ? '••••••'
              : moneyFor(state, state.totalBalance),
          detail: 'Patrimonio incluso nel totale',
          icon: Icons.account_balance_wallet_outlined,
        );
      case DashboardWidgetType.monthlyIncome:
        return _MetricBlock(
          config: config,
          title: type.label,
          value: state.hideBalance
              ? '••••'
              : moneyFor(state, state.monthTotal(TransactionType.income)),
          icon: Icons.arrow_downward_rounded,
          valueColor: context.financeColors.positive,
        );
      case DashboardWidgetType.monthlyExpense:
        return _MetricBlock(
          config: config,
          title: type.label,
          value: state.hideBalance
              ? '••••'
              : moneyFor(state, state.monthTotal(TransactionType.expense)),
          icon: Icons.arrow_upward_rounded,
          valueColor: context.financeColors.negative,
        );
      case DashboardWidgetType.safeToSpend:
        return _MetricBlock(
          config: config,
          title: type.label,
          value: state.hideBalance
              ? '••••'
              : moneyFor(state, state.safeToSpend),
          detail: 'Stima fino a fine mese',
          icon: Icons.safety_check_outlined,
        );
      case DashboardWidgetType.accounts:
        return _AccountsBlock(config: config);
      default:
        return _SizedCanonicalWidget(config: config);
    }
  }
}

class _SizedCanonicalWidget extends StatelessWidget {
  const _SizedCanonicalWidget({required this.config});

  final DashboardWidgetConfig config;

  @override
  Widget build(BuildContext context) {
    final padding = switch (config.size) {
      DashboardWidgetSize.small => 0.0,
      DashboardWidgetSize.medium => 4.0,
      DashboardWidgetSize.large => 10.0,
    };
    return Padding(
      padding: EdgeInsets.symmetric(vertical: padding),
      child: CanonicalDashboardWidget(config: config),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.config,
    required this.title,
    required this.value,
    this.detail,
    this.icon,
    this.valueColor,
  });

  final DashboardWidgetConfig config;
  final String title;
  final String value;
  final String? detail;
  final IconData? icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = switch (config.size) {
      DashboardWidgetSize.small => Theme.of(context).textTheme.titleLarge,
      DashboardWidgetSize.medium => Theme.of(context).textTheme.headlineSmall,
      DashboardWidgetSize.large => Theme.of(context).textTheme.displaySmall,
    };
    final showDetail = config.size != DashboardWidgetSize.small;
    final showIcon = icon != null && config.size == DashboardWidgetSize.large;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelMedium),
        if (showIcon) ...[const SizedBox(height: 8), Icon(icon, size: 24)],
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: style?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (showDetail && detail != null) ...[
          const SizedBox(height: 4),
          Text(detail!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _AccountsBlock extends StatelessWidget {
  const _AccountsBlock({required this.config});

  final DashboardWidgetConfig config;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final limit = switch (config.size) {
      DashboardWidgetSize.small => 2,
      DashboardWidgetSize.medium => 4,
      DashboardWidgetSize.large => 6,
    };
    final accounts = state.activeAccounts.take(limit).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Conti',
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
        if (accounts.isEmpty)
          EmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Nessun conto',
            subtitle:
                'Aggiungi il conto che usi davvero oppure continua con movimenti Non assegnati.',
            action: TextButton.icon(
              onPressed: () => showAccountEditor(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crea conto'),
            ),
          )
        else
          ...accounts.map(
            (account) => ListTile(
              contentPadding: EdgeInsets.zero,
              minVerticalPadding: 10,
              leading: Icon(
                accountIcon(account.iconKey),
                color: Color(account.colorValue),
              ),
              title: Text(
                account.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: config.size == DashboardWidgetSize.small
                  ? null
                  : Text(account.accountType.label),
              trailing: Text(
                state.hideBalance || account.hideBalance
                    ? '••••'
                    : moneyFor(state, account.balance),
                style: const TextStyle(fontWeight: FontWeight.w700),
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
      ],
    );
  }
}

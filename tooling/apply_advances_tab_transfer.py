from pathlib import Path


def read(path):
    return Path(path).read_text()


def write(path, text):
    Path(path).write_text(text)


def replace_once(path, old, new):
    text = read(path)
    if old in text:
        write(path, text.replace(old, new, 1))
        return
    if new in text:
        return
    raise SystemExit(f"Pattern not found in {path}: {old[:160]!r}")


# 1) Closed/settled advances must not remain in active sections.
replace_once(
    "lib/screens/advances_screen.dart",
    "    final open = state.advances\n        .where((item) => item.closedKind == null)\n        .toList();",
    "    final open = state.advances\n        .where(\n          (item) =>\n              item.closedKind == null &&\n              state.advanceRemainingCents(item.id) > 0,\n        )\n        .toList();",
)

# 2) Add Anticipi as a first-class bottom navigation destination.
replace_once(
    "lib/screens/app_shell.dart",
    "      AccountContextAnalyticsScreen(\n        accountId: effectiveAccountId,\n        onAccountChanged: _selectAccount,\n      ),\n      const PlanningScreen(),",
    "      AccountContextAnalyticsScreen(\n        accountId: effectiveAccountId,\n        onAccountChanged: _selectAccount,\n      ),\n      const AdvancesScreen(),\n      const PlanningScreen(),",
)
replace_once(
    "lib/screens/app_shell.dart",
    "          child: FloatingActionButton(\n            tooltip: 'Nuovo movimento. Tieni premuto per voce e preset.',\n            onPressed: () => _open(TransactionType.expense),\n            child: const Icon(Icons.add_rounded),\n          ),",
    "          child: FloatingActionButton(\n            tooltip: index == 3\n                ? 'Nuovo anticipo'\n                : 'Nuovo movimento. Tieni premuto per voce e preset.',\n            onPressed: index == 3\n                ? () => showAdvanceEditor(context)\n                : () => _open(TransactionType.expense),\n            child: const Icon(Icons.add_rounded),\n          ),",
)
replace_once(
    "lib/screens/app_shell.dart",
    "            NavigationDestination(\n              icon: Icon(Icons.insights_outlined),\n              selectedIcon: Icon(Icons.insights_rounded),\n              label: 'Analisi',\n            ),\n            NavigationDestination(\n              icon: Icon(Icons.event_note_outlined),",
    "            NavigationDestination(\n              icon: Icon(Icons.insights_outlined),\n              selectedIcon: Icon(Icons.insights_rounded),\n              label: 'Analisi',\n            ),\n            NavigationDestination(\n              icon: Icon(Icons.handshake_outlined),\n              selectedIcon: Icon(Icons.handshake_rounded),\n              label: 'Anticipi',\n            ),\n            NavigationDestination(\n              icon: Icon(Icons.event_note_outlined),",
)

# 3) Keep true income/expense accounting intact, but expose net transfers for a selected account.
replace_once(
    "lib/services/account_context_service.dart",
    "    return total;\n  }\n\n  static double monthTotal(",
    "    return total;\n  }\n\n  static double transferNetFor(\n    AppState state,\n    int accountId,\n    DateTime from,\n    DateTime to,\n  ) {\n    var total = 0.0;\n    for (final item in state.transactions) {\n      if (item.type != TransactionType.transfer) continue;\n      if (item.date.isBefore(from) || !item.date.isBefore(to)) continue;\n      if (item.toAccountId == accountId) total += item.amount;\n      if (item.accountId == accountId) total -= item.amount;\n    }\n    return total;\n  }\n\n  static double monthTotal(",
)

# 4) Single-account analytics reconcile cash movement without calling transfers income.
replace_once(
    "lib/screens/account_context_analytics_screen.dart",
    "    final savingsRate = income <= 0\n        ? null\n        : ((income - expense) / income * 100);\n    final delta = previousExpense == 0",
    "    final savingsRate = income <= 0\n        ? null\n        : ((income - expense) / income * 100);\n    final transferNet = effectiveAccountId == null\n        ? 0.0\n        : AccountContextService.transferNetFor(\n            state,\n            effectiveAccountId,\n            from,\n            to,\n          );\n    final accountVariation = income - expense + transferNet;\n    final delta = previousExpense == 0",
)
replace_once(
    "lib/screens/account_context_analytics_screen.dart",
    "              Expanded(\n                child: _Metric(\n                  label: 'Risparmio',\n                  value: savingsRate == null\n                      ? '—'\n                      : '${savingsRate.toStringAsFixed(0)}%',\n                ),\n              ),",
    "              Expanded(\n                child: _Metric(\n                  label: effectiveAccountId == null ? 'Risparmio' : 'Variazione',\n                  value: effectiveAccountId == null\n                      ? savingsRate == null\n                            ? '—'\n                            : '${savingsRate.toStringAsFixed(0)}%'\n                      : moneyFor(state, accountVariation, signed: true),\n                  color: effectiveAccountId == null\n                      ? null\n                      : accountVariation < 0\n                      ? context.financeColors.negative\n                      : context.financeColors.positive,\n                ),\n              ),",
)
replace_once(
    "lib/screens/account_context_analytics_screen.dart",
    "          const SizedBox(height: 10),\n          _AnalyticsLine(\n            icon: Icons.repeat_rounded,",
    "          if (effectiveAccountId != null) ...[\n            const SizedBox(height: 10),\n            _AnalyticsLine(\n              icon: Icons.swap_horiz_rounded,\n              text:\n                  'Giroconti netti ${moneyFor(state, transferNet, signed: true)} nel periodo.',\n            ),\n          ],\n          const SizedBox(height: 10),\n          _AnalyticsLine(\n            icon: Icons.repeat_rounded,",
)

# 5) Regression coverage: transfers stay out of income but reconcile a single account.
replace_once(
    "test/account_context_service_test.dart",
    "  test('grouped movements report totals and percentages by category', () {",
    "  test('single-account transfer net reconciles cash without inflating income', () {\n    final state = AppState(AppDatabase())..loading = false;\n    state.accounts = [account(1, 'Portafoglio'), account(2, 'Revolut')];\n    state.transactions = [\n      transaction(\n        id: 1,\n        type: TransactionType.income,\n        amount: 40,\n        accountId: 2,\n      ),\n      transaction(\n        id: 2,\n        type: TransactionType.expense,\n        amount: 52.32,\n        accountId: 2,\n      ),\n      transaction(\n        id: 3,\n        type: TransactionType.transfer,\n        amount: 50,\n        accountId: 1,\n        toAccountId: 2,\n      ),\n    ];\n\n    final from = DateTime(2026, 9, 1);\n    final to = DateTime(2026, 10, 1);\n    final income = AccountContextService.periodTotal(\n      state,\n      2,\n      TransactionType.income,\n      from,\n      to,\n    );\n    final expense = AccountContextService.periodTotal(\n      state,\n      2,\n      TransactionType.expense,\n      from,\n      to,\n    );\n    final transferNet = AccountContextService.transferNetFor(\n      state,\n      2,\n      from,\n      to,\n    );\n\n    expect(income, 40);\n    expect(expense, 52.32);\n    expect(transferNet, 50);\n    expect(income - expense + transferNet, closeTo(37.68, 0.001));\n    expect(\n      AccountContextService.transferNetFor(state, 1, from, to),\n      -50,\n    );\n  });\n\n  test('grouped movements report totals and percentages by category', () {",
)

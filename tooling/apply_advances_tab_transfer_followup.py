from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text()
    if old in text:
        p.write_text(text.replace(old, new, 1))
        return
    if new in text:
        return
    raise SystemExit(f'Pattern not found in {path}: {old[:160]!r}')


replace_once(
    'lib/screens/advances_screen.dart',
    "class AdvancesScreen extends StatelessWidget {\n  const AdvancesScreen({super.key});",
    "class AdvancesScreen extends StatelessWidget {\n  const AdvancesScreen({this.showFab = true, super.key});\n\n  final bool showFab;",
)

replace_once(
    'lib/screens/advances_screen.dart',
    "      floatingActionButton: FloatingActionButton.extended(\n        onPressed: () => showAdvanceEditor(context),\n        icon: const Icon(Icons.add_rounded),\n        label: const Text('Anticipo'),\n      ),",
    "      floatingActionButton: showFab\n          ? FloatingActionButton.extended(\n              onPressed: () => showAdvanceEditor(context),\n              icon: const Icon(Icons.add_rounded),\n              label: const Text('Anticipo'),\n            )\n          : null,",
)

replace_once(
    'lib/screens/app_shell.dart',
    '      const AdvancesScreen(),',
    '      const AdvancesScreen(showFab: false),',
)

replace_once(
    'lib/screens/account_context_analytics_screen.dart',
    "                      AccountContextService.periodTotal(\n                        state,\n                        account.id,\n                        TransactionType.expense,\n                        from,\n                        to,\n                      ),\n                  signed: true,",
    "                      AccountContextService.periodTotal(\n                        state,\n                        account.id,\n                        TransactionType.expense,\n                        from,\n                        to,\n                      ) +\n                      AccountContextService.transferNetFor(\n                        state,\n                        account.id,\n                        from,\n                        to,\n                      ),\n                  signed: true,",
)

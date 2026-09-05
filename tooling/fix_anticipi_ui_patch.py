from pathlib import Path

# Repair the one-time integration script against the actual canonical files.
path = Path('tooling/apply_anticipi_ui_patch.py')
text = path.read_text()
text = text.replace(
    "s = replace_once(s, \"import 'account_screens.dart';\", \"import 'account_screens.dart';\\nimport 'advances_screen.dart';\", 'app shell import')",
    "s = replace_once(s, \"import 'canonical_shell.dart';\", \"import 'advances_screen.dart';\\nimport 'canonical_shell.dart';\", 'app shell import')",
    1,
)
text = text.replace(
    "s = replace_once(s, \"import 'account_screens.dart';\", \"import 'account_screens.dart';\\nimport 'advances_screen.dart';\", 'home advances import')",
    "s = replace_once(s, \"import 'account_screens.dart' show showAccountEditor;\", \"import 'account_screens.dart' show showAccountEditor;\\nimport 'advances_screen.dart';\", 'home advances import')",
    1,
)
path.write_text(text)

# Remove a temporary local extension that clashes with the project's shared
# firstOrNull extension, and an import that became redundant during the core
# implementation. This keeps the branch analyzable before/after the UI patch.
advance_path = Path('lib/screens/advances_screen.dart')
advance = advance_path.read_text()
advance = advance.replace("import '../app_state.dart';\n", '', 1)
advance = advance.replace(
    "\nextension _FirstOrNull<T> on Iterable<T> {\n  T? get firstOrNull => isEmpty ? null : first;\n}\n",
    '\n',
    1,
)
advance_path.write_text(advance)

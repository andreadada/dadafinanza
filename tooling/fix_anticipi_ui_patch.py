from pathlib import Path

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

from pathlib import Path

path = Path('lib/screens/quick_add_page.dart')
source = path.read_text(encoding='utf-8')
old = """                  ButtonSegment(\n                    value: TransactionType.transfer,\n                    label: Text('Trasferisci', maxLines: 1),\n                  ),"""
new = """                  ButtonSegment(\n                    value: TransactionType.transfer,\n                    label: FittedBox(\n                      fit: BoxFit.scaleDown,\n                      child: Text(\n                        'Trasferimento',\n                        maxLines: 1,\n                        softWrap: false,\n                      ),\n                    ),\n                  ),"""
if old not in source:
    raise SystemExit('transfer label pattern not found')
source = source.replace(old, new, 1)
path.write_text(source, encoding='utf-8')

test = Path('test/voice_listening_ux_contract_test.dart')
t = test.read_text(encoding='utf-8')
t = t.replace(
    "expect(source, contains(\"label: Text('Trasferisci', maxLines: 1)\"));",
    "expect(source, contains(\"'Trasferimento'\"));\n    expect(source, contains('fit: BoxFit.scaleDown'));\n    expect(source, contains('softWrap: false'));",
)
test.write_text(t, encoding='utf-8')

from pathlib import Path

path = Path('tooling/apply_anticipi_core_patch.py')
text = path.read_text()
text = text.replace("advance_schema = r'''", 'advance_schema = r"""', 1)
text = text.replace("\n'''\ns = replace_once(s, marker, advance_schema + marker, 'schema method insertion')", "\n\"\"\"\ns = replace_once(s, marker, advance_schema + marker, 'schema method insertion')", 1)
path.write_text(text)

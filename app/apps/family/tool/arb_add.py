"""Adds strings to both language files at once, English and Swedish.

    python3 tool/arb_add.py < strings.json && flutter gen-l10n

where strings.json is {"key": ["English", "Svenska", {placeholders}?]}.
Refuses a key either file already has: a duplicate key silently replaces
the earlier string, which is how a device message once turned into an
event one.
"""
import json
import sys

add = json.load(sys.stdin)
for lang, idx in (('en', 0), ('sv', 1)):
    path = f'lib/l10n/app_{lang}.arb'
    text = open(path).read().rstrip()
    assert text.endswith('}')
    lines = []
    for key, value in add.items():
        if f'"{key}"' in text:
            raise SystemExit(f'{key} exists in {path}')
        lines.append(f'  {json.dumps(key)}: {json.dumps(value[idx], ensure_ascii=False)}')
        if lang == 'en' and len(value) > 2:
            lines.append(f'  {json.dumps("@" + key)}: {json.dumps(value[2], ensure_ascii=False)}')
    open(path, 'w').write(text[:-1].rstrip() + ',\n' + ',\n'.join(lines) + '\n}\n')
print('added', len(add))

"""Writes assets/whats_new.json: this build's number and the release notes
of the last few builds, which the app shows once after each update.

    python3 tool/whats_new.py

Run from app/apps/family whenever the version is bumped (the TestFlight
script does it before building). A test checks the number matches
pubspec.yaml, so a stale file fails loudly rather than showing old news.
"""
import glob, json, os, re

here = os.path.dirname(os.path.abspath(__file__))
app = os.path.dirname(here)
notes_dir = os.path.join(app, '..', '..', '..', 'release-notes')

version = re.search(r'^version:\s*\S+\+(\d+)', open(os.path.join(app, 'pubspec.yaml')).read(), re.M)
current = int(version.group(1))

notes = {}
for path in glob.glob(os.path.join(notes_dir, '*.json')):
    name = os.path.splitext(os.path.basename(path))[0]
    if name.isdigit() and current - 10 < int(name) <= current:
        notes[name] = json.load(open(path, encoding='utf-8'))

out = os.path.join(app, 'assets', 'whats_new.json')
with open(out, 'w', encoding='utf-8') as f:
    json.dump({'build': current, 'notes': dict(sorted(notes.items(), key=lambda kv: -int(kv[0])))},
              f, ensure_ascii=False, indent=1)
    f.write('\n')
print(f'whats_new.json: build {current}, notes for {sorted(map(int, notes))}')

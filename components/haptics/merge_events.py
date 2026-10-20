#!/usr/bin/env python3
"""Adds to the user's events.toml the events of the project file that it lacks (run by the haptics component on every install).

Usage: merge_events.py USER_FILE PROJECT_FILE
The user's file is their settings: an existing key is never changed, comments and layout are kept (tomlkit). A file
that is not valid TOML is an error and stays untouched. Prints the names added, one per line.
An event silenced by the user (`force = 0` on its line, see events.toml) is an existing key: it stays silenced.
Before the file is rewritten, a copy of it is kept next to it (events.toml.YYYYMMDD-HHMMSS, never overwritten): this
file is in no backup of the installer. Nothing to add: nothing rewritten, no copy.
"""
import os
import shutil
import sys
import tempfile
import time
from pathlib import Path

import tomlkit


def merge(user_text, project_text):
    """Returns (merged text, names added). The text is user_text itself when nothing is missing."""
    user = tomlkit.parse(user_text)
    project = tomlkit.parse(project_text)
    if 'events' not in user:
        user['events'] = tomlkit.table()
    added = []
    for name, spec in project.get('events', {}).items():
        if name not in user['events']:
            user['events'][name] = spec
            added.append(name)
    return (tomlkit.dumps(user) if added else user_text), added


def main(argv, now=lambda: time.strftime('%Y%m%d-%H%M%S')):
    user_path, project_path = Path(argv[0]), Path(argv[1])
    text, added = merge(user_path.read_text(encoding='utf-8'), project_path.read_text(encoding='utf-8'))
    if added:
        copy = user_path.with_name(f'{user_path.name}.{now()}')
        with open(copy, 'xb') as kept, open(user_path, 'rb') as current:   # 'x': an existing copy is never replaced
            shutil.copyfileobj(current, kept)
        shutil.copystat(user_path, copy)
        print(f'previous {user_path.name} kept as {copy}', file=sys.stderr)
        handle, temporary = tempfile.mkstemp(dir=user_path.parent, prefix='.events-', suffix='.toml')
        with os.fdopen(handle, 'w', encoding='utf-8') as out:
            out.write(text)
        os.chmod(temporary, user_path.stat().st_mode & 0o777)
        os.replace(temporary, user_path)
    print('\n'.join(added))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

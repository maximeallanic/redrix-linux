#!/usr/bin/env python3
"""Adds or removes extension UUIDs in org.gnome.shell enabled-extensions, keeping every other entry and its order.

Usage: enabled_extensions.py add|remove UUID...
"""
import ast
import subprocess
import sys

KEY = ['org.gnome.shell', 'enabled-extensions']


def updated(current, action, uuids):
    if action == 'add':
        return current + [u for u in uuids if u not in current]
    if action == 'remove':
        return [u for u in current if u not in uuids]
    raise ValueError(f'unknown action {action!r}')


def parse(text):
    """gsettings prints '@as []' for an empty list and "['a', 'b']" otherwise."""
    text = text.strip()
    if text.startswith('@as '):
        text = text[4:]
    return list(ast.literal_eval(text))


def main(argv):
    if len(argv) < 2 or argv[0] not in ('add', 'remove'):
        print(__doc__, file=sys.stderr)
        return 2
    current = parse(subprocess.check_output(['gsettings', 'get', *KEY], text=True))
    new = updated(current, argv[0], argv[1:])
    if new != current:
        subprocess.check_call(['gsettings', 'set', *KEY, str(new)])
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

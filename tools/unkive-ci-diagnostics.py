"""Expose error headers/stack locations as API-readable annotations, without payloads."""
import re
import sys
from pathlib import Path

script, path = sys.argv[1:]
lines = re.sub(r'\x1b\[[0-9;]*m', '', Path(path).read_text(encoding='utf-8', errors='replace')).splitlines()
pattern = re.compile(r'^\s*(?:AssertionError|Error(?:\s|\[|:)|TypeError|ReferenceError|SyntaxError|locator\..*Timeout|page\..*Timeout|at\s+.*:\d+|UNKIVE_.*TIMEOUT)')
selected = [line.strip()[:280] for line in lines if pattern.search(line)][-8:]
message = script + ': ' + ('\n'.join(selected) or 'Validation returned nonzero. Full log retained in artifact.')
message = message.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
print('::error title=UNKIVE exact-SHA browser verification::' + message)

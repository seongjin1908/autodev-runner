#!/usr/bin/env bash
set -euo pipefail

# Execute the exact embedded batch guard against isolated synthetic git changes.
# This never clones or writes to a production repository.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT/scripts/develop_target.sh" <<'PY'
import os
import pathlib
import subprocess
import sys
import tempfile

source = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8')
assert source.count('guard_changes() {') == 1
section = source.split('guard_changes() {', 1)[1].split('\n}\n\nsanitize_tail()', 1)[0]
marker = 'python - "$MAX_CHANGED_FILES" <<\'PY\'\n'
assert marker in section, 'could not locate active guard code'
guard_code = section.split(marker, 1)[1].rsplit('\nPY', 1)[0]

with tempfile.TemporaryDirectory(prefix='saju-guard-test-') as temporary:
    root = pathlib.Path(temporary)
    (root / 'backend').mkdir()
    (root / 'backend' / 'analysis.ts').write_text('export const analysis = 1;\n')
    subprocess.run(['git', 'init', '--quiet', '-b', 'main'], cwd=root, check=True)
    subprocess.run(['git', 'add', '.'], cwd=root, check=True)
    subprocess.run(['git', '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '--quiet', '-m', 'baseline'], cwd=root, check=True)

    def verify(path, expected, alias='saju-core'):
        subprocess.run(['git', 'reset', '--hard', 'HEAD'], cwd=root, check=True, stdout=subprocess.DEVNULL)
        subprocess.run(['git', 'clean', '-fd'], cwd=root, check=True, stdout=subprocess.DEVNULL)
        file = root / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text('probe\n' if path != 'backend/analysis.ts' else 'export const analysis = 2;\n')
        env = {**os.environ, 'ALIAS': alias}
        run = subprocess.run([sys.executable, '-c', guard_code, '10'], cwd=root, env=env, text=True, capture_output=True)
        if run.returncode != expected:
            raise AssertionError(f'{alias}: {path} yielded {run.returncode} instead of {expected}: {run.stdout} {run.stderr}')

    for path in ['probe-tmp.mjs', 'probe-tmp.py', 'scripts/probe-debug.mjs', 'scripts/_probe.ts', 'scripts/probe_diagnostics.ts', 'scripts/tmp-dump-runner.mjs', 'scripts/tmp-full-answers.ts', 'scripts/tmp-run2.mjs', 'scripts/tmp-xprofile-dump.ts', '.tmp-smoke-v24.ts']:
        verify(path, 2)
    verify('backend/analysis.ts', 0)
    verify('probe-tmp.mjs', 0, alias='creative-studio')
    verify('.github/workflows/unsafe.yml', 2, alias='creative-studio')

print('PASS: disposable saju probes denied, real code allowed, unrelated aliases preserved')
PY

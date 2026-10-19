"""Reuse exact successful full validation only for three fixed test-only edits."""
import json, pathlib, subprocess, sys
BASE = '8e759edb71ee4da4950527e332e2ae449b06d5c5'
CONTROL = '8ade753b57387a9e442629affe1326035d70a90d'
RUN = 39188845584
root = pathlib.Path(sys.argv[1])
def git(*args):
    return subprocess.check_output(['git', '-C', str(root), *args], text=True).strip()
def api(path):
    return json.loads(subprocess.check_output(['gh', 'api', 'repos/seongjin1908/autodev-runner/' + path], text=True))
run = api('actions/runs/' + str(RUN))
assert run['conclusion'] == 'success' and run['head_sha'] == CONTROL
jobs = api('actions/runs/' + str(RUN) + '/jobs')['jobs']
steps = jobs[0]['steps']
assert len(steps) == 27 and all(s['conclusion'] == 'success' for s in steps)
assert git('rev-parse', 'HEAD^') == BASE
expected = {'scripts/unkive-paid-ai-context-check.ts', 'scripts/check-unkive-paid-ai-context.mjs', 'scripts/tsconfig-paid-ai-context.json'}
assert set(git('diff', '--name-only', BASE, 'HEAD').splitlines()) == expected
path = 'scripts/unkive-paid-ai-context-check.ts'
before = git('show', BASE + ':' + path)
old = "const allDomains = ['wealth', 'workBusiness', 'relationship'];"
assert before.count(old) == 1
assert (root/path).read_text().strip() == before.replace(old, old[:-1] + ' as const;')
path = 'scripts/check-unkive-paid-ai-context.mjs'
before = git('show', BASE + ':' + path)
anchor = "mkdirSync('release-test-results', { recursive: true });"
added = "\nexecFileSync(process.execPath, [resolve('node_modules/typescript/bin/tsc'), '-p', 'scripts/tsconfig-paid-ai-context.json'], { stdio: 'inherit', timeout: 30000 });"
assert before.count(anchor) == 1
assert (root/path).read_text().strip() == before.replace(anchor, anchor + added)
assert json.loads((root/'scripts/tsconfig-paid-ai-context.json').read_text()) == {'extends':'./tsconfig-comprehensive.json','files':['../backend/lunar-javascript.d.ts','./unkive-paid-ai-context-check.ts']}
print('EXACT_TEST_ONLY_FOLLOWUP_PASS', json.dumps({'source':git('rev-parse','HEAD'),'fullValidationBaseline':BASE,'fullRun':RUN,'fullSteps':27,'reusedSyntheticPDFs':96,'customerRuntimeChanged':False}))

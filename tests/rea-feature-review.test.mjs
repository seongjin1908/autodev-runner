import test from 'node:test';
import assert from 'node:assert/strict';
import { buildFeatureBrief } from '../scripts/rea-feature-review.mjs';

const valid = () => ({
  project: 'UNKIVE',
  target: 'public demo of an app',
  access_basis: 'public-ui-only',
  inspection_mode: 'public-ui-observation',
  authorization_record: 'publicly accessible UX only; no binary or internal traffic analysis',
  features: [{
    name: 'Compare saved reports',
    priority: 'P1',
    independent_design: 'Implement a new comparison view using our own report model.',
    rights_review: 'passed',
    evidence: [{ source: 'demo', locator: 'screen: saved-report', observation: 'Two reports can be compared by heading.' }],
    acceptance_tests: ['Shows only reports owned by the authenticated user.'],
  }],
});

test('creates evidence-based brief without running analysis', () => {
  const result = buildFeatureBrief(valid());
  assert.match(result, /Feature review: UNKIVE/);
  assert.match(result, /Compare saved reports/);
  assert.match(result, /Acceptance tests:/);
});

test('rejects binary inspection on public UI basis', () => {
  const input = valid(); input.inspection_mode = 'local-static';
  assert.throws(() => buildFeatureBrief(input), /does not authorize/);
});

test('requires rights review and concrete evidence', () => {
  const input = valid(); input.features[0].evidence = [];
  assert.throws(() => buildFeatureBrief(input), /evidence/);
});

test('flags review pending as blocked', () => {
  const input = valid(); input.features[0].rights_review = 'pending';
  assert.match(buildFeatureBrief(input), /BLOCKED/);
});

test('rejects obvious credentials', () => {
  const input = valid(); input.authorization_record = '-----BEGIN PRIVATE KEY-----';
  assert.throws(() => buildFeatureBrief(input), /credential/);
});

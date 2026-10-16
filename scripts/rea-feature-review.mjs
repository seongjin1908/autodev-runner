#!/usr/bin/env node
/**
 * Turn an explicitly authorized REA/public-UI investigation into an evidence-led
 * feature brief. This script never executes REA, downloads applications, or
 * accesses network, private source, credentials, or other repositories.
 * Usage: node scripts/rea-feature-review.mjs review.json
 */
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const BASES = new Set(['owned', 'explicit-permission', 'public-ui-only']);
const MODES = new Set(['local-static', 'public-ui-observation']);
const PRIORITIES = new Set(['P0', 'P1', 'P2']);
const secretPatterns = [
  /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/i,
  /\bgh[pousr]_[a-zA-Z0-9]{20,}\b/,
  /\bsk-[a-zA-Z0-9_-]{24,}\b/,
];

function requiredText(x, field) {
  if (typeof x !== 'string' || !x.trim() || x.length > 2000) {
    throw new Error(`${field}: required non-empty text up to 2000 chars`);
  }
  if (secretPatterns.some((pattern) => pattern.test(x))) {
    throw new Error(`${field}: potential credential material detected`);
  }
  return x.trim().replace(/\s+/g, ' ').replace(/[<>]/g, '');
}

export function buildFeatureBrief(data) {
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    throw new Error('review: expected JSON object');
  }
  const project = requiredText(data.project, 'project');
  const target = requiredText(data.target, 'target');
  const accessBasis = requiredText(data.access_basis, 'access_basis');
  const mode = requiredText(data.inspection_mode, 'inspection_mode');
  if (!BASES.has(accessBasis)) throw new Error('access_basis: unsupported value');
  if (!MODES.has(mode)) throw new Error('inspection_mode: unsupported value');
  if (accessBasis === 'public-ui-only' && mode !== 'public-ui-observation') {
    throw new Error('public UI access does not authorize static or binary inspection');
  }
  const permission = requiredText(data.authorization_record, 'authorization_record');
  if (!Array.isArray(data.features) || data.features.length < 1 || data.features.length > 20) {
    throw new Error('features: must contain 1-20 entries');
  }
  const lines = [
    `# Feature review: ${project}`,
    '',
    `- Target: ${target}`,
    `- Access basis: ${accessBasis}`,
    `- Inspection mode: ${mode}`,
    `- Authorization record: ${permission}`,
    '- Result: planning only; no automatic code copy, deployment, or install',
    '',
  ];
  for (const [index, item] of data.features.entries()) {
    if (!item || typeof item !== 'object') throw new Error(`features[${index}]: invalid`);
    const prefix = `features[${index}]`;
    const name = requiredText(item.name, `${prefix}.name`);
    const priority = requiredText(item.priority, `${prefix}.priority`);
    if (!PRIORITIES.has(priority)) throw new Error(`${prefix}.priority: must be P0/P1/P2`);
    const design = requiredText(item.independent_design, `${prefix}.independent_design`);
    const rights = requiredText(item.rights_review, `${prefix}.rights_review`);
    if (!['passed', 'pending'].includes(rights)) throw new Error(`${prefix}.rights_review: passed or pending`);
    if (!Array.isArray(item.evidence) || !item.evidence.length || item.evidence.length > 20) {
      throw new Error(`${prefix}.evidence: required 1-20 evidence entries`);
    }
    if (!Array.isArray(item.acceptance_tests) || !item.acceptance_tests.length || item.acceptance_tests.length > 20) {
      throw new Error(`${prefix}.acceptance_tests: required 1-20 tests`);
    }
    const evidence = item.evidence.map((e, idx) => {
      const key = `${prefix}.evidence[${idx}]`;
      return `${requiredText(e.source, key + '.source')} (${requiredText(e.locator, key + '.locator')}): ${requiredText(e.observation, key + '.observation')}`;
    });
    const tests = item.acceptance_tests.map((t, idx) => requiredText(t, `${prefix}.acceptance_tests[${idx}]`));
    lines.push(`## ${priority} — ${name}`, '', `- Rights review: **${rights}**${rights === 'pending' ? ' — BLOCKED: do not implement until reviewed' : ''}`);
    lines.push(`- Independent implementation: ${design}`, '- Evidence:');
    for (const e of evidence) lines.push(`  - ${e}`);
    lines.push('- Acceptance tests:');
    for (const t of tests) lines.push(`  - ${t}`);
    lines.push('');
  }
  return lines.join('\n');
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  try {
    if (process.argv.length !== 3) throw new Error('Usage: node scripts/rea-feature-review.mjs review.json');
    const parsed = JSON.parse(readFileSync(process.argv[2], 'utf8'));
    process.stdout.write(buildFeatureBrief(parsed) + '\n');
  } catch (error) {
    process.stderr.write(`REA review rejected: ${error.message}\n`);
    process.exitCode = 1;
  }
}

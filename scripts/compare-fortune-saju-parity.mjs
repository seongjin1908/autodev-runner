import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';

const [fortuneDir='fortune', sajuDir='saju'] = process.argv.slice(2);
const read = p => fs.readFileSync(p,'utf8');
const readBuffer = p => fs.readFileSync(p);
const digest = value => crypto.createHash('sha256').update(value).digest('hex');
const gitBlobSha = value => crypto.createHash('sha1').update('blob ' + value.length + '\0').update(value).digest('hex');
const parseExporter = cwd => JSON.parse(execFileSync(process.execPath,['scripts/saju-shadow-parity-export.mjs'],{cwd,encoding:'utf8'}));

const fortuneLock = JSON.parse(read(path.join(fortuneDir,'contracts/migration-lock.v1.json')));
const sajuLock = JSON.parse(read(path.join(sajuDir,'contracts/migration-lock.v1.json')));
const lockDefinitionMatch = JSON.stringify(fortuneLock) === JSON.stringify(sajuLock);
if (!lockDefinitionMatch) {
  console.error('MIGRATION_LOCK_DEFINITION_MISMATCH');
  process.exit(1);
}
if (fortuneLock.schemaVersion !== 'fortune-saju-migration-lock-v1') {
  console.error('MIGRATION_LOCK_SCHEMA_MISMATCH',fortuneLock.schemaVersion);
  process.exit(1);
}

const lockedFiles = Object.entries(fortuneLock.files || {});
const lockChecks = lockedFiles.map(([relativePath,expected]) => {
  const fortuneBytes = readBuffer(path.join(fortuneDir,relativePath));
  const sajuBytes = readBuffer(path.join(sajuDir,relativePath));
  const fortuneSha = gitBlobSha(fortuneBytes);
  const sajuSha = gitBlobSha(sajuBytes);
  return {
    path:relativePath,
    expected,
    fortuneSha,
    sajuSha,
    byteIdentical:fortuneBytes.equals(sajuBytes),
    fortuneMatchesLock:fortuneSha === expected,
    sajuMatchesLock:sajuSha === expected
  };
});
const migrationLockMatch = lockChecks.every(item =>
  item.byteIdentical && item.fortuneMatchesLock && item.sajuMatchesLock
);
if (!migrationLockMatch) {
  console.error('MIGRATION_LOCK_CONTENT_MISMATCH',lockChecks.filter(item =>
    !item.byteIdentical || !item.fortuneMatchesLock || !item.sajuMatchesLock
  ));
  process.exit(1);
}

const fortuneContract = read(path.join(fortuneDir,'contracts/fortune-platform.v1.schema.json'));
const sajuContract = read(path.join(sajuDir,'contracts/fortune-platform.v1.schema.json'));
const contractMatch = fortuneContract === sajuContract;

if (!contractMatch) {
  console.error('SHADOW_PARITY_CONTRACT_MISMATCH', {
    fortune:digest(fortuneContract),
    saju:digest(sajuContract)
  });
  process.exit(1);
}

const parityPolicy = JSON.parse(read(path.join(fortuneDir,'contracts/saju-parity-policy.v1.json')));
const approvedDivergences = new Map((parityPolicy.knownDivergences || [])
  .filter(item => item.status === 'REFERENCE_VALIDATED')
  .map(item => [item.vectorId, new Set(item.approvedDifferenceFields || [])]));

const fortune = parseExporter(fortuneDir);
const saju = parseExporter(sajuDir);
if (fortune.schemaVersion !== 'saju-shadow-parity-v1' || saju.schemaVersion !== 'saju-shadow-parity-v1') {
  throw new Error('SHADOW_PARITY_SCHEMA_VERSION_MISMATCH');
}

const sajuById = new Map(saju.cases.map(item => [item.id,item]));
const comparisons = fortune.cases.map(left => {
  const right = sajuById.get(left.id);
  if (!right) return { id:left.id, status:'MISSING_SAJU_CASE', fortune:left, saju:null };
  const fields = ['pillars','dayMaster','principalElements'];
  const differences = fields.filter(field => JSON.stringify(left[field]) !== JSON.stringify(right[field]));
  if (!differences.length) return { id:left.id, status:'MATCH', differences, fortune:left, saju:right };
  const approved = approvedDivergences.get(left.id);
  const approvedExact = approved && differences.length === approved.size && differences.every(field => approved.has(field));
  return { id:left.id, status:approvedExact ? 'KNOWN_DIFF' : 'UNEXPECTED_DIFF', differences, fortune:left, saju:right };
});
for (const item of saju.cases) {
  if (!fortune.cases.some(left => left.id === item.id)) comparisons.push({id:item.id,status:'MISSING_FORTUNE_CASE',fortune:null,saju:item});
}

const report = {
  schemaVersion:'fortune-saju-shadow-parity-report-v1',
  generatedAt:new Date().toISOString(),
  migrationLockMatch,
  lockChecks,
  contractSha256:digest(fortuneContract),
  contractMatch,
  fortuneHead:process.env.FORTUNE_HEAD || null,
  sajuHead:process.env.SAJU_HEAD || null,
  caseCount:comparisons.length,
  matchCount:comparisons.filter(x=>x.status==='MATCH').length,
  knownDiffCount:comparisons.filter(x=>x.status==='KNOWN_DIFF').length,
  unexpectedDiffCount:comparisons.filter(x=>x.status==='UNEXPECTED_DIFF').length,
  missingCount:comparisons.filter(x=>x.status.startsWith('MISSING_')).length,
  comparisons
};

fs.mkdirSync('artifacts',{recursive:true});
fs.writeFileSync('artifacts/fortune-saju-shadow-parity.json',JSON.stringify(report,null,2)+'\n');
console.log('FORTUNE_SAJU_SHADOW_PARITY', {
  migrationLockMatch:report.migrationLockMatch,
  contractMatch:report.contractMatch,
  caseCount:report.caseCount,
  matchCount:report.matchCount,
  knownDiffCount:report.knownDiffCount,
  unexpectedDiffCount:report.unexpectedDiffCount,
  missingCount:report.missingCount
});

if (!report.migrationLockMatch || !report.contractMatch || report.missingCount > 0 || report.unexpectedDiffCount > 0) process.exit(1);

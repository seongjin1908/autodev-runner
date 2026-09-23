import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';

const [fortuneDir='fortune', sajuDir='saju'] = process.argv.slice(2);
const read = p => fs.readFileSync(p,'utf8');
const digest = value => crypto.createHash('sha256').update(value).digest('hex');
const parseExporter = cwd => JSON.parse(execFileSync(process.execPath,['scripts/saju-shadow-parity-export.mjs'],{cwd,encoding:'utf8'}));

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
  return { id:left.id, status:differences.length ? 'DIFF' : 'MATCH', differences, fortune:left, saju:right };
});
for (const item of saju.cases) {
  if (!fortune.cases.some(left => left.id === item.id)) comparisons.push({id:item.id,status:'MISSING_FORTUNE_CASE',fortune:null,saju:item});
}

const report = {
  schemaVersion:'fortune-saju-shadow-parity-report-v1',
  generatedAt:new Date().toISOString(),
  contractSha256:digest(fortuneContract),
  contractMatch,
  fortuneHead:process.env.FORTUNE_HEAD || null,
  sajuHead:process.env.SAJU_HEAD || null,
  caseCount:comparisons.length,
  matchCount:comparisons.filter(x=>x.status==='MATCH').length,
  diffCount:comparisons.filter(x=>x.status==='DIFF').length,
  missingCount:comparisons.filter(x=>x.status.startsWith('MISSING_')).length,
  comparisons
};

fs.mkdirSync('artifacts',{recursive:true});
fs.writeFileSync('artifacts/fortune-saju-shadow-parity.json',JSON.stringify(report,null,2)+'\n');
console.log('FORTUNE_SAJU_SHADOW_PARITY', {
  contractMatch:report.contractMatch,
  caseCount:report.caseCount,
  matchCount:report.matchCount,
  diffCount:report.diffCount,
  missingCount:report.missingCount
});

if (report.missingCount > 0) process.exit(1);

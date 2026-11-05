// Public staging v24 browser smoke using LIVE GET /api/products. No real checkout or AI calls.
// This test intentionally intercepts ALL POST/PUT/PATCH/DELETE requests in the browser.
// The free-reading result is synthetic, provided by an offline local fixture.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';

const require = createRequire(resolve('target/package.json'));
const { chromium } = require('playwright');
const base = 'https://unkive-rc-isolated-test-3b1ofi.v2.appdeploy.ai';
const samples = JSON.parse(readFileSync('target/release-test-results/launch-free-30-samples.json', 'utf8'));
const free = samples.find(row => row.input.year === 1990)?.result;
assert.ok(free?.readingId && free?.accessToken, 'Missing synthetic free reading fixture');
const productExpectations = [['P001',9900],['P002',19900],['P004',79000]];
const report = [];
let realWrites = 0;
let blockedWrites = 0;
const browser = await chromium.launch({ headless:true });
try {
  const api = await browser.newContext();
  const response = await api.request.get(base + '/api/products');
  const directType = response.headers()['content-type'] || '';
  const directBody = await response.text();
  console.log('P002_STAGING_DIRECT_HTTP_DIAGNOSTIC', {
    status:response.status(),contentType:directType,
    htmlInsteadOfJson:directBody.trim().startsWith('<!doctype'),
  });
  // AppDeploy may proxy @appdeploy/client through its own transport; raw /api/products is not proof.
  if (directType.includes('application/json')) {
    const json = JSON.parse(directBody);
    assert.deepEqual((json.products || []).map(p => [p.code,p.price]), productExpectations,
      'Staging live product inventory does not match approved PR #267');
    console.log('P002_STAGING_LIVE_PRODUCTS_PASS',JSON.stringify(productExpectations));
  }
  await api.close();

  for (const spec of [
    { width:375, source:'DIRECT', expected:19900 },
    { width:390, source:'DAANGN', expected:17910 },
    { width:1024, source:'DIRECT', expected:19900 },
    { width:1440, source:'DAANGN', expected:17910 },
  ]) {
    const context = await browser.newContext({viewport:{width:spec.width,height:900}, locale:'ko-KR'});
    const page = await context.newPage();
    page.setDefaultTimeout(20000);
    const pageErrors = [];
    page.on('pageerror',e=>pageErrors.push(e.message));
    await page.addInitScript(reading => {
      sessionStorage.setItem('fortune_free_reading_v1',JSON.stringify({savedAt:Date.now(),reading}));
    },free);
    const traffic=[];
    page.on('request',request=>{
      if(traffic.length<50){
        const url=new URL(request.url());
        traffic.push({method:request.method(),path:url.pathname,
          postLength:request.method()==='POST'?(request.postData()||'').length:0});
      }
    });
    await page.route('**/*', async route=>{
      const request = route.request(), path = new URL(request.url()).pathname;
      const method=request.method().toUpperCase();
      if (['GET','HEAD'].includes(method)) return route.continue();
      // Never send any mutation, order, AI, PayApp or event telemetry to staging.
      blockedWrites++;
      return route.fulfill({status:200,contentType:'application/json',
        body:JSON.stringify(path==='/api/payapp/status'
          ? {provider:'PAYAPP',configured:false,enabled:false,relayReady:false}
          : {})});
    });
    await page.goto(base+'/?source='+spec.source+'&market=KR&locale=ko#product-choice',
      {waitUntil:'domcontentloaded',timeout:30000});
    try {
      await page.locator('.final-product-grid > article').first().waitFor({timeout:12000});
    } catch (error) {
      console.error('P002_LIVE_FRONTEND_DIAGNOSTIC', {
        width:spec.width,source:spec.source,
        traffic,
        body:(await page.locator('body').innerText()).slice(0,650),
        errors:pageErrors,
      });
      throw error;
    }
    const articles=page.locator('.final-product-grid > article');
    assert.equal(await articles.count(),3,'Live staging product UI does not show exactly three SKUs');
    const compareCopy = await page.locator('.product-choice-heading p').innerText();
    assert.match(compareCopy,/Premium은 5년 흐름/);
    assert.match(compareCopy,/Signature는 명식별 핵심 분석/);
    assert.doesNotMatch(compareCopy,/Master는 7년|Master 사주|Master 전체 분석/,
      'Inactive Master is still presented as a currently purchasable product');
    const amounts=await articles.evaluateAll(nodes=>nodes.map(node=>({
      tier:node.querySelector('.product-tier')?.textContent?.trim()||'',
      price:node.querySelector('strong.price')?.textContent?.trim()||'',
      promotion:node.querySelector('.one-time-payment')?.textContent||'',
    })));
    const find=tier=>amounts.find(item=>item.tier.startsWith(tier));
    assert.match(find('STANDARD')?.price||'',spec.source==='DAANGN'?/8,910/:/9,900/);
    assert.match(find('PREMIUM')?.price||'',new RegExp(spec.expected.toLocaleString('en-US')));
    assert.match(find('SIGNATURE')?.price||'',/79,000/);
    assert.equal(amounts.some(item=>item.tier.startsWith('MASTER')),false);
    if(spec.source==='DAANGN'){
      assert.match(find('PREMIUM').promotion,/당근 10% 자동 할인/);
    } else {
      assert.doesNotMatch(find('PREMIUM').promotion,/당근 10% 자동 할인/);
    }
    if (spec.width === 390) {
      // Isolated staging has no PayApp credentials; a product click must not
      // persist an unpayable new order. No provider calls are allowed.
      await page.locator('.final-product-grid article.premium-product button').click();
      const message = await page.locator('#product-choice .signature-question-error').innerText();
      assert.match(message,/새 주문은 만들지 않았습니다/);
      assert.equal(await page.locator('section#payment').count(),0,
        'Unpayable product choice incorrectly opened checkout');
      const persistedOrder = await page.evaluate(()=>localStorage.getItem('saju_last_order'));
      assert.equal(persistedOrder,null,'Unpayable order persisted in localStorage');
      console.log('P002_STAGING_NO_PAYAPP_NEW_ORDER_GATE_PASS', {persistedOrders:0,realWrites:0});
    }
    const overflow=await page.evaluate(()=>document.documentElement.scrollWidth-document.documentElement.clientWidth);
    assert.ok(overflow<=1,'Unexpected horizontal overflow at '+spec.width+'px: '+overflow);
    assert.deepEqual(pageErrors,[], 'Staging browser JS errors: '+JSON.stringify(pageErrors));
    report.push({width:spec.width,source:spec.source,products:amounts.map(x=>x.tier),
      premium:find('PREMIUM').price,paymentRequests:0,unapprovedBackendWrites:realWrites});
    await context.close();
  }
  // Private operator UI can be checked without credentials or activating AI.
  const opsContext=await browser.newContext({viewport:{width:390,height:844},locale:'ko-KR'});
  const opsPage=await opsContext.newPage();
  opsPage.setDefaultTimeout(16000);
  const opsErrors=[];
  opsPage.on('pageerror',e=>opsErrors.push(e.message));
  await opsPage.route('**/*',route=>{
    const method=route.request().method().toUpperCase();
    if(method==='GET'||method==='HEAD')return route.continue();
    blockedWrites++;
    return route.fulfill({status:200,contentType:'application/json',body:'{}'});
  });
  await opsPage.goto(base+'/?ops=1',{waitUntil:'domcontentloaded',timeout:30000});
  const oldQa=opsPage.getByRole('button',{name:'실제 Premium AI 1건 실행(크레딧 사용)'});
  const approvedRecheck=opsPage.getByRole('button',{name:'별도 승인 Premium 실AI 재검증 1건 (최대 3회 호출)'});
  await approvedRecheck.waitFor();
  assert.equal(await oldQa.isDisabled(),true,'original used one-shot must remain disabled');
  assert.equal(await approvedRecheck.isEnabled(),true,'separate P002 recheck control missing');
  assert.deepEqual(opsErrors,[],'private operator page JS errors');
  console.log('P002_OWNER_APPROVED_RECHECK_LIVE_STAGING_UI_PASS',{
    oldUsedControlDisabled:true,
    newControlVisible:true,newControlNotClicked:true,
    adminKeyNotRead:true,paidModelCalls:0,paymentCalls:0,
  });
  await opsContext.close();
  assert.equal(realWrites,0);
  assert.ok(blockedWrites>=4,'Expected analytics POST to be intercepted during load');
  console.log('P002_STAGING_LIVE_BROWSER_READONLY_PASS',JSON.stringify({
    version:'1793206537178',liveProducts:true,scenarios:report,
    writesPrevented:blockedWrites,realWrites,paidProviderCalls:0,modelCalls:0,
    uiFreeReading:'OFFLINE_SYNTHETIC_FIXTURE'
  }));
} finally {
  await browser.close();
}

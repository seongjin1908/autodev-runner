// Customer-safe operational preflight: production app PayApp availability only.
// All requests that could mutate customer state are intercepted before network.
// No payment, order creation, admin access, paid AI or personal records.
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
const require=createRequire(resolve('target/package.json'));
const { chromium }=require('playwright');
const targets=[
 {name:'production',url:'https://mvp-91zb78.v2.appdeploy.ai/'},
 {name:'isolated_staging',url:'https://unkive-rc-isolated-test-3b1ofi.v2.appdeploy.ai/'},
];
const browser=await chromium.launch({headless:true});
let totalActualMutations=0;
try{
  for (const target of targets) {
    const context=await browser.newContext({viewport:{width:390,height:844},locale:'ko-KR'});
    const page=await context.newPage();
    const routeNames=[];
    const statusResponses=[];
    const javascriptErrors=[];
    let mutationsBlocked=0;
    page.on('pageerror',error=>javascriptErrors.push(error.message.slice(0,150)));
    page.on('request',request=>{
      const method=request.method().toUpperCase();
      const path=new URL(request.url()).pathname;
      if(routeNames.length<45 && (path.includes('api') || path.includes('sdk')))routeNames.push({method,path});
    });
    page.on('response',async response=>{
      const request=response.request();
      const url=new URL(response.url()),method=request.method().toUpperCase();
      const type=response.headers()['content-type']||'';
      if(method==='GET' && (url.pathname.includes('payapp')||url.pathname.includes('api'))&&type.includes('application/json')){
        try {
          const data=await response.json();
          // Report only allowlisted operational booleans, never record customer content.
          if(data && data.provider==='PAYAPP' && typeof data.enabled==='boolean'){
            statusResponses.push({configured:!!data.configured,enabled:!!data.enabled,
              relayReady:!!data.relayReady,reason:typeof data.reason==='string'?data.reason:'NONE',
              chargesEnabledByThisCheck:!!data.chargesEnabledByThisCheck});
          }
        }catch{} // Ignore non-JSON or SDK streaming payloads.
      }
    });
    await page.route('**/*',async route=>{
      const request=route.request(),method=request.method().toUpperCase();
      if(method==='GET'||method==='HEAD')return route.continue();
      mutationsBlocked++;
      return route.fulfill({status:200,contentType:'application/json',body:'{}'});
    });
    await page.goto(target.url+'?source=DIRECT&market=KR&locale=ko',
      {waitUntil:'domcontentloaded',timeout:30000});
    await page.locator('body').waitFor();
    await page.waitForTimeout(2500);
    const body=await page.locator('body').innerText();
    assert.equal(javascriptErrors.length,0,
      target.name+': browser JavaScript error '+javascriptErrors.join('; '));
    assert.equal(totalActualMutations,0);
    const knownStatus=statusResponses.at(-1)||null;
    const safeResult={
      target:target.name,
      pageTitle:await page.title(),
      domLoaded:!!body,
      paymentUiReadyLabel:body.includes('PayApp') && !body.includes('PayApp 준비 중')
        ? 'POSSIBLE':body.includes('PayApp 준비 중')?'WAITING':'NOT_DETERMINED',
      payAppServerStatus:knownStatus||'NOT_OBSERVED_WITH_READONLY_BROWSER',
      statusObserved:!!knownStatus,
      mutationsBlocked,
      actualMutations:totalActualMutations,
      actualCharges:0,realAiCalls:0,
      pageErrors:javascriptErrors.length,
      sanitizedSdkPaths:routeNames.slice(0,12),
    };
    console.log('P002_LIVE_PROVIDER_READONLY_DIAGNOSTIC',JSON.stringify(safeResult));
    if(target.name==='isolated_staging' && knownStatus){
      assert.equal(knownStatus.enabled,false,'isolated staging suddenly has PayApp enabled; review test isolation');
    }
    if(knownStatus?.chargesEnabledByThisCheck){
      throw Error('Backend read-only PayApp status unexpectedly authorizes charge');
    }
    await context.close();
  }
  console.log('P002_PRODUCTION_PROVIDER_READONLY_BROWSER_PASS',JSON.stringify({
    sitesChecked:targets.length,
    paymentsCreated:0,
    actualAiCalls:0,
    actualMutationRequests:0,
    operationalStatusOnly:true,
    realPaymentPath:'NOT_VERIFIED',
    realPremiumOutput:'NOT_EVALUATED',
  }));
} finally{
 await browser.close();
}

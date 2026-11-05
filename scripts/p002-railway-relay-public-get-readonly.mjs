// Public GET-only audit of the dedicated Railway P002 merchant relay.
// Never send a merchant key, never POST /register, and never create a PayApp order.
import assert from 'node:assert/strict';
const host='https://saju-p002-isolated-function-staging.up.railway.app';
const get=async path=>{
  const response=await fetch(host+path,{method:'GET',headers:{Accept:'application/json'},signal:AbortSignal.timeout(5500),redirect:'error'});
  let body=null;try{body=await response.json();}catch{}
  return {status:response.status,body,headers:response.headers};
};
const health=await get('/health');
assert.equal(health.status,200,'Dedicated Relay GET health is down');
assert.equal(health.body?.ok,true);
assert.equal(health.body?.service,'saju-p002-dedicated-relay');
const catalog=await get('/catalog');
assert.equal(catalog.status,200,'Merchant Relay catalog is unavailable');
assert.equal(catalog.body?.ok,true);
assert.equal(catalog.body?.protocol,'SAJU_MYEONGKWAE_P002_V1');
assert.equal(catalog.body?.products?.['Premium 사주'],19900);
const required=[
  'merchant-register-json-v1','merchant-register-auth-v1',
  'relay-state-token-v1','callback-order-uuid-v1','merchant-signed-feedback-v1'];
for(const entry of required)assert.ok(catalog.body.capabilities?.includes(entry),
  'Missing preflight feature '+entry);
const denied=await get('/merchant/verify');
assert.equal(denied.status,403,'Merchant authentication NEGATIVE control did not deny anonymous GET');
assert.notEqual(denied.body?.merchantAuthenticated,true);
const publicReport={
  host:'saju-p002-isolated-function-staging.up.railway.app',
  health:'PASS',catalog:'PASS',catalogSku:'P002',catalogPriceKrw:19900,
  exactProtocol:'SAJU_MYEONGKWAE_P002_V1',
  capabilitiesMatched:required.length,
  unauthorizedMerchantVerifyDenied:denied.status,
  merchantCredentialAlignment:'NOT_VERIFIED',
  actualCharge:'NOT_TESTED',
  actualOrderWrites:0,postRequests:0,actualAiCalls:0
};
console.log('P002_DEDICATED_RELAY_PUBLIC_GET_READONLY_PASS',JSON.stringify(publicReport));

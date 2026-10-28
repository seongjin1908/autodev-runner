import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {openDb} from '../../hub/partner-hub/src/database.mjs';
import {makeEngine} from '../../hub/partner-hub/src/engine.mjs';
import {makeReferral,mac,verifyMerchant} from '../../hub/partner-hub/src/security.mjs';
import {sajuP002OriginalOrderEvent,sajuP002VerifiedPayAppCapture}
  from '../../saju/affiliate/saju-p002-payapp-bridge.mjs';
import {enqueueSajuP002HubEvent,flushSajuP002HubOutbox}
  from '../../saju/affiliate/saju-p002-durable-outbox.mjs';

function durableDb(){
  const tables=new Map();
  const m=n=>{if(!tables.has(n))tables.set(n,new Map());return tables.get(n)};
  return {
    get:async(n,ids)=>ids.map(id=>m(n).get(id)?structuredClone(m(n).get(id)):null),
    tx:{
      add:async(n,items)=>items.map(item=>{
        if(m(n).has(item.id))return null;
        m(n).set(item.id,structuredClone(item));return item.id;
      }),
      update:async(n,changes,{patch=false}={})=>changes.map(item=>{
        const x=m(n).get(item.id);
        if(!x||Object.entries(item.if||{}).some(([k,v])=>x[k]!==v))return false;
        m(n).set(item.id,structuredClone(patch?{...x,...item.record}:item.record));
        return true;
      }),
    },
    list:async(n,{limit=100,nextToken}={})=>{
      const all=[...m(n).values()],offset=nextToken?Number(nextToken):0;
      return {items:structuredClone(all.slice(offset,offset+limit)),
        nextToken:offset+limit<all.length?String(offset+limit):undefined};
    },
    update:async()=>{throw Error('legacy db.update must not be used for compare-and-swap');},
    rows:()=>[...m('coston_saju_p002_outbox').values()],
  };
}
const secret='s'.repeat(64),cfg={authSecret:'a'.repeat(64),
  referralSecret:'b'.repeat(64),buyerSecret:'c'.repeat(64),
  bankKey:'d'.repeat(64),ownerEmail:'owner@example.test',
  merchantKeys:{saju:secret},partnerTermsApproved:true,
  referralLaunchApproved:true,referralApps:['saju'],
  production:false,allowManualPayout:false};
const hubDb=openDb(),outboxDb=durableDb(),mail=new Map();
const hub=makeEngine(hubDb,cfg,{sendEmail:async(e,code)=>mail.set(e,code)});
const orderId='saju-durable-synthetic-1',uuid='32039ab7-19a2-456d-a8b1-28164997cf2c';
const request='112233445566',date='20261028123456';
const sha=s=>createHash('sha256').update(s).digest('hex');
try{
  await hub.loginRequest('partner@example.test');
  const logged=hub.loginVerify('partner@example.test',mail.get('partner@example.test'));
  const partner=hub.join(logged.token,logged.csrf,{
    name:'Synthetic single-tier partner',termsAccepted:true});
  const token=makeReferral(cfg.referralSecret,partner.id,'saju');
  const unpaid={orderUuid:uuid,product:{code:'P002',price:19900},
    attribution:{market:'KR'},status:'CREATED'};
  const paid={...unpaid,status:'PAYMENT_VERIFIED',
    payAppRequestNo:request,paymentProvider:'PAYAPP',
    paymentVerifiedAt:'2026-10-28T12:36:00.000Z',
    paymentProviderEventId:sha('PAYAPP:'+request+':'+date+':4'),
    payAppAwaitingDeposit:false};
  const relay={ok:true,orderId,registration:{orderUuid:uuid,mulNo:request,price:19900},
    latestFeedback:{merchantAuthVerified:true,payload:{
      pay_state:'4',var1:orderId,var2:uuid,mul_no:request,price:'19900',pay_date:date}}};
  const original=sajuP002OriginalOrderEvent({orderId,order:unpaid,referralToken:token});
  const capture=sajuP002VerifiedPayAppCapture({orderId,order:paid,relayState:relay});
  const now={value:1793189000000},calls=[];
  const sender=async(_url,req)=>{
    verifyMerchant(secret,req.headers['x-coston-timestamp'],req.body,
      req.headers['x-coston-signature'],Math.floor(now.value/1000));
    const event=JSON.parse(req.body),result=hub.event('saju',req.body,event);
    calls.push(result.status);
    return {ok:true,json:async()=>result};
  };
  const config={db:outboxDb,enabled:true,
    hubUrl:'https://synthetic-hub.example.test',merchantSecret:secret,
    fetcher:sender,now:()=>now.value};
  // Recover capture before its original order — must stay untransmitted.
  assert.equal((await enqueueSajuP002HubEvent(outboxDb,capture,{enabled:true,now:()=>now.value})).status,'queued');
  assert.equal((await flushSajuP002HubOutbox(config)).sent,0);
  assert.equal(calls.length,0);
  assert.equal((await enqueueSajuP002HubEvent(outboxDb,original,{enabled:true,now:()=>now.value})).status,'queued');
  const sent=await flushSajuP002HubOutbox(config);
  assert.equal(sent.sent,2);
  assert.deepEqual(calls,['order_saved','captured']);
  assert.equal(hubDb.prepare('SELECT COUNT(*) n FROM sales').get().n,1);
  assert.equal(hubDb.prepare('SELECT COUNT(*) n FROM ledger').get().n,0);
  assert.equal(outboxDb.rows().every(x=>x.state==='DELIVERED'),true);
  // Deliberately simulated evidence; not provider KYC.
  const verified={type:'BUYER_VERIFIED',eventId:'synthetic-buyer-1',orderId,
    customerHash:mac(cfg.buyerSecret,'synthetic-independent-buyer@example.test'),
    merchantEvidenceVerified:true,evidenceRef:'synthetic-independent-identity-1',
    verifiedAt:paid.paymentVerifiedAt};
  assert.equal(hub.event('saju',JSON.stringify(verified),verified).commissionRecorded,true);
  const accrual=hubDb.prepare("SELECT amount,status FROM ledger WHERE kind='ACCRUAL'").get();
  assert.equal(accrual.amount,5970);
  assert.equal(accrual.status,'PENDING');
  const refund={type:'PAYMENT_REFUNDED',eventId:'synthetic-refund-1',orderId,
    refundId:'synthetic-refund-id-1',refundMinor:19900,providerVerified:true};
  assert.equal(hub.event('saju',JSON.stringify(refund),refund).status,'refund_recorded');
  assert.deepEqual(hubDb.prepare('SELECT amount FROM ledger ORDER BY rowid').all().map(x=>x.amount),[5970,-5970]);
  assert.equal(hubDb.prepare('SELECT COUNT(*) n FROM payouts').get().n,0);
  console.log('PASS: durable DB → signed transport → Hub order/capture → no-KYC lock → synthetic buyer proof → 5970 KRW PENDING → refund reversal → no payout');
}finally{hubDb.close();}

import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {openDb} from '../../hub/partner-hub/src/database.mjs';
import {makeEngine} from '../../hub/partner-hub/src/engine.mjs';
import {makeReferral,mac,verifyMerchant} from '../../hub/partner-hub/src/security.mjs';
import {sajuP002OriginalOrderEvent,sajuP002VerifiedPayAppCapture,
  sajuP002SignedHubMessage} from '../../saju/affiliate/saju-p002-payapp-bridge.mjs';

const premium=readFileSync(new URL('../../premium/backend/index.ts',import.meta.url),'utf8');
const price=readFileSync(new URL('../../premium/shared/domestic-catalog.ts',import.meta.url),'utf8');
assert.match(premium,/async function finalizePayAppVerifiedOrder/);
assert.match(premium,/paymentProviderEventId: providerEventId/);
assert.match(premium,/merchantAuthVerified === true/);
assert.match(price,/code: 'P002', name: 'Premium 사주', price: 19900/);

const sha=s=>createHash('sha256').update(s).digest('hex');
const cfg={authSecret:'a'.repeat(64),referralSecret:'b'.repeat(64),
  buyerSecret:'c'.repeat(64),bankKey:'d'.repeat(64),
  ownerEmail:'owner@example.test',merchantKeys:{saju:'e'.repeat(64)},
  partnerTermsApproved:true,referralLaunchApproved:true,
  referralApps:['saju'],allowManualPayout:false,production:false};
const orderId='saju-stage-P002-order-1';
const requestNo='1299311001',payDate='20261028160011';
const orderUuid='2f3bdca1-f328-491f-85aa-02d774f7c822';
const paidAt=new Date().toISOString();
const original={orderUuid,product:{code:'P002',price:19900},
  attribution:{market:'KR'},status:'CREATED',payAppRequestNo:requestNo};
const paid={...original,status:'PAYMENT_VERIFIED',paymentProvider:'PAYAPP',
  paymentVerifiedAt:paidAt,paymentProviderEventId:sha('PAYAPP:'+requestNo+':'+payDate+':4'),
  payAppAwaitingDeposit:false};
const relay={ok:true,orderId,registration:{orderUuid,mulNo:requestNo,price:19900},
  latestFeedback:{merchantAuthVerified:true,payload:{pay_state:'4',
    var1:orderId,var2:orderUuid,mul_no:requestNo,price:'19900',pay_date:payDate}}};
const db=openDb(),inbox=new Map();
try{
  const hub=makeEngine(db,cfg,{sendEmail:async(email,code)=>inbox.set(email,code)});
  await hub.loginRequest('partner@example.test');
  const session=hub.loginVerify('partner@example.test',inbox.get('partner@example.test'));
  const partner=hub.join(session.token,session.csrf,{name:'Synthetic partner',termsAccepted:true});
  const token=makeReferral(cfg.referralSecret,partner.id,'saju');
  const created=sajuP002OriginalOrderEvent({orderId,order:original,referralToken:token});
  const paidEvent=sajuP002VerifiedPayAppCapture({orderId,order:paid,relayState:relay});
  const send=ev=>{
    const req=sajuP002SignedHubMessage(ev,cfg.merchantKeys.saju);
    verifyMerchant(cfg.merchantKeys.saju,req.headers['x-coston-timestamp'],
      req.body,req.headers['x-coston-signature']);
    return hub.event('saju',req.body,JSON.parse(req.body));
  };
  assert.equal(send(created).status,'order_saved');
  assert.equal(send(paidEvent).commissionRecorded,false,
    'A paid event without independently verified buyer cannot earn commission');
  assert.equal(send(paidEvent).status,'duplicate');
  assert.equal(db.prepare("SELECT COUNT(*) n FROM ledger").get().n,0);
  const verified={type:'BUYER_VERIFIED',eventId:'saju:buyer:synthetic',orderId,
    customerHash:mac(cfg.buyerSecret,'independent-synthetic-buyer@example.test'),
    merchantEvidenceVerified:true,evidenceRef:'synthetic-independent-provider-proof',
    verifiedAt:paidAt};
  assert.equal(hub.event('saju',JSON.stringify(verified),verified).commissionRecorded,true);
  const accrual=db.prepare("SELECT amount,currency,status FROM ledger WHERE kind='ACCRUAL'").get();
  assert.equal(accrual.amount,5970);
  assert.equal(accrual.currency,'KRW');
  assert.equal(accrual.status,'PENDING');
  const refund={type:'PAYMENT_REFUNDED',eventId:'saju:refund:synthetic',orderId,
    refundId:'synthetic-provider-refund-1',refundMinor:19900,providerVerified:true};
  assert.equal(hub.event('saju',JSON.stringify(refund),refund).status,'refund_recorded');
  assert.equal(hub.event('saju',JSON.stringify(refund),refund).status,'duplicate');
  const ledger=db.prepare("SELECT kind,amount FROM ledger ORDER BY rowid").all();
  assert.deepEqual(ledger.map(x=>x.amount),[5970,-5970]);
  assert.equal(db.prepare("SELECT status FROM orders").get().status,'REFUNDED');
  assert.equal(db.prepare("SELECT COUNT(*) n FROM payouts").get().n,0);
  console.log('Saju P002 synthetic end-to-end Hub contract PASS: order, paid no KYC, simulated buyer verification, 5970 KRW pending, full refund reversal, no payout');
}finally{db.close();}

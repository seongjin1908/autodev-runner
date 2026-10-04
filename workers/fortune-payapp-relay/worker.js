const APP_URL = 'https://mvp-91zb78.v2.appdeploy.ai/';
const APP_ORIGIN = new URL(APP_URL).origin;
const INGEST_URL = 'https://api-v2.appdeploy.ai/app/mvp-91zb78/api/payapp/relay-ingest';
const LEGACY_RELAY_URL = 'https://fortune-payapp-relay-production.up.railway.app';

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}

function text(body, status = 200) {
  return new Response(body, {
    status,
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}

function safeOrderId(value) {
  const orderId = String(value || '').trim();
  return /^[A-Za-z0-9_-]{8,160}$/.test(orderId) ? orderId : '';
}

async function parseBody(request) {
  const raw = await request.text();
  if (!raw) return {};
  const contentType = request.headers.get('content-type') || '';
  if (contentType.includes('application/json')) {
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return {};
    return Object.fromEntries(Object.entries(parsed).map(([key, value]) => [key, String(value ?? '')]));
  }
  return Object.fromEntries(new URLSearchParams(raw).entries());
}

function canonicalPayload(payload) {
  const allowed = [
    'userid',
    'var1',
    'var2',
    'mul_no',
    'price',
    'pay_state',
    'pay_type',
    'pay_date',
    'csturl',
    'feedbacktype',
  ];
  const selected = {};
  for (const key of allowed) selected[key] = String(payload[key] || '');
  return JSON.stringify(selected);
}

async function hmacHex(secret, message) {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const signature = new Uint8Array(await crypto.subtle.sign('HMAC', key, encoder.encode(message)));
  return Array.from(signature, byte => byte.toString(16).padStart(2, '0')).join('');
}

function base64url(value) {
  const bytes = new TextEncoder().encode(value);
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function returnHtml(orderId) {
  const fallback = new URL(APP_URL);
  fallback.searchParams.set('market', 'KR');
  fallback.searchParams.set('locale', 'ko');
  fallback.searchParams.set('surface', 'DAANGN');
  fallback.searchParams.set('payapp_return', '1');
  if (orderId) fallback.searchParams.set('order', orderId);
  const payload = { type: 'FORTUNE_PAYAPP_RETURN', orderId };
  return '<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>결제 확인</title></head><body><p style="font-family:sans-serif;padding:24px">결제가 확인되었습니다. 원래 화면으로 돌아갑니다.</p><script>(function(){var payload=' +
    JSON.stringify(payload) +
    ';var targetOrigin=' +
    JSON.stringify(APP_ORIGIN) +
    ';var fallback=' +
    JSON.stringify(fallback.toString()) +
    ';try{if(window.opener&&!window.opener.closed){window.opener.postMessage(payload,targetOrigin);setTimeout(function(){window.close();},80);setTimeout(function(){if(!window.closed)window.location.replace(fallback);},900);return;}}catch(e){}window.location.replace(fallback);}());<\\/script></body></html>';
}

async function forwardFeedback(payload) {
  const orderId = safeOrderId(payload.var1);
  const payState = String(payload.pay_state || '').trim();
  const linkval = String(payload.linkval || '');
  if (!orderId || !payState || !linkval) return false;
  if (payState === '1') return true;

  const canonical = canonicalPayload(payload);
  const sig = await hmacHex(linkval, canonical);
  const target = new URL(INGEST_URL);
  target.searchParams.set('payload', base64url(canonical));
  target.searchParams.set('sig', sig);

  const response = await fetch(target.toString(), {
    method: 'GET',
    headers: { 'Cache-Control': 'no-store' },
    redirect: 'manual',
  });
  const body = await response.text();
  return response.status === 200 && body.includes('SUCCESS');
}

export default {
  async fetch(request) {
    try {
      const url = new URL(request.url);

      if (request.method === 'GET' && url.pathname === '/health') {
        return json({ ok: true, service: 'fortune-payapp-relay-v2', mode: 'stateless' });
      }

      if (request.method === 'POST' && url.pathname === '/register') {
        const body = await parseBody(request);
        const orderId = safeOrderId(body.orderId);
        const mulNo = String(body.mulNo || '').trim();
        const price = Number(body.price);
        if (!orderId || !/^\d+$/.test(mulNo) || !Number.isInteger(price) || price <= 0) {
          return json({ ok: false, error: 'INVALID_REGISTRATION' }, 400);
        }
        return json({ ok: true, registered: true, stateless: true });
      }

      if (request.method === 'POST' && url.pathname === '/payapp/feedback') {
        const payload = await parseBody(request);
        const forwarded = await forwardFeedback(payload);
        return forwarded ? text('SUCCESS', 200) : text('FAIL', 502);
      }

      if ((request.method === 'POST' || request.method === 'GET') && url.pathname === '/payapp/return') {
        const body = request.method === 'POST' ? await parseBody(request) : {};
        const orderId = safeOrderId(body.var1 || url.searchParams.get('order'));
        return new Response(returnHtml(orderId), {
          status: 200,
          headers: {
            'Content-Type': 'text/html; charset=utf-8',
            'Cache-Control': 'no-store',
            'Referrer-Policy': 'no-referrer',
            'X-Content-Type-Options': 'nosniff',
          },
        });
      }

      if (request.method === 'POST' && url.pathname === '/state') {
        const raw = await request.text();
        try {
          const legacy = await fetch(LEGACY_RELAY_URL + '/state', {
            method: 'POST',
            headers: { 'Content-Type': request.headers.get('content-type') || 'application/json' },
            body: raw,
            redirect: 'manual',
          });
          if (legacy.status !== 404) {
            return new Response(await legacy.text(), {
              status: legacy.status,
              headers: {
                'Content-Type': legacy.headers.get('content-type') || 'application/json; charset=utf-8',
                'Cache-Control': 'no-store',
                'X-Content-Type-Options': 'nosniff',
              },
            });
          }
        } catch {
          // Legacy state is best-effort only. New payments do not depend on it.
        }
        return json({ ok: false, error: 'STATELESS_RELAY' }, 404);
      }

      if (request.method === 'POST' && url.pathname === '/ack') {
        const raw = await request.text();
        try {
          await fetch(LEGACY_RELAY_URL + '/ack', {
            method: 'POST',
            headers: { 'Content-Type': request.headers.get('content-type') || 'application/json' },
            body: raw,
          });
        } catch {
          // Ack is compatibility-only and must not block the new stateless path.
        }
        return json({ ok: true, stateless: true });
      }

      return json({ ok: false, error: 'NOT_FOUND' }, 404);
    } catch {
      return json({ ok: false, error: 'INTERNAL_ERROR' }, 500);
    }
  },
};
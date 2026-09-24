import { chromium } from 'playwright';
import fs from 'node:fs/promises';

const baseUrl = process.env.SAJU_LIVE_URL || 'https://mvp-91zb78.v2.appdeploy.ai/';
// Myeongri P0 backend smoke: existing free-result, premium checkout and mobile layout must remain stable.
const outDir = 'artifacts/saju-live-qa';
await fs.mkdir(outDir, { recursive: true });

const report = {
  baseUrl,
  startedAt: new Date().toISOString(),
  diagnostics: null,
  viewports: {},
  checkout: null,
  errors: [],
};

function hostOf(value) {
  try { return new URL(value).hostname; } catch { return ''; }
}

async function collectLayout(page, stage) {
  const metrics = await page.evaluate(() => {
    const doc = document.documentElement;
    const selectors = ['.product-header', '.hero', '.form-card', '#free-result', '#payment', '.resume-card'];
    const boxes = {};
    for (const selector of selectors) {
      const el = document.querySelector(selector);
      if (!el) continue;
      const r = el.getBoundingClientRect();
      boxes[selector] = {
        left: Math.round(r.left),
        right: Math.round(r.right),
        top: Math.round(r.top),
        bottom: Math.round(r.bottom),
        width: Math.round(r.width),
        height: Math.round(r.height),
      };
    }
    const controls = [...document.querySelectorAll('button,input,select,textarea,a')].map((el) => {
      const r = el.getBoundingClientRect();
      const style = getComputedStyle(el);
      return {
        tag: el.tagName,
        text: (el.textContent || el.getAttribute('aria-label') || '').trim().slice(0, 90),
        left: r.left,
        right: r.right,
        top: r.top,
        bottom: r.bottom,
        width: r.width,
        height: r.height,
        fontSize: parseFloat(style.fontSize || '0'),
        visible: r.width > 0 && r.height > 0 && style.visibility !== 'hidden' && style.display !== 'none',
      };
    }).filter((x) => x.visible);
    const viewportWidth = window.innerWidth;
    const clipped = controls.filter((x) => x.left < -1 || x.right > viewportWidth + 1).slice(0, 20);
    const tinyTapTargets = controls.filter((x) => ['BUTTON','A'].includes(x.tag) && x.height > 0 && x.height < 40).slice(0, 20);
    return {
      viewport: { width: window.innerWidth, height: window.innerHeight },
      document: { clientWidth: doc.clientWidth, scrollWidth: doc.scrollWidth, scrollHeight: doc.scrollHeight },
      horizontalOverflow: doc.scrollWidth > doc.clientWidth + 2,
      clipped,
      tinyTapTargets,
      boxes,
    };
  });
  if (metrics.horizontalOverflow) throw new Error(stage + ': horizontal overflow ' + JSON.stringify(metrics.document));
  if (metrics.clipped.length) throw new Error(stage + ': clipped controls ' + JSON.stringify(metrics.clipped));
  return metrics;
}

async function fillFreeFlow(page, label) {
  await page.getByLabel('이름').fill('김영희');
  await page.getByLabel('출생년도').fill('1970');
  await page.getByLabel('출생월').fill('8');
  await page.getByLabel('출생일').fill('15');
  await page.getByLabel('출생시간').selectOption('10');
  await page.getByLabel('출생분').selectOption('30');
  const consent = page.getByLabel('개인정보 수집 동의');
  if (!(await consent.isChecked())) await consent.check();
  await page.getByRole('button', { name: /무료로 결과 보기/ }).click();
  await page.locator('#free-result').waitFor({ state: 'visible', timeout: 30000 });

  const freeText = await page.locator('#free-result').innerText();
  for (const expected of [
    '김영희 님 사주에서 지금 가장 중요한 흐름',
    '당신의 사주를 한 문장으로 보면',
    '가장 중요한 3가지',
    '지금 가장 주목할 흐름',
    '돈·재물',
    '사업',
    '연애',
    '지금 가장 궁금한 것은 무엇인가요?',
    '내 상세 흐름 확인하기',
    '5,900원부터 · 1회 결제',
  ]) {
    if (!freeText.includes(expected)) throw new Error(label + ': consumer free result missing ' + expected);
  }

  for (const banned of ['CURRENT FLOW', '시기 계산값 보기']) {
    if (freeText.includes(banned)) throw new Error(label + ': technical copy leaked: ' + banned);
  }

  const expertTerms = ['원국', '월령', '통근', '투간', 'DRAINING', 'SUPPORTIVE'];
  const visibleMainCopy = await page.locator('#free-result').evaluate((root) => {
    const clone = root.cloneNode(true);
    clone.querySelectorAll('details, .product-choice-panel').forEach((node) => node.remove());
    return clone.innerText;
  });
  for (const term of expertTerms) {
    if (visibleMainCopy.includes(term)) throw new Error(label + ': expert term visible before evidence: ' + term);
  }

  if (await page.locator('.product-card').count()) throw new Error(label + ': product comparison visible before primary CTA');

  const surprise = page.locator('.surprise-card');
  if (await surprise.count()) {
    const surpriseText = await surprise.innerText();
    if (!surpriseText.includes('왜 이렇게 나왔나요?')) throw new Error(label + ': surprise hook missing evidence accordion');
  }

  const interestButton = page.getByRole('button', { name: '사업', exact: true });
  if (await interestButton.count()) {
    await interestButton.click();
    const selectedText = await page.locator('.selected-interest-preview').innerText();
    if (!selectedText.includes('사업에서 지금 가장 중요한 질문')) throw new Error(label + ': business interest copy did not update');
    if (!new URL(page.url()).searchParams.get('focus')?.includes('business')) throw new Error(label + ': selected interest not preserved in URL');
  }

  const primaryCta = page.locator('.result-primary-cta');
  if (await primaryCta.count() !== 1) throw new Error(label + ': free result must show exactly one primary checkout gate');
  await primaryCta.click();
  await page.locator('.product-choice-panel').waitFor({ state: 'visible', timeout: 10000 });
  if (await page.locator('.product-card').count() < 2) throw new Error(label + ': Standard/Premium comparison missing after primary CTA');
  const productChoiceText = await page.locator('.product-choice-panel').innerText();
  for (const expected of ['STANDARD', '5,900원', 'PREMIUM', '9,900원', '사업 관심 기준 추천']) {
    if (!productChoiceText.includes(expected)) throw new Error(label + ': product choice missing ' + expected);
  }
  return freeText;
}

async function choosePremium(page, label) {
  const premium = page.locator('.product-card').filter({ hasText: '9,900원' });
  await premium.waitFor({ state: 'visible', timeout: 15000 });
  await premium.getByRole('button').click();
  await page.locator('#payment').waitFor({ state: 'visible', timeout: 20000 });
  const paymentText = await page.locator('#payment').innerText();
  if (!paymentText.includes('9,900원')) throw new Error(label + ': Premium price missing');
  if (!paymentText.includes('Toss Payments') || !paymentText.includes('자동구독 없음')) throw new Error(label + ': payment trust copy missing');
  await page.getByLabel('알림 이메일').fill('qa@example.com');
  return paymentText;
}

async function openTossCheckout(page, context) {
  const beforePages = context.pages().length;
  const button = page.getByRole('button', { name: /Toss Payments로 결제하기/ });
  if (!(await button.isEnabled())) throw new Error('checkout button disabled before request');
  await button.click();

  const deadline = Date.now() + 20000;
  let evidence = null;
  while (Date.now() < deadline) {
    const pages = context.pages();
    const pageUrls = pages.map((p) => p.url());
    const frameUrls = page.frames().map((f) => f.url());
    const allUrls = [...pageUrls, ...frameUrls].filter(Boolean);
    const external = allUrls.find((u) => {
      const host = hostOf(u);
      return host.includes('tosspayments') || host.includes('tosspayment');
    });
    if (external) {
      evidence = { externalUrl: external, pageUrls, frameUrls, pagesBefore: beforePages, pagesAfter: pages.length };
      break;
    }
    if (page.url() !== baseUrl && hostOf(page.url()) !== hostOf(baseUrl)) {
      evidence = { externalUrl: page.url(), pageUrls, frameUrls, pagesBefore: beforePages, pagesAfter: pages.length };
      break;
    }
    await page.waitForTimeout(500);
  }

  if (!evidence) {
    const body = (await page.locator('body').innerText()).slice(0, 3000);
    throw new Error('Toss checkout did not become observable. Current URL=' + page.url() + ' BODY=' + body);
  }
  return evidence;
}

const browser = await chromium.launch({ headless: true });
try {
  // Payment diagnostic is the fastest deployed-config check.
  {
    const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    const page = await context.newPage();
    const consoleErrors = [];
    page.on('pageerror', (e) => consoleErrors.push('pageerror: ' + e.message));
    page.on('console', (m) => { if (m.type() === 'error') consoleErrors.push('console: ' + m.text()); });
    await page.goto(baseUrl + '?payment_diag=1', { waitUntil: 'networkidle', timeout: 60000 });
    const text = await page.locator('body').innerText();
    report.diagnostics = { text: text.slice(0, 2500), consoleErrors };
    for (const expected of ['READY','TEST','test_gck_','LOADED','DISABLED']) {
      if (!text.includes(expected)) throw new Error('payment diagnostic missing ' + expected + ': ' + text.slice(0, 1200));
    }
    await page.screenshot({ path: outDir + '/payment-diagnostic.png', fullPage: true });
    await context.close();
  }

  for (const spec of [
    { label: 'desktop', width: 1440, height: 1000, checkout: true },
    { label: 'mobile', width: 390, height: 844, checkout: false },
  ]) {
    const context = await browser.newContext({ viewport: { width: spec.width, height: spec.height } });
    const page = await context.newPage();
    const consoleErrors = [];
    page.on('pageerror', (e) => consoleErrors.push('pageerror: ' + e.message));
    page.on('console', (m) => {
      if (m.type() === 'error' && !/favicon/i.test(m.text())) consoleErrors.push('console: ' + m.text());
    });

    await page.goto(baseUrl, { waitUntil: 'networkidle', timeout: 60000 });
    const initial = await collectLayout(page, spec.label + ':initial');
    await page.screenshot({ path: outDir + '/' + spec.label + '-initial.png', fullPage: true });

    await fillFreeFlow(page, spec.label);
    const result = await collectLayout(page, spec.label + ':result');
    await page.screenshot({ path: outDir + '/' + spec.label + '-result.png', fullPage: true });

    await choosePremium(page, spec.label);
    const payment = await collectLayout(page, spec.label + ':payment');
    await page.screenshot({ path: outDir + '/' + spec.label + '-payment.png', fullPage: true });

    if (spec.checkout) {
      report.checkout = await openTossCheckout(page, context);
      await page.screenshot({ path: outDir + '/desktop-checkout-observed.png', fullPage: true }).catch(() => {});
    }

    report.viewports[spec.label] = { initial, result, payment, consoleErrors };
    if (consoleErrors.length) throw new Error(spec.label + ': browser errors ' + JSON.stringify(consoleErrors));
    await context.close();
  }
} catch (error) {
  report.errors.push(error instanceof Error ? error.stack || error.message : String(error));
} finally {
  report.finishedAt = new Date().toISOString();
  await fs.writeFile(outDir + '/report.json', JSON.stringify(report, null, 2));
  await browser.close();
}

console.log(JSON.stringify(report, null, 2));
if (report.errors.length) process.exit(1);

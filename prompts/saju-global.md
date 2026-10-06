# Fortune Atlas Global i18n launch lane

Goal: make the existing Fortune Atlas product launch-ready for international markets without regressing the Korea release.

## Priority order
1. English (US/GLOBAL)
2. Japanese (JP)
3. Traditional Chinese (TW)
4. Spanish (ES)
5. Brazilian Portuguese (BR)

## Hard product rule
Locale and market are separate dimensions. Never infer payment, currency, legal copy, feature availability, or seller obligations solely from language.

## Required user journey
Localize the complete customer journey, not only the landing page:
- document title/meta and landing page
- birth input form, validation, consent, loading and error states
- free result and all interpretation copy
- product comparison
- checkout and payment copy
- fulfillment/progress states
- paid Standard/Premium result
- PDF
- order recovery/re-entry
- FAQ/refund/privacy/seller-support copy

## Architecture
- Prefer a typed translation/catalog layer and reusable translation helpers over scattered locale conditionals.
- Keep deterministic Saju calculations language-neutral.
- Do not translate raw stems/branches in a way that corrupts canonical calculation identifiers.
- Consumer labels may show localized explanations while retaining canonical terms when helpful.
- Preserve locale and market in order attribution, PayPal return/cancel and result re-entry.
- Unsupported/missing copy must fail to a deliberate fallback; do not silently show mixed Korean on international pages.
- Add executable regression coverage that detects Korean leakage on non-KR public surfaces, while allowing explicitly whitelisted canonical terms.

## Product availability
- KR: existing PayApp path and current product rules remain untouched.
- International: P001 Standard and P002 Premium only unless the repository explicitly enables another tier.
- P004 Signature remains KR-only until an explicit international product decision.
- Current international USD price mapping is authoritative unless deliberately changed by a separate pricing task.

## Payment safety
- PayPal live code may be inspected and hardened, but never perform an automated real-money charge.
- Do not enable a new payment provider, alter secrets, or create external provider configuration.
- Preserve idempotency, server-side entitlement verification and safe return/re-entry behavior.

## Content quality
- Global output must preserve the v19 cross-evidence personalization rules.
- Do not translate Korean idioms literally when natural local-market language is clearer.
- Avoid unsupported certainty claims.
- Keep technical Saju evidence secondary to readable consumer explanations.
- PDF and web result must represent the same analysis snapshot.

## Batch strategy
Work in coherent vertical slices. Prefer completing English end-to-end before spreading partial translations across five locales. Once English is structurally complete, reuse the architecture for JA, ZH-TW, ES and PT-BR.

## Do not
- regress Korea UI/payment
- deploy production
- auto-merge
- spend money
- modify target GitHub workflows
- claim a locale is complete without executable leakage/coverage checks

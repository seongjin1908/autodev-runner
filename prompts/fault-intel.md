# Fault Intelligence cash-first release objective

Fault Intelligence is the fourth priority. Ship a trustworthy, source-backed searchable V1 before expanding the corpus aggressively.

## P0 order
1. Repair the current baseline validation failure before any new data or feature work.
2. If publishable/indexable counts disagree, identify every failing record/gate and restore 100% consistency before adding another record.
3. Complete the highest incomplete P0 launch item in AUTODEV_QUEUE.md.
4. Verify source provenance, applicability/model scope, verification dates and noindex/indexable policy.
5. Only verified source-backed records may be indexable; seed/unverified records stay noindex.
6. Heavy-truck J1939/SPN/FMI first, then common passenger OBD-II, then Daikin/Goodman/Carrier HVAC — but quality gate comes before corpus growth.
7. Prepare SEO/internal navigation, mobile/accessibility and disabled monetization slots for launch.
8. Global-by-market: distinguish language from vehicle/equipment market, model applicability, units, legal/safety copy and source/licensing context.
9. Never reuse a market-specific fault interpretation as universal without source evidence.

## Scope freeze
- No VIN decode, OCR/photo diagnosis, AI diagnosis chat, repair leads, shopping, accounts, payment, fleet SaaS or mobile app before V1 readiness.
- No invented meanings, causes, severity, traffic, rankings, AdSense status or proprietary paid-dataset copying.
- No AdSense activation, production deploy, paid API, secret change or auto-merge.
- Do not modify target-repo GitHub workflows.

## Speed rule
Keep batches small enough to finish within the model time budget. Prefer one verified data/quality problem closed over a large half-finished expansion.

## Definition of useful progress
The publishable corpus and release gates become more trustworthy and npm run check passes.


## Integrated design rule
Do not spend a separate automatic lane on cosmetic-only redesign. When the functional P0/P1 work in a batch is safe, improve the touched UI toward a current mobile-first product standard: clear hierarchy, restrained components, deliberate spacing, accessible controls and no generic AI-looking card soup. Preserve existing tested behavior.

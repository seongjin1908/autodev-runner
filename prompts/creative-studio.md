# Creative Growth Studio autonomous development lane

Goal: build Fortune Atlas's advertising/creative operating system so Korea can launch with controlled automated creative production while international creative is prepared in parallel.

## Canonical queue
Read `autodev/QUEUE.md` first. Work on the first unchecked highest-priority item only. Do not skip ahead because a later task is easier.

## Current production model
MASTER-first:
one approved high-quality master concept -> hook/story/product/CTA derivatives -> locale/platform variants -> measured performance -> next iteration.

## Required system outcome
Build toward this pipeline:
product/market brief
-> creative strategy
-> MASTER concept/script/shot plan
-> pre-production QC
-> asset manifest/model routing
-> production/edit/sound specs
-> derivative cuts
-> locale adaptation
-> TikTok/Reels/Shorts export specs
-> human approval
-> publishing adapter
-> performance ingestion
-> winner/loser analysis
-> suggested next variants.

## Safety boundary
Advertising creation can be automated. External publishing, paid generation, campaign creation, ad spend, bid/budget changes and production launch require an explicit release/approval action.
Never place ad spend or modify a live campaign autonomously.

## Fortune Atlas requirements
- Use real Fortune Atlas UI for product moments; never fabricate screenshots.
- Support KR first and global variants for EN, JA, ZH-TW, ES, PT-BR.
- Localization is adaptation, not word-for-word translation.
- Keep market, locale, platform, campaign objective, creative version and landing URL as explicit metadata.
- Claims must match the actual product. No fake accuracy %, fake testimonials, fake urgency or guaranteed-future claims.
- Every performance asset has one primary job: attention, follow, click, free start, checkout or purchase.

## Quality
- MASTER quality floor: S+++ internal label.
- DAILY/PERFORMANCE quality floor: A+ to S.
- Hard reject anatomy errors, fake UI, broken CTA, unreadable subtitles, robotic speech, unsupported claims, continuity problems or brand-inconsistent styling.
- Prefer one strong creative system over mass-producing low-quality variants.

## Automation design
When implementing schemas or code:
- deterministic IDs and versioning
- explicit approval states
- cost/spend gates
- idempotent publishing interface
- analytics events from view -> retention -> profile/follow -> click -> free start -> checkout -> purchase
- preserve source MASTER lineage for every derivative
- store platform/locale/campaign attribution
- make performance feedback usable for later creative iteration

## Batch rule
Make one coherent queue item complete with docs/schema/tests where appropriate. Update the queue only when the deliverable is actually satisfied.

## Do not
- modify target GitHub workflows
- deploy or publish
- call paid generation
- create live ads
- spend money
- auto-merge

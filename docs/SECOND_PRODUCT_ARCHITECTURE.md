# SECOND — Product Architecture

## Goal
SECOND is not a "senior job board". It is a marketplace for flexible second-income opportunities where experience is an asset.

## Business model
- Consumer: free
- Employer: free posting during supply build-up
- Later B2B revenue:
  - premium listing
  - verified experienced-candidate recommendation
  - employer subscription
  - compliant success/lead fees where legally allowed
- Avoid charging users simply to browse opportunities.

## North-star metric
Meaningful matches that lead to a real conversation, project, shift, partnership or business operation.

## MVP entities
- Opportunity
- Source
- UserProfile
- CareerCard
- Bookmark
- Inquiry
- Employer
- ListingSubmission
- ModerationReview
- RiskFlag
- NotificationPreference

## Critical fields for Opportunity
- title
- category
- region
- work_mode
- expected_income_min/max
- compensation_basis
- expected_hours
- schedule
- required_experience
- vehicle_requirement
- physical_load
- upfront_cost
- mandatory_inventory
- payment_timing
- description
- source_type
- source_name
- source_url
- expires_at
- moderation_status
- risk_flags

## Matching model v1
Weighted rules, not opaque AI:
- region 25
- income target 20
- experience relevance 25
- schedule fit 15
- vehicle/physical constraint fit 10
- risk/quality modifier 5

Explain why a listing matches.

## Mobile app architecture
- PWA first
- shared React/TypeScript UI
- app-shell navigation
- service worker + manifest
- later Capacitor wrapper
- deep links reserved from start
- push notification abstraction isolated from UI

## Legal/product boundary
SECOND can provide job/opportunity information and user-driven inquiry flows. If the service actively mediates employment contracts, paid placement or regulated brokerage, compliance requirements must be reviewed before launch.

## Initial growth loop
1. Curate public/partner opportunities.
2. Publish search-indexable detail pages.
3. Let users save matching criteria.
4. Alert when a matching opportunity appears.
5. Recruit employers using demonstrated user demand.
6. Convert employers to premium matching after liquidity exists.

## Anti-embarrassment language
Use:
- 경력활동
- 프로젝트
- 파트너
- 부업
- 작은사업
- 재능활동

Avoid on core surfaces:
- 노인
- 생계형
- 취약계층
- 일자리 지원 대상
- 시니어 전용

Search/SEO pages may use direct terms like "50대 부업" and "60대 일자리" because those reflect actual search intent, while the in-product brand remains aspirational.


## UX hard rule: first value in 3 taps
The default journey is:
1. 지역 선택
2. 목표 수입 선택
3. 활동 방식 선택
4. 즉시 추천 피드

No account is required to browse. Authentication is deferred until a durable or identity-sensitive action such as cross-device saving, alerts, inquiry/apply, or listing submission.

### P0 information architecture
Bottom navigation should stay minimal:
- 홈
- 탐색
- 저장
- 내 활동

Advanced filters live behind one secondary control. The product must not resemble a dense public-job portal.

## Source aggregation architecture
SECOND uses a provider-adapter architecture rather than hard-coding one recruitment source.

### Components
- SourceRegistry: provider metadata, legal/robots review, refresh policy, health
- Fetcher/Adapter: API, RSS, allowed public HTML, manual or partner feed
- Normalizer: maps provider fields to Opportunity
- Deduplicator: canonical fingerprint + source priority
- Freshness engine: detects expiry and stale records
- Risk/quality classifier: missing pay, upfront cost, vague work, suspicious claims
- Coverage monitor: source health by region
- Source provenance UI: every imported listing shows provider and original link

### Initial provider plan
1. Work24 adapter
2. Seoul 50+ adapter
3. JobAlio adapter
4. NaraIlteo/public-sector adapter
5. Jeju official-source pack:
   - 제주특별자치도
   - 제주시
   - 서귀포시
   - 제주 농업기술원/센터
   - 제주 산하기관/재단/시설기관
6. Generic local-government board adapter framework for nationwide expansion
7. Direct employer/partner feed

### Source-selection policy
Prefer official APIs/feeds over HTML parsing. Use public HTML adapters only where permitted and necessary. Never bypass technical or contractual access restrictions. Commercial job-board ingestion requires an approved API/feed/partnership or explicit permission.

### Normalized source fields
Every imported record keeps:
- canonical opportunity id
- provider/source id
- original URL
- original posting id if available
- first_seen_at / last_seen_at
- posted_at / expires_at
- source freshness
- region hierarchy
- compensation data and confidence
- schedule/hours and confidence
- source type and trust level

This allows one user-facing card even when the same public job appears on multiple official sites.

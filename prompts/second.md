# SECOND AutoDev — Product & Engineering Prompt

## Mission
Build SECOND as a mobile-first second-career opportunity marketplace for experienced adults who want flexible income without being framed as "senior job seekers".

## Product positioning
- Never lead with "노인", "시니어", "재취업 실패".
- Lead with: 경력, 부업, 프로젝트, 지역파트너, 작은사업, 재능활동.
- Core promise: "하루 종일 일하지 않아도 내 경력은 계속 돈이 됩니다."
- Users are free. Monetization comes primarily from employers/partners through premium exposure, verified matching, and later success-based fees where legally allowed.

## Primary user jobs
1. Discover flexible opportunities by income target, time, region, experience, vehicle/physical constraints.
2. Save opportunities and receive alerts for matching new opportunities.
3. Apply/contact without rebuilding a traditional resume.
4. Build a compact "경력 카드" instead of a job-seeker resume.
5. Report suspicious listings and see risk signals.
6. Employers can post opportunities, manage status, and review applicants/leads.
7. Admin can review listings before publication.

## Opportunity taxonomy
- 알바
- 부업
- 프로젝트
- 경력활동
- 지역파트너
- 작은사업
- 재능활동

## Must-have product capabilities
### Consumer
- Mobile-first home feed
- Search/filter
- Personalized matching score
- Save/bookmark
- Recent views
- Career card
- Simple inquiry/apply flow
- Notification preferences
- Scam/risk signals
- Clear distinction between external sourced listings and direct listings

### Employer
- Listing creation
- Draft/pending/published/closed states
- Transparent pay/settlement fields
- Required fields: actual work, expected effort, compensation, payment timing, upfront cost, inventory purchase obligation
- Applicant/lead inbox

### Admin
- Review queue
- Risk flags
- Source provenance
- Duplicate detection
- Suspend/close listing
- Basic audit trail

## Data ingestion
- First-party direct listings are primary.
- Work24 Open API integration should be optional and secret-backed.
- Never fabricate live listings.
- Imported listings must preserve source URL/provider and clearly label external source.
- Normalize title, region, employment type, compensation, hours, source and expiry.

## Mobile app strategy
Phase 1: Installable PWA with app shell, bottom nav, manifest, offline-safe shell.
Phase 2: Capacitor wrapper for Android/iOS using the same web codebase where practical.
Phase 3: Native-only capabilities only if proven necessary: push, deep links, share target, biometric login.

## UX
- Large readable typography without "senior UI" stigma.
- Calm premium visual language.
- Bottom tabs: 홈 / 탐색 / 저장 / 내 활동 / 더보기.
- Avoid dense government-job-board visual patterns.
- Prefer card-based task/opportunity summaries:
  - expected income
  - time
  - location
  - experience fit
  - vehicle need
  - physical load
  - upfront cost
  - risk badge

## Guardrails
- Do not market guaranteed income.
- Flag upfront fees, mandatory inventory, vague compensation, MLM-like recruiting, unrealistic earnings.
- Licensed professions and regulated brokerage/placement activities must be separated and reviewed.
- Do not expose private contact info before the intended user action.
- No paid production deployment or automatic merge from AutoDev.
- Keep API keys only in encrypted secrets.

## Release order
P0
- App shell + mobile bottom navigation
- Opportunity feed/search/filter
- Matching profile
- Save/bookmark
- Direct listing submission + moderation state
- Source/risk labels
- PWA installability
- Tests and build green

P1
- Career card
- Employer dashboard
- Apply/inquiry flow
- Admin review
- Alerts/preferences
- Work24 adapter with mocked/off state when key absent

P2
- Notifications
- Recommendation ranking
- Duplicate/fraud heuristics
- Analytics
- SEO landing pages
- Capacitor Android build preparation

## Validation
Every batch must run:
- JSON parse for tests/tests.json when present
- TypeScript noEmit
- production build
- any project-specific tests

Prioritize broken critical flows over new features. Work in coherent batches. Do not change deployment workflows, secrets, or production payment settings.


## Non-negotiable simplicity — "3 taps to value"
SECOND must be easier than a normal job board. If a new user needs a tutorial, long signup, resume upload, or multi-page form before seeing value, the flow is wrong.

### Guest-first onboarding
The first useful result must be reachable without account creation.
Ask only three high-signal questions:
1. 어디에서 하고 싶어요? — current region / other region / nationwide
2. 월 얼마 정도 더 벌고 싶어요? — 50 / 100 / 200 / 300만원+
3. 어떤 방식이 좋아요? — 가볍게 / 경력활용 / 프로젝트 / 작은사업

Then immediately show: "오늘 나에게 맞는 기회 N개".
Do not ask age, education, full work history, certifications, detailed resume, family status, or identity verification before first results unless a specific listing legally requires it.

### Progressive disclosure
- Browse anonymously.
- Ask for login/verification only when the user saves across devices, applies/inquires, posts a listing, or enables alerts.
- Hide advanced filters under "더 자세히 찾기".
- One primary action per screen.
- No more than 4 bottom navigation items during P0.
- Every opportunity card must answer, without opening detail: what is it, where, roughly how much, how much time, why it fits, and whether money is required upfront.
- Replace jargon with plain Korean. A user should understand each screen in under 5 seconds.
- Preserve dignity: large readable UI, but never visually label the user as elderly.

## Nationwide source coverage — not Work24-only
SECOND must behave as a source aggregation and normalization layer, not as a thin Work24 skin.

### Source registry
Maintain a versioned source registry with:
- source_id
- provider_name
- source_type
- region
- official/partner status
- acquisition_method: api / rss / public_html / manual / partner_feed
- source_url
- allowed_refresh_interval
- terms_or_robots_reviewed_at
- last_success_at
- last_item_seen_at
- health_status
- parser_version

### Priority source families
Tier A — official structured feeds/APIs
- 고용24 Open API
- 서울시50플러스 OPEN API/CSV and equivalent regional middle-aged employment programs when available
- other central/local government open-data feeds that explicitly allow reuse

Tier B — official public-sector recruitment portals
- 잡알리오 public-institution recruitment
- 나라일터 central/local public-sector recruitment
- 지방공기업/지방출자·출연기관 recruitment sources
- public hospitals, universities, foundations, facilities corporations and other public institutions

Tier C — local-government and affiliated websites
For every supported region, maintain adapters/watchers for:
- 광역시·도청
- 시청·군청·구청
- 읍면동/사업소 where recruitment is posted separately
- 농업기술원/농업기술센터
- 보건소
- 복지관/50+센터/중장년지원센터
- 문화·체육·관광·시설관리 기관
- 지역 일자리센터
- 산하기관 and local foundations
Start with 제주특별자치도, 제주시, 서귀포시 and 제주 산하기관 as the first coverage-quality benchmark.

Tier D — first-party and partner supply
- employers posting directly to SECOND
- chambers, associations, cooperatives, dealer networks, franchise/agency recruitment partners
- local projects and short-term tasks

### Commercial job boards
Do not scrape commercial sites such as major private job boards without an allowed API, feed, partnership, or explicit permission. Where appropriate, link users to the original source rather than copying restricted content.

### Public HTML ingestion rules
When an official site has no API/feed:
- respect robots.txt, terms, rate limits and server load
- fetch only public pages needed for recruitment discovery
- store normalized facts and source URL, not unnecessary copied page bodies
- preserve original provider and direct source link
- detect expiry/closure
- deduplicate against the same listing syndicated elsewhere
- alert internally when parser health drops
- never bypass login, CAPTCHA, paywall, access controls or anti-bot protections

### Coverage quality
The system must expose source health metrics:
- active source count by region
- last successful refresh
- freshness lag
- parser failure count
- duplicate rate
- expired listing rate
- % of listings with compensation/time/location parsed
Do not claim "전국 전체 공고" unless measured coverage supports the claim. Prefer "여러 공식 채용처를 한곳에서 확인" until coverage is proven.

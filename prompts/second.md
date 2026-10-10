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

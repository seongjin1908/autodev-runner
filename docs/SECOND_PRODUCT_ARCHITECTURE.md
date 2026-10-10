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

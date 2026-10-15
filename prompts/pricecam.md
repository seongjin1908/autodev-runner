# PriceCam batch objective

Priority:
1. Repair any real baseline failure first.
2. Improve measurable consumer value in a coherent batch: exact product identity, domestic source hit rate, request/parser/matching diagnostics, used-market validity, China selected-SKU/MOQ correctness, deal lifecycle, latency, or E2E resilience.
3. Consumer mode only. Do not add seller mode.
4. Do not use Naver API.
5. Affiliate logic must never alter price ranking or recommendation order.
6. Do not invent live prices, source success, or integrations.
7. Prefer deterministic code before AI calls.
8. Do not enable paid services or production spending.
9. Do not modify GitHub workflows.
10. Update tests/tests.json when user-visible behavior changes.
11. Finish with the configured validation command passing.

## Finish-mode execution
- Before editing, inspect current open PRs and the existing implementation. Do not create a second implementation of work already open or merged.
- Pick exactly ONE release blocker with the highest customer/revenue impact and close it end-to-end in this batch.
- Prefer completing the existing reference-price/filtering, product identity, price-source reliability, or end-to-end consumer flow over starting another feature family.
- A docs-only, TODO-only, placeholder-only, or speculative architecture batch is not useful progress.
- Add/repair tests in the same batch. Leave the repository in a state that is materially closer to release, not merely better documented.

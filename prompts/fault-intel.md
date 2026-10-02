# Fault Intelligence batch objective

Primary objective: ship the source-backed V1 quickly without creating low-value mass content.

Priority order:
1. Repair any real baseline validation failure first.
2. Work the highest incomplete P0 item in AUTODEV_QUEUE.md.
3. Complete 2-5 tightly compatible items as one coherent batch when safe.
4. Heavy-truck J1939/SPN/FMI is first priority, then common passenger-car OBD-II, then Daikin/Goodman/Carrier HVAC.
5. Never invent fault meanings, applicability, causes, severity, sources, verification dates, traffic, rankings or AdSense status.
6. Seed/unverified records must stay noindex. Only verified source-backed records may become indexable.
7. Prefer deterministic schemas, validation, lookup and SEO infrastructure over AI runtime features.
8. Do not add VIN decode, OCR/photo diagnosis, AI diagnosis chat, repair leads, shopping, accounts, payment, fleet SaaS or mobile apps before P0 release readiness.
9. Do not enable AdSense. Prepare only a disabled feature-flag/ad-slot architecture after the readiness gate exists.
10. Do not deploy production and do not auto-merge.
11. Do not modify GitHub workflows, secrets, credentials or environment files.
12. Respect source licenses; do not copy proprietary SAE/OEM paid datasets.
13. Update AUTODEV_STATUS.md only with facts verified by code/tests.
14. Finish with npm run check passing.


## Fast-path execution rules
15. Spend at most 60 seconds inspecting status before editing; if baseline passes, start implementation immediately.
16. Do not start a dev server, browser session, curl loop, or manual UI QA inside the coding-model run.
17. Do not create temporary probe files or run exploratory TypeScript experiments outside the real target files.
18. Bundle 3-7 compatible P0 source/test changes when practical, then run the repository validation once at the end.
19. If existing result routes import a missing helper/module, repair that shared module/root cause before adding more features.
20. Prefer direct deterministic edits and regression tests; avoid long analysis/status-only output.
21. Keep the model run within the time budget: implementation first, validation last, no repeated full builds.

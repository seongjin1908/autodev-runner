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

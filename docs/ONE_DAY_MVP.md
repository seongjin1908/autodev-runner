# Zero-Cost One-Day MVP Starter

Optional starter for **new** ideas. It never touches existing product source or calls paid cloud, models, databases, payments or hosting.

## Start (Python 3.10+)

```bash
python3 scripts/scaffold_zero_cost_mvp.py --name "My MVP" --destination /tmp/my-mvp
```

Open `/tmp/my-mvp/index.html` in a browser. The output is a working single-user checklist with add, complete, delete and local persistence. It has no package installation or network dependency.

## Hard boundaries

- This is a local browser **prototype**, NOT a production SaaS.
- No authentication, shared database, cloud synchronization, real payment, real orders, or public hosting.
- Do not enter private customer information, API keys, payments, or personal identifiers.
- Generating a starter never rewrites an existing folder or any existing product.
- Keep existing Saju, WORKLINK, SECOND and PriceCam development on their validated repositories.

## One-day workflow (target, not a production guarantee)

1. Select one customer problem and one acceptance test.
2. Generate a prototype using this starter or a license-reviewed reusable template.
3. Implement exactly one functional user journey with synthetic data.
4. Test navigation, keyboard accessibility, error behavior and repeatable demo.
5. Create reviewable code and a PR; evaluate authentication, authorization, payment, privacy and hosting separately before commercial release.

Public standard GitHub-hosted Actions currently have free use according to GitHub policy, but private repositories, larger runners and cache limits can introduce charges. Do not enable billing, paid AI fallbacks or production deployment without authorization.

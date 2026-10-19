# Optional Gemini CLI free-tier fallback

Status: disabled by default. This is an **independent** optional coding path after
OpenCode's reviewed free-model pool fails to produce a validated code batch.

## Cost and data-privacy safeguards

- DO NOT enable on a Google AI Studio project with billing or paid tier enabled.
- Use only a Gemini API key from an **unbilled, free-tier-only** AI Studio project.
- Confirm Gemini 2.5 Flash is currently free for that project in the Google AI Studio pricing/usage dashboard. Google can revise models, quotas and policies.
- Google states that free-tier Gemini API content may be used to improve its products. Do not enable for confidential source or personal/customer data until that is acceptable. Keep credentials and actual customer data out of prompts.
- This runner cannot independently verify Google project billing; it is **not** a guarantee of zero cost. Enabling requires a human verification.
- No Google Cloud Vertex AI project, pay-as-you-go, Google Cloud billing, auto-recharge, or paid API is enabled or configured by this PR.

## Explicit opt-in in GitHub

Repository: seongjin1908/autodev-runner

1. In Google AI Studio, create a free-tier-only API project/key and verify billing is disabled and available free usage. Do not paste the API key into chat, files or Issues.
2. In GitHub Settings > Secrets and variables > Actions > Secrets, create repository secret AUTODEV_GEMINI_FREE_API_KEY.
3. Only after verification, add Actions repository variable AUTODEV_GEMINI_FREE_ENABLED with value true. Default is absent/false, causing zero Gemini requests.
4. To disable, set that variable to false or remove the secret. No code change is required.

## Runtime rules

- Existing OpenCode pool stays primary. Gemini CLI runs in a **separate job step**, so its secret is not provided to the OpenCode worker, npm bootstrap, or baseline validation steps.
- Gemini CLI requires GEMINI_API_KEY in headless mode. Only gemini-2.5-flash (default) and gemini-2.5-flash-lite are allowed through this bridge.
- One 180-second headless invocation per failed OpenCode batch. No blanket YOLO mode, no extensions, and no automatic shell approval; restrict tool set to source file reading/editing in clean HOME.
- Do not call Gemini when the target is held, repository token missing, or a valid OpenCode code batch was already produced.
- Any candidate must make actual application-code edits. Reject credentials/workflows, generated files, invalid diffs, too many changed files, or a failing existing project validation.
- The Gemini key is removed before dependency installation and project tests. Its output and private target code are not published in public logs.
- Code is committed only after tests pass, then the existing protected push creates a **review PR**; never auto-merge or deploy.
- Missing/blocked quota, auth, installation, source validation, or absent key => no accepted batch and the normal production gate reports failure rather than fake success.

## Official docs

- CLI noninteractive auth: https://geminicli.com/docs/get-started/authentication/
- CLI automation: https://geminicli.com/docs/cli/tutorials/automation/
- Gemini API free vs paid: https://ai.google.dev/gemini-api/docs/pricing

## Definition of done

CI of this PR checks gating, tests and syntax. True model failover is only proved
after the account owner explicitly opts in with a verified free-only API key
and one real Actions run produces a validated source PR without billing.

## Verified operational diagnosis — October 2026

- GitHub Actions run `39340783760` invoked Gemini after all free OpenCode attempts failed; Gemini exited `55` before any edits. This matches Gemini CLI's documented headless `FatalUntrustedWorkspaceError` behavior, but the previous private log was not exposed and cannot by itself conclusively prove the exact error.
- The worker now explicitly sets `--skip-trust` **only after verifying** the checked-out target has no `.gemini` project settings/hooks/extensions, `.mcp.json`, `.env`, or controller-local `.gemini` override. If any are present, the worker refuses the Gemini model call instead of trusting the config.
- The worker maintains a clean HOME with an explicit file-edit tool allowlist, disables hooks and YOLO mode, disallows extensions and shell-tool usage, and retains the validation/rollback/code-change gates.
- Classification uses `scripts/gemini_failure.py` to print only fixed labels (such as `workspace_untrusted`, `authorization_failed`, `quota_limited`, `configuration_failure`) and the CLI exit code. Never show raw model output or private files in public Actions logs.
- **Do not treat any successfully completed fallback step as successful software development** unless the protected production gate finds a tested and committed source batch and the PR is pushed.
- If Gemini still exits with a different error, use the fixed label to correct that specific issue; do not enable paid APIs, weaken the safety guard, or rerun high-frequency probes.

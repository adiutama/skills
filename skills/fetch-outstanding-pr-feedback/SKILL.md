---
name: fetch-outstanding-pr-feedback
description: Fetch unresolved review threads and pending change requests for a GitHub PR. Use when the user asks for outstanding PR feedback.
compatibility: Requires gh CLI authenticated to GitHub, and jq.
metadata:
  argument-hint: "<PR URL or PR Number>"
allowed-tools: Bash(gh:*) Read
---

Invoked as `/fetch-outstanding-pr-feedback <PR URL or PR Number>`. If missing, ask for it.

## Step 1 — Fetch, filter, save

Resolve `SKILL_DIR` (directory containing this `SKILL.md`).

Derive `OWNER`, `REPO`, `NUMBER` from input:
- URL `https://github.com/OWNER/REPO/pull/NUMBER` -> parse directly.
- Bare number -> run `gh repo view --json nameWithOwner -q .nameWithOwner` for `OWNER/REPO`.

Run:

```bash
OUTFILE="${TMPDIR:-/tmp}/fetch-outstanding-pr-feedback-<OWNER>-<REPO>-<NUMBER>.json"
bash <SKILL_DIR>/scripts/fetch.sh <PR_URL_OR_NUMBER> | bash <SKILL_DIR>/scripts/filter.sh | tee "$OUTFILE"
```

After completion, report the saved path (`$OUTFILE`) to the user.

## Step 2 — Classify and present

Assign severity and finding IDs, then format output per `<SKILL_DIR>/references/output.md`.

## Notes

- If `gh` or `jq` is missing, offer install steps for their platform and ask before running them.
- If `gh` auth fails, offer `gh auth login`.
- If unresolved count is zero, confirm the PR is merge-ready.

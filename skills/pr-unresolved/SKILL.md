---
name: pr-unresolved
description: Fetch all unresolved review threads and pending change requests from a GitHub PR link. Use when the user wants a list of unresolved PR feedback, open review comments, or outstanding review threads to address.
compatibility: Requires gh CLI authenticated to GitHub, and jq.
metadata:
  argument-hint: "<PR URL or PR Number>"
allowed-tools: Bash(gh:*) Read
---

Invoked as `/pr-unresolved <PR URL or PR Number>`. If missing, ask the user for it before proceeding.

## Step 1 — Fetch, filter, and save

Resolve the path to this skill's directory (the directory containing this SKILL.md).

Derive `OWNER`, `REPO`, and `NUMBER` from the PR argument:
- URL `https://github.com/OWNER/REPO/pull/NUMBER` → parse directly
- Bare number → run `gh repo view --json nameWithOwner -q .nameWithOwner` to get `OWNER/REPO`

Then run:

```bash
OUTFILE="${TMPDIR:-/tmp}/pr-unresolved-<OWNER>-<REPO>-<NUMBER>.json"
bash <SKILL_DIR>/scripts/fetch.sh <PR_URL_OR_NUMBER> | bash <SKILL_DIR>/scripts/filter.sh | tee "$OUTFILE"
```

Tell the user the saved path (`$OUTFILE`) after the command completes.

## Step 2 — Classify and present

Assign severity, finding IDs, and format the output per `<SKILL_DIR>/references/output.md`.

## Notes

- Missing `gh` or `jq` → offer to install for their platform, ask before running.
- `gh` auth failure → offer `gh auth login`.
- Zero unresolved items → confirm PR is ready to merge.

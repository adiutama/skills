---
name: pr-review
description: Review a GitHub PR and save a persistent session file under reviews/. Use when evaluating a PR before merge. Does not post anything; use /pr-post to publish findings.
compatibility: Requires gh CLI authenticated to GitHub, and jq.
metadata:
  argument-hint: "<PR URL or PR Number>"
allowed-tools: Bash(gh:*) Read Write
---

Invoke as `/pr-review <PR URL or PR Number>`. If missing or unparseable, ask once and stop.

## Step 1 - Initialize

Resolve `SKILL_DIR`, then run:

```bash
bash <SKILL_DIR>/scripts/start-session.sh <PR_URL_OR_NUMBER>
```

Fields: `owner repo number title branch head_sha base body diff_file comments_file session_path pass`.

## Step 2 - Load context (parallel)

- `diff_file` from Step 1: read, then `rm -f <diff_file>`.
- `<SKILL_DIR>/references/checklist.md`
- `<SKILL_DIR>/references/format.md`
- Pass `02+`: previous session file (`<NN-1>.md` beside `session_path`).
- Repo root: `AGENTS.md` or `CLAUDE.md`; read `README.md` only if neither exists.
- Docs under `docs/` matching areas touched by the diff.
- `comments_file` from Step 1: read, then `rm -f <comments_file>`.

## Step 3 - Write the review

Follow `checklist.md` for review scope and `format.md` for template, finding format, and rules. Save to `session_path`.

**Deduplication:** Cross-check each finding against `comments_file` before writing. A finding is duplicate if an existing inline comment is on the same file within +/-5 lines and covers the same issue (semantic match). Mark duplicates as `Posted: ✅ dup`; keep them in the session file, but exclude them from counts and stance. See `format.md` for details.

## Step 4 - Print summary

Follow the summary format in `format.md`, then stop.

If `<SKILL_DIR>/../pr-review-post/SKILL.md` exists, tell the user they can run `/pr-review-post` to publish findings; otherwise omit this line.

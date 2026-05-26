---
name: pr-review
description: Review a GitHub PR and save a persistent session file under reviews/. Use when reviewing a pull request, evaluating code changes, or checking a PR before merging. Does not post anything - use /pr-post to publish findings.
compatibility: Requires gh CLI authenticated to GitHub, and jq.
metadata:
  argument-hint: "<PR URL or PR Number>"
allowed-tools: Bash(gh:*) Read Write
---

Invoked as `/pr-review <PR URL or PR Number>`. If missing or unparseable, ask once and stop.

## Step 1 — Initialize

Resolve this skill's directory, then run:

```bash
bash <SKILL_DIR>/scripts/init.sh <PR_URL_OR_NUMBER>
```

Fields: `owner repo number title branch head_sha base body diff_file comments_file session_path pass`.

## Step 2 — Load context (in parallel)

- `diff_file` from Step 1 — read then `rm -f <diff_file>`
- `<SKILL_DIR>/references/checklist.md`
- `<SKILL_DIR>/references/format.md`
- Pass `02+`: previous session file (`<NN-1>.md` beside `session_path`)
- Repo root: `AGENTS.md` or `CLAUDE.md`; `README.md` only if neither exists
- Docs under `docs/` matching areas touched by the diff
- `comments_file` from Step 1 — read then `rm -f <comments_file>`

## Step 3 — Write the review

Follow `checklist.md` for what to examine and `format.md` for session file template, finding format, and rules. Save to `session_path`.

**Deduplication:** cross-check each finding against `comments_file` before writing it. A finding is a duplicate when an existing inline comment is on the same file within ±5 lines AND covers the same issue (semantic match). Mark duplicates `Posted: ✅ dup`; keep them in the session file but exclude them from counts and stance. See `format.md` for rules.

## Step 4 — Print summary

Follow `format.md` output summary format, then stop.

If `<SKILL_DIR>/../pr-review-post/SKILL.md` exists, tell the user they can run `/pr-review-post` to publish findings. Otherwise omit that line.

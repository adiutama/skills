---
name: submit-pr-review
description: Submit saved review to GitHub—paste blocks inline, approve or request-changes via gh. Resolves session artifacts on disk.
disable-model-invocation: true
compatibility: Requires gh CLI authenticated to GitHub, and jq.
metadata:
  argument-hint: "<pr-url or pr-number> [optional instructions]"
allowed-tools: Bash(gh:*) Read Write
---

Invoked as `/submit-pr-review [<pr-url or pr-number>] [optional free-text instructions]`.

*Disk held the findings; the PR deserves the voice—human opener, then **paste** blocks at the lines.*

## Step 1 — Parse

PR identity (URL or number) + optional instructions. No identity → instructions-only input.

## Step 2 — Resolve

1. `bash <SKILL_DIR>/scripts/resolve.sh <PR_IDENTITY>` → `owner`, `repo`, `number`, `head_sha`, `session_path`.
2. Else ask once for PR URL/number; stop.

Empty `session_path` → no session; stop. Else read fully. Lookup: [session-sources.md](references/session-sources.md).

## Step 3 — Submit pipeline

1. **Event** + personal message — [event.md](references/event.md).
2. Pre-submit summary — [summary.md](references/summary.md). No unposted findings → stop.
3. Review body — [body.md](references/body.md).
4. Submit:

```bash
bash <SKILL_DIR>/scripts/post.sh <OWNER> <REPO> <NUMBER> <HEAD_SHA> <EVENT> <<'EOF'
{ "body": "<composed>", "comments": [{ "path": "<file>", "line": <N>, "body": "<paste>" }] }
EOF
```

`APPROVE` without inline findings → omit `comments`.

5. Mark posted: `bash <SKILL_DIR>/scripts/mark-posted.sh <session_path> <ID1> …` — output review URL.

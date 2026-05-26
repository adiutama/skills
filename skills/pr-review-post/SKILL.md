---
name: pr-review-post
description: Post findings from a saved review session file as inline GitHub PR comments. Use after /pr-review to publish findings, submit a review, approve or request changes on a PR.
compatibility: Requires gh CLI authenticated to GitHub, and jq.
metadata:
  argument-hint: "<pr-url or pr-number> [optional instructions]"
allowed-tools: Bash(gh:*) Read Write
---

Invoked as `/pr-review-post [<pr-url or pr-number>] [optional free-text instructions]`.

## Step 1 — Parse arguments

Split the argument:
1. **PR identity** (optional) — full GitHub URL or plain number.
2. **User instructions** (optional) — remaining text; if no URL/number present, treat the whole arg as user instructions.

## Step 2 — Resolve PR and session file

Check in order, stop at the first match:

1. **Current session** — if `/pr-review` already ran, reuse its `OWNER`, `REPO`, `NUMBER`, `HEAD_SHA`, `SESSION_PATH`.
2. **Argument** — `bash <SKILL_DIR>/scripts/resolve.sh <PR_IDENTITY>` → parse JSON → `owner`, `repo`, `number`, `head_sha`, `session_path`.
3. **Ask** — ask once: "Please provide a PR URL or number." and stop.

If `session_path` is empty, tell the user no session file was found and stop. Otherwise read it in full.

## Step 3 — Determine event and personal message

Follow `<SKILL_DIR>/references/event.md`.

## Step 4 — Show pre-post summary

Follow `<SKILL_DIR>/references/summary.md`. If no unposted findings, stop here.

## Step 5 — Build the review body

Follow `<SKILL_DIR>/references/body.md`.

## Step 6 — Post the review

```bash
bash <SKILL_DIR>/scripts/post.sh <OWNER> <REPO> <NUMBER> <HEAD_SHA> <EVENT> <<'EOF'
{
  "body": "<composed body>",
  "comments": [
    { "path": "<file>", "line": <N>, "body": "<paste block>" }
  ]
}
EOF
```

Omit `comments` for `APPROVE` with no inline findings.

## Step 7 — Update the session file

```bash
bash <SKILL_DIR>/scripts/mark-posted.sh <session_path> <ID1> <ID2> ...
```

Output the review URL from step 6.

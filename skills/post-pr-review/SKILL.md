---
name: post-pr-review
description: Post findings from a saved review session as inline GitHub PR comments. Use after /review-pr to publish findings and submit an approve/request-changes review.
disable-model-invocation: true
compatibility: Requires gh CLI authenticated to GitHub, and jq.
metadata:
  argument-hint: "<pr-url or pr-number> [optional instructions]"
allowed-tools: Bash(gh:*) Read Write
---

Invoked as `/post-pr-review [<pr-url or pr-number>] [optional free-text instructions]`.

## Step 1 — Parse arguments

Split input into:
1. **PR identity** (optional): full GitHub URL or plain number.
2. **User instructions** (optional): remaining text. If no URL/number is present, treat the full input as instructions.

## Step 2 — Resolve PR and session file

Check in order and stop at first match:

1. **Current session**: if `/review-pr` already ran, reuse `OWNER`, `REPO`, `NUMBER`, `HEAD_SHA`, `SESSION_PATH`.
2. **Argument**: run `bash <SKILL_DIR>/scripts/resolve.sh <PR_IDENTITY>`, parse JSON to `owner`, `repo`, `number`, `head_sha`, `session_path`.
3. **Ask**: ask once, "Please provide a PR URL or number.", then stop.

If `session_path` is empty, report no session file found and stop. Otherwise read it fully.

## Step 3 — Determine event and personal message

Follow `<SKILL_DIR>/references/event.md`.

## Step 4 — Show pre-post summary

Follow `<SKILL_DIR>/references/summary.md`. Stop if there are no unposted findings.

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

For `APPROVE` with no inline findings, omit `comments`.

## Step 7 — Update the session file

```bash
bash <SKILL_DIR>/scripts/mark-posted.sh <session_path> <ID1> <ID2> ...
```

Output the review URL from Step 6.

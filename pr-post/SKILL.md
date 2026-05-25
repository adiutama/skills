---
name: pr-post
description: Post findings from a saved review session file as inline GitHub PR comments. Use after /pr-review to publish findings, submit a review, approve or request changes on a PR.
compatibility: Requires gh CLI authenticated to GitHub.
metadata:
  argument-hint: "<pr-url or pr-number> [optional instructions]"
allowed-tools: Bash(gh:*) Read Write
---

You are invoked as `/pr-post [<pr-url or pr-number>] [optional free-text instructions]`.

## 1. Parse arguments

Split the argument into two parts:

1. **PR identity** (optional) — a full GitHub URL (`https://github.com/owner/repo/pull/123`) or a plain number (`123`). Extract this if present.
2. **User instructions** (optional) — any remaining text after the PR identity. If the entire argument contains no URL or number, treat the whole thing as user instructions (PR identity comes from the current session).

## 2. Resolve the PR identity

Check in this order, stop at the first match:

1. **Current session** - if `/pr-review` was already run in this conversation, reuse the `OWNER`, `REPO`, `PR_NUMBER`, `HEAD_SHA`, and `SESSION_PATH` that were established then.
2. **Argument** - parse the PR identity extracted in step 1:
   - Full URL: `https://github.com/owner/repo/pull/123`
   - Short number with implicit repo: `123` (default repo: `SystemEarth/systemearth`)
3. **Ask** - if neither is available, ask once: "Please provide a PR URL or number." and stop.

## 3. Find the session file

If `SESSION_PATH` is already known from the current session, use it.

Otherwise derive it from the PR branch:
- `gh pr view <PR_NUMBER> --repo <OWNER>/<REPO> --json headRefName,headRefOid`
- Slugify `headRefName` (replace `/` and non-alphanumeric with `-`)
- Use the **highest-numbered** `NN.md` under `reviews/branches/<slug>/`

Read the session file in full.

## 4. Determine event and personal message

### Default behavior (no user instructions)

- **Event**: read the recommended stance from the session file and map it:
  - "Approve" → `APPROVE`
  - "Approve with notes" → `APPROVE`
  - "Request Changes" → `REQUEST_CHANGES`
  - "Comment" → `COMMENT`
  - If the stance is ambiguous or missing, default to `COMMENT`.
- **Personal message**: none.

### When user instructions are provided

Infer the event and an optional personal message from the free-text instructions. Examples of inference:

- "approve, great work" → event: `APPROVE`, message: "great work"
- "request changes — the naming is off" → event: `REQUEST_CHANGES`, message derived from context
- "leave as a comment, be encouraging" → event: `COMMENT`, tone guidance for body
- "lgtm" / "ship it" → event: `APPROVE`, no message
- "block this" → event: `REQUEST_CHANGES`, no message

If the instructions mention dropping specific findings (e.g. "drop N1 N2"), exclude those finding IDs from the post. Apply tone/framing guidance to the body composition in step 5.

## 5. Show summary and post

List every unposted finding (`Posted: ❌`) with a brief summary:

```
Session: reviews/branches/<slug>/<NN>.md
Recommended stance: <from session file>

Unposted findings:
  C1 - <title>  path/to/file:LINE  [critical]
  W1 - <title>  path/to/file:LINE  [warning]
  N1 - <title>  path/to/file:LINE  [nit]

Posting as: <EVENT> | Personal message: none
```

If there are no unposted findings, say so and stop.

Then proceed to post immediately — do not ask for confirmation.

## 6. Build the review body

**Transition sentence** — write a short, natural sentence bridging from the opener to the inline comments. It must convey that the findings come from an AI-assisted review and are offered as additional things to consider. Vary the phrasing each time; never use em-dashes; write like a human colleague leaving a note. Examples of the spirit (never copy verbatim):
- "Here are a few things an AI review flagged that might be worth a second look."
- "My AI reviewer surfaced some points you may want to consider before merging."
- "Ran this through an automated review so dropping the notes here for your consideration."
- "Some AI-assisted observations that could be helpful. Take what's useful."

**If a personal message was inferred from user instructions:**
```
<personal message>

<transition sentence>
```

**If no personal message:** write a dynamic 1-2 sentence opener that reflects the actual tone of the findings (e.g. encouraging for a clean diff with only nits, more direct if there are warnings). Draw on the PR title, branch name, and finding severities to make it feel specific rather than generic. Keep it conversational and avoid em-dashes. Then append the transition sentence as a new paragraph.

If the user instructions included tone guidance (e.g. "be encouraging", "be firm"), apply that to the opener and inline comment bodies where appropriate.

## 7. Post the review

Post a single batched review:

```
gh api repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/reviews \
  --method POST \
  --input - <<'EOF'
{
  "commit_id": "<HEAD_SHA>",
  "body": "<composed body from step 6>",
  "event": "<REQUEST_CHANGES|COMMENT|APPROVE>",
  "comments": [
    { "path": "<file path from repo root>", "line": <N>, "side": "RIGHT", "body": "<paste block text>" }
  ]
}
EOF
```

For `APPROVE` with no inline comments, omit the `comments` field.

## 8. Update the session file

For each successfully posted finding, update the session file:
- Change `| Posted | ❌ |` to `| Posted | ✅ |`

Output the review URL from the response `html_url`.

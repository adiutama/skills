# Notify human reviewers

After fixes are **pushed**, tell **human** reviewers what changed before refresh. Bot reviewers (`[bot]`, `coderabbitai`, `user.type == Bot`) re-check on their own — **skip notify**.

## When

- End of each address batch, after **push** succeeds (or push skipped — no local changes)
- Before **refresh** (Step 8)
- Fetch-only, unaddressed rounds, or **no human feedback** in the batch → skip entirely

## What to say

One reply per **addressed** human finding. Short, specific, colleague tone:

- @mention the reviewer when the channel has no automatic thread (reviews, issue comments)
- Reference the finding ID and location (`path:line`)
- State what changed — not a re-litigation of the original comment
- Deferrals/skips → no notify unless user asks

Example (thread reply):

```text
Addressed — moved validation into `parseInput` and added a test for the empty-string case.
```

Example (review / issue comment):

```text
@alice Addressed your review feedback:
- W1 — `auth/login.ts:42`: null guard added before token decode
- N1 — renamed `fetchData` → `loadUserData` for clarity
```

Ask once per batch if many items: show draft replies → user confirms → post.

## How to post

Read `findings_path` and match each addressed ID to its source row in `report.md` / index order:

| `reply_kind` | Post via |
|--------------|----------|
| `thread` | `bash <SKILL_DIR>/scripts/reply.sh <OWNER> <REPO> <NUMBER> <reply_to_id> <<'EOF'` … thread body … `EOF` |
| `review` | `gh pr comment <NUMBER> --repo <OWNER>/<REPO> --body "<@reviewer + summary>"` |
| `issue_comment` | `gh pr comment <NUMBER> --repo <OWNER>/<REPO> --body "<@reviewer + summary>"` |

`reply_to_id` comes from `findings.json` (`threads[].reply_to_id`, `comments[].reply_to_id`). Skip rows where `is_bot == true`.

Record `notified` in `tracker.md` Notes for each ID after a successful post.

## Completion

Notify only when human items were **addressed**. No human feedback → skip posting; go to refresh. When human items were addressed, notify (or user explicitly skips) before refresh.

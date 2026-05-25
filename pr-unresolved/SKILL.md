---
name: pr-unresolved
description: Fetch all unresolved review threads and pending change requests from a GitHub PR link. Use when the user wants a list of unresolved PR feedback, open review comments, or outstanding review threads to address.
argument-hint: "<PR URL>"
---

# PR Unresolved Feedback

Fetch all unresolved feedback from a GitHub PR and format it as structured findings ready for agent handoff.

## Step 1 — Parse the PR URL

Extract owner, repo, and PR number from the argument (e.g. `https://github.com/owner/repo/pull/123`).

If no argument was given, ask the user for the PR URL before proceeding.

## Step 2 — Fetch unresolved review threads via GraphQL (paginated)

Run the following query, then repeat with the `endCursor` value until `hasNextPage` is false. Collect all thread nodes across pages.

```bash
gh api graphql -f query='
{
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: NUMBER) {
      title
      url
      reviewThreads(first: 100, after: CURSOR) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          isResolved
          isOutdated
          path
          line
          comments(first: 50) {
            nodes {
              author { login }
              body
              url
              createdAt
            }
          }
        }
      }
    }
  }
}'
```

Replace OWNER, REPO, NUMBER with values parsed from the URL. For the first call use `null` as the CURSOR value (without quotes); for subsequent pages use the `endCursor` string from the previous response.

After collecting all pages, keep only threads where **both** `isResolved: false` AND `isOutdated: false`. This is the definition of "unresolved" — do not apply any other filter.

## Step 3 — Fetch review-level comments (all states)

```bash
gh api graphql -f query='
{
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: NUMBER) {
      reviews(first: 100) {
        nodes {
          author { login }
          body
          state
          submittedAt
          url
        }
      }
    }
  }
}'
```

Include reviews from **all states** (APPROVED, CHANGES_REQUESTED, COMMENTED). Omit only reviews with an empty body.

## Step 4 — Fetch general PR comments (non-inline)

```bash
gh api repos/OWNER/REPO/issues/NUMBER/comments --paginate
```

## Step 5 — Assign severity

For each unresolved thread and review comment, infer severity from the reviewer's language:

- **critical** — security issues, auth bypass, data loss, broken functionality
- **warning** — correctness bugs, missing error handling, truncation, UX regressions
- **nit** — accessibility, style, naming, minor cleanup

Assign finding IDs: `C1, C2…` for critical · `W1, W2…` for warning · `N1, N2…` for nit.

## Step 6 — Present the findings

Header:

```
# Unresolved feedback — <PR title>
<PR URL>
N critical · N warning · N nit
```

Then one block per finding:

```
### <ID> — <short title>

| Field    | Value                     |
|----------|---------------------------|
| Severity | critical / warning / nit  |
| Location | `path/to/file:LINE`       |
| Reviewer | @handle                   |

Brief explanation (2–3 sentences max).

**Comment:**

> exact comment excerpt (max 4 lines)

<comment URL>
```

After all findings, a compact index for agent handoff:

```
---
## Findings index

C1 — <title>  path/to/file:LINE
W1 — <title>  path/to/file:LINE
N1 — <title>  path/to/file:LINE
```

## Notes

- An unresolved thread is one where `isResolved: false` AND `isOutdated: false`. Do not skip any thread that meets this criteria.
- For threads with replies, use the last reply as the comment excerpt instead of the first.
- If `gh` is not authenticated or the repo is private without access, surface the error clearly and suggest `gh auth login`.
- If there are zero unresolved items, say so explicitly and confirm the PR looks ready to merge.

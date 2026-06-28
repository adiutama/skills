# Frame gate — conversational examples

## Good invocations (ready to frame)

- `/hmmm should we use OAuth or magic link for orgs?`
- `/hmmm where should rate limiting live — edge or Convex?`
- `/hmmm is it worth migrating to push notifications before mobile v2?`
- `/hmmm how do other teams handle multi-tenant auth in Next.js?`

## Too vague — one follow-up, then stop

| User said | Ask once |
|-----------|----------|
| `/hmmm make it better` | "Better how — faster, simpler, or more reliable?" |
| `/hmmm add auth` | "Who needs to sign in, and what can't they access?" |
| `/hmmm improve performance` | "What's slow — page load, API, or something specific you hit?" |

## Bare invoke

`/hmmm` alone → *"What's on your mind?"* — no session until they answer.

## Mirror-back (confirm)

> So you're weighing OAuth vs magic link for orgs, and we need to fit the existing Next.js setup — I'll peek at the repo and pull docs on both. Sound right?

Not:

> Problem: authentication strategy selection. Constraints: TBD. Mode: rapid.

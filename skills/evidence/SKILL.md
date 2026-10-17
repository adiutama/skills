---
name: evidence
description: Capture proof that work behaves as claimed — screenshots of web pages and HTTP requests with their responses — stamped with commit and time, secrets redacted, stored outside the repo, and packed into a paste-ready Evidence block for a PR.
disable-model-invocation: true
argument-hint: '[capture] <url | curl command | description> [--as <title>] [--from <services.md>] | list | pack'
metadata:
  version: "1.0.0"
  related: "throwaway-services, pr-review"
---

## Harness

At the start, detect your harness with [harnesses.md § Detect](references/harnesses.md#detect), then read its glossary column. These terms mean exactly what that column says, everywhere in this skill: **home** (`<home>` in paths) · **screenshot** · **invoke** (`<invoke>` in commands).

## Route

- No action, or `capture`, or anything that names a page or a request → **Capture**. `--as <title>` names the item (default: a title you derive from what it shows). `--from <services.md>` takes a throwaway-services record: its app URL, case, and Check list become the default targets, and its URLs count as disposable.
- `list` → **List**.
- `pack` → **Pack**.
- Nothing to capture named → ask what to capture, then stop.

Natural-language equivalents ("screenshot the invoice page", "show the curl for creating a vendor") count as `capture`.

Evidence for one piece of work lives in `<E>` = `<home>/<owner>-<repo>/<branch>/`, taken from the current repo and branch: lowercased, `/` → `__`, any other character outside `a-z0-9._-` → `-`. Detached HEAD → `detached-<short sha>`. `<E>/evidence.md` is the index: one entry per item, in capture order.

## Rules

- **Outside the repo.** Never write evidence into the repo, commit it, or push it. The user attaches files to the PR themselves.
- **Redact before saving.** In HTTP items, replace secrets with `‹redacted›`: `Authorization`, `Cookie`, `Set-Cookie`, API-key headers and query parameters, and body fields named like `token`, `secret`, `password`, `key`. Screenshots can't be redacted: never capture a page showing secrets or real personal data — use test accounts and seeded data, and if a secret is visible, discard the image and say so.
- **Mutating requests need a disposable target.** A request that changes state (anything but `GET`, `HEAD`, `OPTIONS`) runs without asking only against URLs from a `--from` record or ones the user called disposable in this conversation. Anything else — including other localhost ports, which may be the developer's own — show the request and ask first.
- **Stamp every item** with the commit SHA (`git rev-parse --short HEAD`, plus `+dirty` when the tree has uncommitted changes), the time, and one line saying what it proves. Ask for that line if the user didn't say.
- **Capture, don't stage.** Record what the app actually returns or shows. A failed capture (error page, 500, timeout) is still saved as what happened, and reported as such.

## Capture

Number items `NN` in capture order; `<slug>` = the title in kebab-case.

**Screenshot** (a URL, or a page described in words):

1. Open the page with **screenshot** at 1280×800. Steps before the shot ("log in as the test user, open invoice 42") are performed in the browser first; wait until the page settles (network idle, or the element the user cares about is visible).
2. Save `<E>/NN-<slug>.png` (or the format **screenshot** produces). Full page only when the user asks.
3. Look at the image. It doesn't show what the item claims to prove (wrong page, spinner, error) → say so and offer to retry.

**HTTP** (a `curl` command, or a request described in words):

1. Build the `curl` command; run it with `-sS -i --max-time 30`.
2. Save `<E>/NN-<slug>.http.md`:

   ````markdown
   ```http
   <METHOD> <path and query>
   Host: <host>
   <request headers that matter, redacted>

   <request body, pretty-printed>
   ```

   ```http
   HTTP/<v> <status> <reason>
   <response headers that matter: content-type, location, cache, redacted cookies>

   <response body, pretty-printed; over ~150 lines → first 150 and "… <n> more lines">
   ```

   Reproduce: `<the curl command, redacted>`
   ````

Then append the item to `<E>/evidence.md`:

```markdown
### NN · <title>
proves: <one line> · kind: screenshot | http · commit: <sha> · at: <time>
file: `NN-<slug>.<ext>` · source: <URL, or METHOD URL → status>
```

Report:

```markdown
**Captured NN · <title>** — <screenshot: what it shows | http: METHOD path → status>
proves: <one line> · `<E>/NN-<slug>.<ext>` · next: `<invoke> pack`
```

Show the screenshot or the response inline when your harness can display it.

## List

Print `<E>/evidence.md` as a table: NN, title, kind, proves, commit, and whether the commit is still `HEAD`. Items from an older commit are marked `stale` — the code changed since.

## Pack

Write the PR text to `<E>/pack.md`, then reply in this shape: the paste-ready text inside one fenced block (so the user copies the Markdown, not its rendering), then the files to attach.

`````markdown
## 📋 Paste into the PR  (also in `<E>/pack.md`)

````markdown
## Evidence

**<title>** — <proves> <sub>captured at `<sha>`</sub>
📎 *attach `NN-<slug>.png` here*

**<title>** — <proves> <sub>captured at `<sha>`</sub>
<details><summary><METHOD> <path> → <status></summary>

```http
<request, from the .http.md>
```

```http
<response, from the .http.md>
```

</details>
````

## 📎 Files to attach
- `<E>/NN-<slug>.png` — <title>

**Stale:** <items captured before the latest commit, or "none">
`````

Every item goes in, in capture order. Stale items are still packed but listed under **Stale** so the user can re-capture them.

# Setup, switching, and cleanup

`<S>`, `<skill>`, and `<ts>` are as in SKILL.md. `H` = `sh <skill>/scripts/harness.sh`, `DASH` = `node <skill>/scripts/dashboard.mjs`, `GUARD` = `node <skill>/scripts/guard.mjs`.

## Workspace

This applies to the checkout you were started in (the coordinator checkout). It is not `<S>/tree`, and no other worktree is affected.

**Keep** → change nothing. Tests run in `<S>/tree`.

**Reset** → before asking for approval, show exactly what happens:

| Step | Command | What is lost |
|---|---|---|
| 1 | `git fetch origin <default>` | nothing |
| 2 | `git switch --discard-changes <default>` (skip when already on it) | staged and unstaged edits to the files listed |
| 3 | `git reset --hard origin/<default>` | local commits on `<default>` not on origin: list them (`git log origin/<default>..<default>`), and refuse unless the user names them as disposable |
| 4 | `git clean -fd` (never `-x`) | the untracked files listed; ignored files (`.env`, build output) stay |

The branch you leave keeps its commits. Other worktrees, stashes, and ignored files are untouched. Never stash, copy, or move the user's files on your own.

## Setup

1. **Session.** `mkdir -p <S>/{cases,runtime,secrets,briefs,logs}`; `chmod 700 <S>/secrets`.
2. **Test checkout.** Use the current clone when a remote points at the base repo; otherwise `gh repo clone <owner>/<repo> <S>/clone -- --filter=blob:none`. Add `<S>/tree` detached at the default branch head: `git -C <clone> worktree add --detach <S>/tree origin/<default>`. Never point it at the developer's branches.
3. **Services.** Read `<ts>/SKILL.md` and follow its Inventory and Start for the data services the repo needs (databases, caches, queues, emulators), with these overrides, which your `pr-testing` invocation authorizes:
   - *Owned for this session.* You start the set once and reuse it for every PR in the session. Its "new every time" rule forbids attaching to another session's set, and that still holds.
   - *Fakes first.* In its Inventory, the recommended option for every external API is a repo double, an emulator, or a stub. **Real sandbox** is never the default. Real choices are made per PR in step 3, not here.
   - *No app here.* Answer its "App" question with no; this skill runs the app (below).
   - Data services stay on `127.0.0.1`, exactly as its recipes say. Its record (`services.md`, `services.json`) is the session's record: note its ID and `services.json` path in the ledger.
4. **Ports.** Choose the app port once: the first free port from 55500 (test with a bind on `127.0.0.1`). Record it; every PR in the session uses it.
5. **Dashboard.** `DASH init --dir <S>/checklist --notify "$(H notify-target)"`, then `H run --title "pr-testing checklist" --log <S>/logs/dashboard.log --cwd <skill> -- node scripts/dashboard.mjs serve --dir <S>/checklist`. Then `H share <dashboard port>`. A remote address → `DASH url --dir <S>/checklist --public <address>`. Give the user the link that `DASH url` prints: it carries the key, so give it only to them.
6. **Ledger.** Write it (below).

## Ledger

`<S>/ledger.md`, rewritten at every change. Facts only, no secrets, no values from secret files.

```markdown
# pr-testing ledger
Repo: <owner/repo> · Coordinator checkout: <path> (kept | reset to <sha>)
Test checkout: <S>/tree · Services: <set id> (<services.json path>)
App: <stable URL> (port <n>, handle <process handle>) · Dashboard: <URL> (handle <h>) · Share: <remote URL | local>
Active: PR #<n> @ <sha> · integrations: <name=fake|real(target)>, …

| PR | base ← head | tested SHA | integrations | status |
|---|---|---|---|---|
| #12 | main ← feat/x | abc1234 | mail=fake, stripe=stub | retest asked |

## Fix batches
| batch | PR | cases | implementer | from → to SHA | result |
|---|---|---|---|---|---|
| 12-1 | #12 | export-csv | <link> | abc1234 → def5678 | deployed, retest asked |
```

## Checkout

1. `git -C <clone> fetch origin pull/<n>/head`. Check that `git rev-parse FETCH_HEAD` equals `headRefOid` from `gh pr view <n> --json headRefOid,baseRefName,isDraft,body,files`. A mismatch → re-read once, then report that the PR is moving.
2. **Dirty guard.** `git -C <S>/tree status --porcelain=v1 --untracked-files=all` must be empty. Otherwise show the files and stop; the user decides how to preserve them. Never stash, copy, reset, or overwrite them, and never carry them into another PR.
3. `git -C <S>/tree checkout --detach <headRefOid>`; confirm `HEAD` equals it. Install dependencies inside `<S>/tree` with the repo's lockfile command. Never reuse the developer's installed dependencies.

## Integrations

Read, don't run: env templates, config loaders, client libraries in the manifest, feature flags, and the diff's new calls. List every external service the PR touches, plus any new infrastructure it needs (a queue, a bucket, a second database):

```markdown
| Service | Used by | Default here | Real option |
|---|---|---|---|
| Email | SMTP_URL | **emulator** Mailpit | provider sandbox — sends real mail to the addresses you enter |
| Payments | STRIPE_* | **stub** (no repo double) | test-mode keys — creates objects in that Stripe account |
| Maps | MAPS_KEY | **unset** — map tiles stay blank | real key — billed per request |
```

Ask: "Which, if any, should use the real service for this PR?" Then wait. The answer applies to this PR only. On a switch, reset everything to the defaults and ask again.

For each real choice: name the target, then ask the user to put the values in `<S>/secrets/<n>.env` through **secret**. Never ask for the values in chat and never read the file. Add new infrastructure with `<ts>` recipes into the same set and record it there.

Write `<S>/runtime/<n>.env`, the non-secret env: this set's URLs, the fake switches, emulator endpoints, the app port, and `NODE_ENV`/`APP_ENV` as the repo's test setup expects. Then run `GUARD env <S>/runtime/<n>.env --record <services.json> --allow <real keys>`. It must pass before the app starts. Look for env files the app loads by itself from the tree (`.env`, `config/*.env`). A tracked one that names real endpoints → override each key in the runtime file, or list it as a limitation.

## Data

Before every migrate, reset, or seed: `GUARD db <url> --record <services.json>`. A refusal stops the step.

- **Fresh per PR.** Drop and recreate the database, run the PR's migrations, then the synthetic seed. Never keep an earlier PR's schema.
- **Synthetic only.** Use the repo seed when it is synthetic; otherwise write the smallest seed through the repo's factories into `<S>/runtime/seed-<n>.*`. The login the user gets is created by that seed.
- Document stores, buckets, and queues are this set's, emptied the same way.

## App

Start it with the repo's run command from `<S>/tree`, with a clean environment, the service label, and the stable port:

```sh
H run --title "pr-testing app :<port>" --log <S>/logs/app.log --cwd <S>/tree -- \
  sh <skill>/scripts/clean-env.sh --env <S>/runtime/<n>.env [--env <S>/secrets/<n>.env] \
  --set AGENT_SERVICE_RECORD=<services.json> --set AGENT_SERVICE_NAME=app -- <run command>
```

- **Binding.** Follow the repo's rule (its `HOST`/`--host` setting, README, or dev config). Local or **share** → `127.0.0.1`. When the user tests from another machine and the repo supports it, bind to all interfaces, and say that anyone on the network can reach it. Data services stay on loopback either way.
- **Ready.** Wait for an HTTP answer (≤ 120 s), then load one page as the seeded user. Not ready → leave everything running and report the log lines.
- Add the app to the set's `services.md` and `services.json`, with its stop command `H stop-run <handle>`, so the set's own **Stop** covers it.
- `DASH active --dir <S>/checklist --pr <n> --sha <sha> --app-url <app URL>`. Remote → `H share <port>` for the app too.

## Switch

1. Dirty guard on `<S>/tree` (Checkout step 2).
2. Stop the app: `H stop-run <handle>`.
3. Checkout the other PR in the same `<S>/tree`.
4. Data: fresh per PR (Data).
5. Integrations: back to the defaults, then step 3's question again.
6. Start the app on the same port; set it active. Earlier PRs keep their checklists and results.

## Revision

When an implementer reports a new SHA on the active PR:

1. Check that the remote head equals that SHA. Run the dirty guard, stop the app, check out the SHA, and reinstall dependencies when the lockfile changed.
2. Migrations or seeds changed between the old and new SHA (`git diff --name-only <old> <new>`) → fresh data. Otherwise keep the data.
3. `DASH revision --dir <S>/checklist --pr <n> --sha <new> --retest <ids | all>`. List the cases the fix touched; when you can't tell, use `all`.
4. Start the app at the same URL, set it active, and ask the user to retest. Update the ledger.

## Stop

Ask which: **this session** (default) or **all pr-testing sessions** (look for ledgers under the storage root). For each session:

1. Stop the app and the dashboard: `H stop-run <handle>`. Then `H unshare <port>` for each shared port.
2. Stop the service set with `<ts>` Stop, using the ID from the ledger. The user can also stop it with that skill's own `stop <id>` command.
3. Test checkout: dirty → show the files and ask. Clean → `git -C <clone> worktree remove <S>/tree`.
4. Keep `<S>/checklist` and the ledger (results, no secrets). Delete `<S>/secrets/`. Report what stopped, what did not, and the retry command.

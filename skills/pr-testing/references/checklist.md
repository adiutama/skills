# Checklist dashboard

One checklist per PR, written by you after reading that PR. The dashboard only displays what you write; it never invents checks. `DASH` = `node <skill>/scripts/dashboard.mjs`; every command takes `--dir <S>/checklist`.

## Writing cases

Read the PR description, the diff, the docs it changes, and its linked issue. Write `<S>/cases/<n>.json`:

```json
{ "cases": [
  { "id": "export-csv", "title": "Export invoices as CSV",
    "steps": ["Log in as finance@example.test", "Open Invoices", "Press Export CSV"],
    "expected": "invoices.csv downloads with the 3 seeded invoices, newest first",
    "area": "invoices" }
] }
```

- **One case per behaviour the PR claims or changes.** Include the edge cases its diff handles: empty, permission denied, an error path. Add a regression case for a neighbouring flow only when the diff touches its shared code.
- **Concrete:** steps use the seeded data and the URL paths; `expected` says what the user should see, not "works".
- **IDs are stable** (`^[A-Za-z0-9][A-Za-z0-9._-]{0,39}$`) and stay the same across revisions; results are keyed by them.
- No secrets in titles, steps, or expected text. Login passwords that the seed created are fine.
- Something not testable here (a fake hides it) → leave it out and list it under **Limitations**.

Load it: `DASH cases --pr <n> --sha <sha> --file <S>/cases/<n>.json --title "<PR title>" --url <PR URL>`. Running the same command again at the same SHA replaces the case list and keeps existing results. New cases start at Pending.

## States

Pending · Pass · Fail · Blocked are the user's. **Needs retest** is set only by `DASH revision`; earlier results stay in history, shown under each case. Results are saved on the server per PR and per revision. They survive a refresh, a dashboard restart, and switches between PRs.

## Commands

| Command | Use |
|---|---|
| `init [--notify "$(harness.sh notify-target)"] [--host H] [--port N]` | once per session; keeps the port and key |
| `serve` | run with `harness.sh run`; it fails rather than move to another port |
| `url [--public <URL>]` | the link to give the user (it carries the key) |
| `cases --pr --sha --file [--title --url]` | write or replace a PR's cases at its current SHA |
| `revision --pr --sha [--retest all\|ID,ID] [--file]` | new head: listed cases → Needs retest, the rest keep their results stamped with the old SHA |
| `active --pr --sha [--app-url]` | which PR the app is running now |
| `results --pr [--json]` | read the user's results |
| `inbox [--all] [--json]` · `ack <id>` | unacknowledged submissions · mark one handled |

## Security

The key from `url` becomes an HttpOnly, SameSite=Strict cookie. Every write also needs a CSRF header that only the page can read. Requests are size-capped and validated. No endpoint runs a command, and no request can choose the notify target, which is fixed by `init`. State files are mode 0600 under `<S>`, outside the repo. Binding to `0.0.0.0` (`init --host 0.0.0.0`) is for testing from another machine on a trusted network only. Say so when you use it.

## Submissions

The three buttons save a submission first (unique ID), then deliver it through **notify**, and show what actually happened:

| Shown | Meaning |
|---|---|
| Sent to the agent | the harness accepted it and this thread was woken or steered |
| Queued | the thread is waiting on an open question; it arrives when that is answered — do not resend |
| Not delivered | delivery failed; the reason is shown, with **Try sending again** and **Copy for chat** |
| Saved | this harness cannot wake the agent; **Copy for chat** gives the text to paste |

A double click or a retried request sends once (idempotency key). An identical **Request fixes** at the same SHA returns the earlier submission instead of starting a second batch.

When one arrives (as a message starting `[pr-testing]`, or through `DASH inbox` when the user says "check the dashboard"):

- **feedback** → read the notes and cases with `DASH results`, reproduce what you can, and reply with what you saw and a proposed fix batch. Do not spawn anything.
- **fix-request** → the user authorizes one fresh implementer for the listed cases and notes ([fixes.md](fixes.md)). It was already deduplicated, so one submission means one batch.
- **complete** → summarise the results. When everything passed, say what step 5 needs. When something failed or is pending, say so. It is not merge authorization.

Then `DASH ack <id>`, and note the batch or decision in the ledger.

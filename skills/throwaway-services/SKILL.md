---
name: throwaway-services
description: A disposable environment for checking a case by hand — new local services, emulators, and the app for a worktree, seeded for the case, with the link to open first; runs until stopped.
disable-model-invocation: true
argument-hint: '[start] [<service>,…] [--for <worktree>] [--version <n>] | seed <id> [<case>] | status | stop [<id> | all]'
compatibility: Needs the service's server binaries, or Docker.
metadata:
  version: "1.1.0"
  related: "evidence, pr-review"
---

## Harness

At the start, detect your harness with [harnesses.md § Detect](references/harnesses.md#detect), then read its glossary column. These terms mean exactly what that column says, everywhere in this skill and its references: **home** (`<home>` in paths) · **invoke** (`<invoke>` in commands).

## Route

- No action, or `start` → **Start**. `--for` defaults to the current worktree. No services named → **Inventory** first; services named → Inventory only for what wasn't named.
- `seed <id> [<case>]` → **Seed** again into a running set: reset to the recorded seed, or a new case.
- `status` → **Status**.
- `stop [<id> | all]` → **Stop**. No argument → the sets started in this conversation; none → show **Status** and ask which.

A set is everything one `start` creates. Its ID `<id>` is `<yyyymmdd-hhmmss>-<4 random hex>`; its directory `<D>` = `<home>/<id>/` is created with an exclusive `mkdir` (exists → new ID). `<D>/services.md` is the record: the worktree, the data choice and seed file, and one block per service and app — kind, version, port, data directory, URL, process identity (PID with its start time, or container ID), and stop command. `<D>/services.json` carries the same set for tools that read it, in the shape [record.md](references/record.md) defines; both files change in the same step.

## Rules

- **Never the developer's own.** Never connect to, reuse, stop, or change a service you didn't start. A port in use is someone else's.
- **New every time.** Never attach to, reuse, or copy an earlier set, even one running for the same worktree.
- **Loopback only, data in `<D>`.** Bind to `127.0.0.1`; trust auth on loopback is fine. Data, logs, and container volumes live under `<D>`, never in the repo.
- **Match the repo.** Use the major version the repo expects (CI config, compose file, `.tool-versions`, engines); `--version` overrides. Unavoidable mismatch → say so in the report.
- **Record first, then start.** Write each service's block (status `starting`, with its stop command) and its `services.json` entry before launching it; update both once running. A start that fails stops what it began.
- **Runs until stopped.** Start everything detached so it survives the conversation and the agent session — self-daemonizing per its recipe, else `nohup <label> <cmd> > <D>/<name>.log 2>&1 &`. Never stop or clean up a set on your own.
- **Label every process.** Start each native process with `<label>` = `env AGENT_SERVICE_RECORD=<D>/services.json AGENT_SERVICE_NAME=<name>` in front of its command, `<name>` being its entry's name in `services.json` ([record.md § Labels](references/record.md#labels)). Containers can't carry it; their record entry is enough.
- **Writes only to your services.** Migrations and seeds run against this set's URLs only; check the target before every write.
- **Act without asking** once the user has answered Inventory; everything here is disposable.

## Inventory

Find everything the app in the worktree needs from outside itself. Read, don't run: env templates (`.env.example`), config loaders, compose files, CI config, client libraries in the manifest, and the repo's test setup (fakes, mocks, switches). Something the code calls but no template mentions → list it with "found in code, not in env templates".

Ask once, in one message, and start nothing before the answer:

```markdown
| Need | Used by | Options (recommended in bold) |
|---|---|---|
| Postgres 16 | DATABASE_URL | **local** |
| Email | SMTP_URL | **emulator** Mailpit · stub · leave unset → sending fails |
| Google Drive | GOOGLE_* | **repo double** `DRIVE_FAKE=1` · real sandbox · stub · leave unset |

**Data** — 1. empty (migrations only) · 2. repo seed (`<command>`) · 3. seeded for a case — describe it · 4. nothing (no migrations)
**App** — run it too? yes (`<command>`) · no
```

| Option | Meaning |
|---|---|
| **local** | a real local server ([recipes.md](references/recipes.md)) |
| **emulator** | an official local imitation of the API ([recipes.md § Emulators](references/recipes.md#emulators)) |
| **repo double** | a fake the repo ships; give its switch. Preferred over a stub. |
| **real sandbox** | the provider's test account; the user puts credentials in a git-ignored env file — never ask for or echo them |
| **stub** | a loopback server with fixed responses so the app boots ([recipes.md § Stubs](references/recipes.md#stubs)); tests against it prove nothing about the real API |
| **leave unset** | say what fails or skips |

## Start

1. **Resolve** per service: version, a free port (bind test on `127.0.0.1`, from 55400), and a runner — native server binaries → Docker if its daemon answers → neither: stop and say what to install.
2. **Start** each service per [recipes.md](references/recipes.md); wait until it accepts connections (≤ 30 s, else read its log, stop it, report).
3. **Data.** Create a database named after the worktree's folder, then apply the data choice per **Seed**.
4. **App** (if chosen): find the repo's run command (scripts `dev`/`start`/`serve`, Makefile, Procfile, README; several apps → ask which). Start it detached and labelled from the worktree with this set's URLs and chosen switches exported, on a free port (the port variable the app reads), logging to `<D>/app-<name>.log`. Wait until it answers HTTP (≤ 120 s); it doesn't → leave the services up and report **Not ready**. For a seeded case, find the app URL of each record that makes the case.
5. **Report.**

## Report

Always this shape; the user acts on the first block without reading further.

```markdown
## ▶ Ready to verify — <id>

**Open:** <app URL deep-linked to the case's main record | "no app running">
**Case:** <the case in one line | repo seed | empty>
**Check:**
- <what to look at> — <URL path> — <what you should see>

**Stop everything:** `<invoke> stop <id>`

---
| Running | URL | Notes |
|---|---|---|
| app (<name>) | http://127.0.0.1:<port> | log `<D>/app-<name>.log` |
| postgres 16 | `postgres://postgres@127.0.0.1:<port>/<db>` | <seed> |

**Data:** <entities and counts, the values that make the case, verification result>
**Not handled:** <unset or sandbox rows and what the user must set; omit if none>
**Env for tests:** `DATABASE_URL=… …`
**Record:** `<D>/services.md` (pass it to other tools that take a services record)
```

Not ready → heading `## ⚠ Not ready — <id>`; **Cause** (one line) and **Log** (the relevant lines) replace **Open**; running services stay listed.

## Seed

Run from the worktree with this set's URLs exported.

1. **Migrations** — the repo's migrate command (scripts, Makefile, docs). Not found → ask.
2. **Repo seed** — the repo's seed command, as is.
3. **Case seed** — the smallest data set that reproduces the case, through the repo's factories, fixtures, or seed helpers when they exist, else raw SQL. Save it to `<D>/seeds/<case>.<ext>` with the case in a header comment. Apply it, verify with read queries that the case holds, and include the result in the report.

`seed <id> [<case>]`: drop and recreate the database, migrate, apply the recorded seed or the new case, update `services.md` and `services.json` (`case`, `credentials`), and report in the **Report** shape. A running app keeps running.

## Status

For every `<D>/services.md` under `<home>`: check each process or container is alive and still the one recorded (same start time or container ID), and that its port answers. Table: ID, worktree, app URL, service, URL, alive / dead / replaced, age.

- **alive** — a recorded PID runs with its recorded start time, or the container is running.
- **dead** — none of its recorded PIDs exists, or the container is gone: something else stopped it.
- **replaced** — not alive, and a recorded PID now has a different start time: that process is someone else's.

## Stop

For each set in scope, app first, then each service, by its **Status** state:

- **alive** → run its stop command, then delete its data directory whether or not the stop succeeded.
- **dead** → skip the stop command (it would fail or hit nothing); delete its data directory.
- **replaced** → don't signal it or touch its port; delete its data directory only when no running process has it open (`lsof +D <dir>` is empty), else leave it and say so.

Then confirm each port is free of this set's processes. Nothing left → delete `services.md` and `services.json`, and remove `<D>` when empty; something left → keep both records, marking what's left, so a retry finds it. Report what stopped and what would not, with the command to retry. Never stop anything not recorded in a `services.md`.

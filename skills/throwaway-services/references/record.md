# Service record

A small contract that lets any tool find out which set a running process belongs to, what it is, and how to reach it. The tool needs no knowledge of this skill. This skill is one producer; any tool that starts detached services may follow it. Version 1.

Two parts: **labels** on each process, and a **record file** they point to.

## Labels

Every native process a set starts carries two environment variables, which its children inherit:

| Variable | Value |
|---|---|
| `AGENT_SERVICE_RECORD` | Absolute path to the set's `services.json`. |
| `AGENT_SERVICE_NAME` | The `name` of this process's entry in that file. |

- Set both by starting the command with `env AGENT_SERVICE_RECORD=<path> AGENT_SERVICE_NAME=<name> <cmd>`. Daemonizing servers keep them: `pg_ctl` passes them to the postmaster, and `redis-server --daemonize` keeps them across its fork.
- Containers can't carry them. Their entry in the file still lists their ports.

## Record file

`<D>/services.json`, beside `services.md`.

- **Encoding:** UTF-8 JSON object, at most 64 KiB.
- **Writing:** replace the whole file atomically — write a temporary file in the same folder, then rename it over `services.json`. Never edit it in place.
- **Permissions:** mode `0600`, owned by the user who runs the services.
- **When:** write it before starting the first service, then rewrite it whenever `services.md` changes.

```json
{
  "version": 1,
  "id": "20261017-201623-d32d",
  "title": "kai-platform — multi-org access case",
  "case": "adi.utama@strata.co.jp is platform admin, writer at Demo AM Co, read-only at Contoso",
  "worktree": "/Users/me/worktrees/kai-platform",
  "createdAt": "2026-10-17T20:16:23+09:00",
  "credentials": [
    { "label": "Case login", "username": "adi.utama@strata.co.jp", "secret": "abcd1234" }
  ],
  "services": [
    {
      "name": "postgres",
      "kind": "postgres 16",
      "ports": [55400],
      "urls": [
        { "label": "Superuser", "url": "postgres://postgres@127.0.0.1:55400/kai_platform" },
        { "label": "App role", "url": "postgres://kai_app:kai_app_dev@127.0.0.1:55400/kai_platform" }
      ],
      "log": "/Users/me/.agents/throwaway-services/20261017-201623-d32d/pg.log"
    },
    {
      "name": "api",
      "kind": "app",
      "ports": [55401],
      "urls": [{ "label": "App", "url": "http://127.0.0.1:55401" }],
      "log": "/Users/me/.agents/throwaway-services/20261017-201623-d32d/app-kai.log"
    }
  ]
}
```

### Fields

| Field | Type | Required | Meaning |
|---|---|---|---|
| `version` | integer | yes | `1`. |
| `id` | string | no | The set's ID. |
| `title` | string, one line, ≤ 200 chars | no | What the set is for: the worktree's folder and the case in a few words. |
| `case` | string, ≤ 2000 chars | no | The seeded case in a sentence or two; `repo seed` or `empty` when there's no case. |
| `worktree` | absolute path | no | The worktree the set serves. |
| `createdAt` | RFC 3339 timestamp with offset | no | When the set was started. |
| `credentials` | array of credential | no | Logins this set created for checking by hand. |
| `credentials[].label` | string, one line | yes in a credential | What the login is for. |
| `credentials[].username` | string | no | |
| `credentials[].secret` | string | no | Password or token. |
| `services` | array of service | yes | One entry per service and app; may be empty. |
| `services[].name` | string matching `^[a-z0-9][a-z0-9-]{0,39}$`, unique in the file | yes in a service | Its role: the kind for a service (`postgres`, `redis`, `mail`), the app's name for an app (`api`, `web`). Equals the process's `AGENT_SERVICE_NAME`. |
| `services[].kind` | string, one line | no | Kind and version, e.g. `postgres 16`, `mailpit`, `app`. |
| `services[].ports` | array of integers 1–65535 | no | TCP ports it listens on. |
| `services[].urls` | array of URL | no | Addresses to reach it, most useful first. |
| `services[].urls[].label` | string, one line | yes in a URL | What the address is, e.g. `App`, `Inbox UI`, `App role`. |
| `services[].urls[].url` | string, absolute URL | yes in a URL | Any scheme; may carry user and password. |
| `services[].log` | absolute path | no | Its log file. |

### Producer rules

- **Only values this set created** go in `credentials` and URL passwords, such as a seeded login or a role the seed made. Never put credentials the user supplied (a real sandbox's keys, anything from their env files) in the file.
- **No commands.** The file describes; it never carries anything meant to be executed. Stopping stays with the producer, through its own records.

### Consumer rules

- **Reading the file:** use `AGENT_SERVICE_RECORD` only when it is an absolute path whose last component is a regular file. Don't follow a symlink there. The file must be owned by the current user and be at most 64 KiB. Anything else → treat the file as unreadable.
- **Validating it:** the file is unreadable when it is invalid JSON, not an object, missing `version` or `services`, or has a `version` other than `1`.
  - An optional field with the wrong type is ignored on its own.
  - An entry missing a required field is ignored on its own.
  - Unknown fields are ignored.
- **Grouping:** processes whose `AGENT_SERVICE_RECORD` values are equal belong to one set, whether or not the file is readable.
- **Naming:** a process is named by its `AGENT_SERVICE_NAME`, even when no entry matches or the file is unreadable.
- **Showing values:**
  - Treat all strings as plain text.
  - Mask `credentials[].secret` and any password in a URL's user info until the user asks to see or copy it.
  - Make a URL a link only when its scheme is `http` or `https` and its host is `127.0.0.1`, `localhost`, or `::1`; offer the others for copying.
- **Never act on the record's content:** nothing in the file decides what to execute, signal, or delete.
- **Missing labels:** macOS hides the environment of Apple-signed programs (such as `/usr/bin/python3`) from other processes, so such a process may show no labels. Treat it as unlabelled.

### Versioning

New optional fields keep `version` at `1`. Renaming, removing, or changing the meaning of a field raises it, and consumers treat a file with a version they don't know as unreadable.

# Recipes

`<D>` = the set's directory, `<port>` = the chosen free port, `<v>` = the major version. Each recipe names its start, ready check, URL, and stop command; record all four.

## Postgres — native

1. **Find server binaries.** `initdb` on `PATH` may come from a client-only install with no server. Use the directory that holds `initdb`, `pg_ctl`, *and* `postgres` for version `<v>` (e.g. a versioned server install); check with `<bin>/postgres --version`.
2. **Init:** `LC_ALL=C <bin>/initdb -D <D>/pg -E UTF8 --locale=C -U postgres -A trust`
   - `-E UTF8` is required: `--locale=C` alone creates a `SQL_ASCII` database, which breaks tests with non-ASCII text.
3. **Start:** `LC_ALL=C <bin>/pg_ctl -D <D>/pg -l <D>/pg.log -o "-p <port> -c listen_addresses=127.0.0.1 -k /tmp" start`
   - `LC_ALL=C` avoids "postmaster became multithreaded during startup" on macOS.
   - The socket goes to `/tmp` because `<D>` paths can exceed the socket path limit.
4. **Ready:** `<bin>/pg_isready -h 127.0.0.1 -p <port>`.
5. **Database** (`--for`): `<bin>/createdb -h 127.0.0.1 -p <port> -U postgres <name>`.
6. **URL:** `postgres://postgres@127.0.0.1:<port>/<name or postgres>`
7. **Stop:** `LC_ALL=C <bin>/pg_ctl -D <D>/pg stop -m fast; rm -rf <D>/pg <D>/pg.log`
8. **Identity:** the PID in `<D>/pg/postmaster.pid` and its start time (`ps -o lstart= -p <pid>`).

## Postgres — Docker

- **Start:** `docker run -d --rm --name tsvc-<id>-pg -e POSTGRES_HOST_AUTH_METHOD=trust -v <D>/pg:/var/lib/postgresql/data -p 127.0.0.1:<port>:5432 postgres:<v>`
- **Ready:** `docker exec tsvc-<id>-pg pg_isready -h 127.0.0.1 -U postgres` (over TCP: the socket answers before the server is ready)
- **Database:** `docker exec tsvc-<id>-pg createdb -U postgres <name>`
- **URL:** as native.
- **Stop:** `docker stop tsvc-<id>-pg; rm -rf <D>/pg` · **Identity:** the container ID.

## Redis — native

- **Start:** `redis-server --port <port> --bind 127.0.0.1 --dir <D>/redis --save '' --appendonly no --daemonize yes --pidfile <D>/redis/redis.pid --logfile <D>/redis/redis.log` (create `<D>/redis` first).
- **Ready:** `redis-cli -h 127.0.0.1 -p <port> ping` → `PONG`.
- **URL:** `redis://127.0.0.1:<port>/0`
- **Stop:** `redis-cli -h 127.0.0.1 -p <port> shutdown nosave; rm -rf <D>/redis` · **Identity:** PID from `<D>/redis/redis.pid` and its start time.

## Redis — Docker

- **Start:** `docker run -d --rm --name tsvc-<id>-redis -p 127.0.0.1:<port>:6379 redis:<v>`
- **Ready:** `docker exec tsvc-<id>-redis redis-cli ping`
- **Stop:** `docker stop tsvc-<id>-redis` · **Identity:** the container ID.

## Emulators

Official local imitations of external APIs. Docker form shown; use a native binary instead when installed. The app is pointed at each by the env var in the last column.

| Emulates | Start | Ready | Point the app at |
|---|---|---|---|
| Email (SMTP) — Mailpit | `docker run -d --rm --name tsvc-<id>-mail -p 127.0.0.1:<port>:1025 -p 127.0.0.1:<ui port>:8025 axllent/mailpit` | `curl -sf http://127.0.0.1:<ui port>/livez` | `smtp://127.0.0.1:<port>`; inbox UI at `http://127.0.0.1:<ui port>` |
| S3 — MinIO | `docker run -d --rm --name tsvc-<id>-s3 -p 127.0.0.1:<port>:9000 minio/minio server /data` | `curl -sf http://127.0.0.1:<port>/minio/health/live` | endpoint `http://127.0.0.1:<port>`, keys `minioadmin` / `minioadmin` |
| Stripe — stripe-mock | `docker run -d --rm --name tsvc-<id>-stripe -p 127.0.0.1:<port>:12111 stripe/stripe-mock` | port answers | API base `http://127.0.0.1:<port>`, any `sk_test_…` key |
| AWS (many services) — LocalStack | `docker run -d --rm --name tsvc-<id>-aws -p 127.0.0.1:<port>:4566 localstack/localstack` | `curl -sf http://127.0.0.1:<port>/_localstack/health` | endpoint `http://127.0.0.1:<port>`, any keys |
| Google Pub/Sub, Firestore, Datastore | `gcloud beta emulators <name> start --host-port=127.0.0.1:<port>` (run in the background, log to `<D>`) | port answers | `<NAME>_EMULATOR_HOST=127.0.0.1:<port>` |

Stop: `docker stop tsvc-<id>-<name>`, or kill the recorded process for native and gcloud emulators. Identity: the container ID, or PID and start time. Emulators keep no data worth keeping; nothing else to delete.

## Stubs

Only after the user picks **stub** for a row. Write the smallest server the repo's own runtime can run (one file in `<D>/stubs/<name>/`), bound to `127.0.0.1:<port>`, answering only the routes the app calls at startup or in the tests the user named, with fixed responses shown to the user first. Unknown route → `501` with the path, so a gap is visible rather than silently passing. Record start, ready check (a known route answers), URL, and stop (kill the recorded process, remove the folder).

## Another service

No recipe here → build one with the same four parts from the service's docs: data under `<D>/<service>`, loopback bind, no persistence beyond `<D>`, a stop command that also removes its data. Record it in `services.md` like the others.

#!/usr/bin/env python3
"""Read the whole bb memory store, and write to it with a journal.

  memory.py dump [--summaries]
      Every global and project memory in full, as Markdown on stdout, grouped by
      scope. One call replaces a catalog per project plus a get per entry.
      --summaries: one line per memory (id, version, name, summary), no details.

  memory.py write --journal <file.jsonl> --op <op id> [--project <id>] -- add|update|forget <bb memory args...>
      Runs `bb memory <args>` (with BB_PROJECT_ID=<id> for project scope).
      1. The op id is already done → prints "already applied", writes nothing.
         Already unresolved (see pending) → exits 3, writes nothing: resolve it first.
      2. Appends an "intent" line, with the full memory as it was for an update or
         forget, and flushes it to disk before touching memory.
      3. Runs the write, then appends "done", "failed" (bb rejected it: version
         conflict, not found, invalid input, so nothing changed), or "uncertain"
         (any other error: it may have been applied).
      Every change therefore has its undo record before it happens.

  memory.py pending --journal <file.jsonl>
      Unresolved ops, one JSON per line: an intent with no outcome (a run crashed
      mid-write) or an uncertain outcome. Check each memory before resolving it.

  memory.py check --journal <file.jsonl> --op <op id>
      For an unresolved op: the memory before, the memory now (an add is found by
      its scope and name, since it has no id yet), and a hint whether it happened.

  memory.py resolve --journal <file.jsonl> --op <op id> --status done|failed --note <what you checked>
      Records the outcome of an unresolved op after checking the memory.

Fails closed: if a scope holds more memories than one catalog call returns, dump
exits 1 instead of returning part of the store.

Run with `python3 -I`. Needs the bb CLI.
"""
import argparse
import datetime as dt
import json
import os
import re
import subprocess
import sys

CATALOG_LIMIT = 100


def bb(args, project=None):
    env = dict(os.environ)
    if project:
        env["BB_PROJECT_ID"] = project
    else:
        env.pop("BB_PROJECT_ID", None)
    out = subprocess.run(["bb", *args], capture_output=True, text=True, env=env)
    if out.returncode != 0:
        err = RuntimeError(f"bb {' '.join(args[:3])}: {out.stderr.strip() or out.stdout.strip()}")
        err.stdout = out.stdout
        raise err
    return json.loads(out.stdout)


def catalog(scope, project=None):
    res = bb(["memory", "catalog", "--scope", scope, "--limit", str(CATALOG_LIMIT), "--json"], project)
    mems = res.get("memories", [])
    if res.get("total", len(mems)) > len(mems):
        raise RuntimeError(
            f"{scope} {project or ''} has {res['total']} memories but only {len(mems)} can be listed; "
            "the store is too big to review whole, so nothing was dumped"
        )
    return mems


def render(m):
    tags = ", ".join(m.get("tags") or [])
    pin = " · pinned" if m.get("pinned") else ""
    return (
        f"### {m['name']} · `{m['id']}` · v{m['version']}\n"
        f"{m.get('kind')} · importance {m.get('importance')}{pin} · tags: {tags or '-'} · "
        f"updated {dt.datetime.fromtimestamp(m['updatedAt'] / 1000).date()}\n\n"
        f"**Summary:** {m['summary']}\n\n{m.get('details', '').strip()}\n"
    )


def dump(a):
    groups = [("Global", None, catalog("global"))]
    for p in bb(["project", "list", "--include-personal", "--json"]):
        mems = catalog("project", p["id"])
        if mems:
            groups.append((f"Project {p.get('name') or p['id']} (`{p['id']}`)", p["id"], mems))
    total = sum(len(g[2]) for g in groups)
    print(f"# Memory store · {total} memories\n")
    print("Counts: " + " · ".join(f"{name.split(' (')[0]} {len(m)}" for name, _, m in groups) + "\n")
    for name, project, mems in groups:
        print(f"## {name}\n")
        if a.summaries:
            print("\n".join(f"- `{c['id']}` v{c['version']} **{c['name']}**: {c['summary']}" for c in mems) + "\n")
            continue
        for c in mems:
            full = bb(["memory", "get", c["id"], "--json"], project)["memory"]
            print(render(full))


def journal_lines(path):
    if not os.path.exists(path):
        return []
    with open(path) as f:
        return [json.loads(l) for l in f if l.strip()]


def append(path, entry):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "a") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")
        f.flush()
        os.fsync(f.fileno())


def now():
    return dt.datetime.now().astimezone().isoformat(timespec="seconds")


# bb's own refusals, checked before anything is stored. Only a structured
# {"ok": false} reply whose message matches one of these counts as "failed";
# any other error may have happened after the write, so it is "uncertain".
REJECTED = [re.compile(p) for p in (
    r"^version conflict for mem_\S+: expected \d+, current \d+$",
    r'^memory "mem_[^"]+" was not found in the current scope$',
    r'^an active (global|project) memory named "[^"]+" already exists$',
    r"^name must be ",
)]


def rejected(err_json):
    try:
        reply = json.loads(err_json)
    except (TypeError, ValueError):
        return False
    msg = (reply.get("error") or {}).get("message", "") if reply.get("ok") is False else ""
    return any(p.match(msg) for p in REJECTED)


def op_state(path, op):
    """Last status of an op: None (never seen), intent, done, failed, uncertain."""
    state = None
    for e in journal_lines(path):
        if e.get("op") == op:
            state = e.get("status")
    return state


def write(a):
    cmd = a.args[1:] if a.args and a.args[0] == "--" else a.args
    if not cmd or cmd[0] not in ("add", "update", "forget"):
        sys.exit("usage: memory.py write --journal <file> --op <id> [--project <id>] -- add|update|forget ...")
    state = op_state(a.journal, a.op)
    if state == "done":
        print(json.dumps({"ok": True, "skipped": "already applied", "op": a.op}))
        return
    if state in ("intent", "uncertain"):
        print(f"error: op {a.op} is unresolved; check the memory, then run resolve", file=sys.stderr)
        sys.exit(3)
    before = None
    if cmd[0] in ("update", "forget"):
        before = bb(["memory", "get", cmd[1], "--json"], a.project)["memory"]
    args = ["memory", *cmd]
    if "--json" not in args:
        args.append("--json")
    base = {"op": a.op, "project": a.project, "command": cmd}
    append(a.journal, {**base, "status": "intent", "time": now(), "before": before})
    try:
        result = bb(args, a.project)
    except RuntimeError as err:
        status = "failed" if rejected(getattr(err, "stdout", None)) else "uncertain"
        append(a.journal, {**base, "status": status, "time": now(), "error": str(err)})
        raise
    append(a.journal, {**base, "status": "done", "time": now(), "result": result})
    print(json.dumps(result, ensure_ascii=False))


def pending(a):
    last, intent = {}, {}
    for e in journal_lines(a.journal):
        last[e["op"]] = e
        if e.get("status") == "intent":
            intent[e["op"]] = e
    for op, e in last.items():
        if e.get("status") in ("intent", "uncertain"):
            print(json.dumps({**intent.get(op, e), "status": e["status"], "error": e.get("error")}, ensure_ascii=False))


def flag(cmd, name):
    return cmd[cmd.index(name) + 1] if name in cmd and cmd.index(name) + 1 < len(cmd) else None


def check(a):
    """Show what memory looks like now for an unresolved op, so it can be resolved."""
    intent = next((e for e in journal_lines(a.journal) if e.get("op") == a.op and e.get("status") == "intent"), None)
    if not intent:
        sys.exit(f"no intent for op {a.op}")
    cmd, project = intent["command"], intent.get("project")
    if cmd[0] == "add":
        scope, name = flag(cmd, "--scope"), flag(cmd, "--name")
        found = [m for m in catalog(scope, project if scope == "project" else None) if m["name"] == name]
        now_ = found[0] if found else None
        hint = "exists → the add happened (done)" if now_ else "absent → the add did not happen (failed)"
    else:
        try:
            now_ = bb(["memory", "get", cmd[1], "--json"], project)["memory"]
        except RuntimeError:
            now_ = None
        was = (intent.get("before") or {}).get("version")
        if cmd[0] == "forget":
            hint = "gone → done" if now_ is None else f"still at v{now_['version']} → failed" if now_["version"] == was else "changed since; check by hand"
        else:
            hint = f"still v{was} → failed" if now_ and now_["version"] == was else "newer version; compare it with the command to decide"
    print(json.dumps({"op": a.op, "command": cmd, "before": intent.get("before"), "now": now_, "hint": hint}, ensure_ascii=False, indent=1))


def resolve(a):
    if op_state(a.journal, a.op) not in ("intent", "uncertain"):
        sys.exit(f"op {a.op} is not unresolved")
    append(a.journal, {"op": a.op, "status": a.status, "time": now(), "resolved": True, "note": a.note})
    print(json.dumps({"ok": True, "op": a.op, "status": a.status}))


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    d = sub.add_parser("dump")
    d.add_argument("--summaries", action="store_true")
    w = sub.add_parser("write")
    w.add_argument("--journal", required=True)
    w.add_argument("--op", required=True)
    w.add_argument("--project")
    pe = sub.add_parser("pending")
    pe.add_argument("--journal", required=True)
    ck = sub.add_parser("check")
    ck.add_argument("--journal", required=True)
    ck.add_argument("--op", required=True)
    rs = sub.add_parser("resolve")
    rs.add_argument("--journal", required=True)
    rs.add_argument("--op", required=True)
    rs.add_argument("--status", required=True, choices=["done", "failed"])
    rs.add_argument("--note", required=True)
    w.add_argument("args", nargs=argparse.REMAINDER)
    a = p.parse_args()
    try:
        {"dump": dump, "write": write, "pending": pending, "check": check, "resolve": resolve}[a.cmd](a)
    except RuntimeError as err:
        print(f"error: {err}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

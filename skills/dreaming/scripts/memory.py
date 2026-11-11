#!/usr/bin/env python3
"""Read the whole bb memory store, and write to it with a journal.

  memory.py dump [--summaries]
      Every global and project memory in full, as Markdown on stdout, grouped by
      scope. One call replaces a catalog per project plus a get per entry.
      --summaries: one line per memory (id, version, name, summary), no details.

Every journal command takes --journal <file.jsonl>; default: journal.jsonl in the
data folder ($DREAMING_HOME, else ~/.bb/dreaming).

  memory.py write --op <op id> [--project <id>] -- add|update|forget <bb memory args...>
      Runs `bb memory <args>` (with BB_PROJECT_ID=<id> for project scope).
      1. The op id is already done → prints "already applied", writes nothing.
         Already unresolved (see pending) → exits 3, writes nothing: resolve it first.
      2. Appends an "intent" line, with the full memory as it was for an update or
         forget, and flushes it to disk before touching memory.
      3. Runs the write, then appends "done", "failed" (bb rejected it: version
         conflict, not found, invalid input, so nothing changed), or "uncertain"
         (any other error: it may have been applied).
      Every change therefore has its undo record before it happens.
      Refuses --pinned and any update or forget of a pinned memory.

  memory.py pending
      Unresolved ops, one JSON per line: an intent with no outcome (a run crashed
      mid-write) or an uncertain outcome. Check each memory before resolving it.

  memory.py check --op <op id>
      For an unresolved op: the memory before, the memory now (an add is found by
      its scope and name, since it has no id yet), and a hint whether it happened.

  memory.py resolve --op <op id> --status done|failed --note <what you checked>
      Records the outcome of an unresolved op after checking the memory.

  memory.py undo --op <op id> --reason <why>
      Reverses a done op as a new journaled op "<op id>:undo": an add is forgotten,
      an update is restored to the memory as it was, a forget is added back.

  memory.py history [--since <YYYY-MM-DD>] [--run <run id>]
      One JSON line per op (last status, action, project, memory id, name, time):
      for reports and the weekly audit.

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


def day(ms):
    return dt.datetime.fromtimestamp(ms / 1000).date()


def render(m):
    tags = ", ".join(m.get("tags") or [])
    pin = " · pinned" if m.get("pinned") else ""
    return (
        f"### {m['name']} · `{m['id']}` · v{m['version']}\n"
        f"{m.get('kind')} · importance {m.get('importance')}{pin} · tags: {tags or '-'} · "
        f"created {day(m['createdAt'])} · updated {day(m['updatedAt'])}\n\n"
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
            print("\n".join(f"- `{c['id']}` v{c['version']}{' · pinned' if c.get('pinned') else ''} "
                             f"**{c['name']}**: {c['summary']}" for c in mems) + "\n")
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


def journaled(journal, op, project, cmd):
    """Run one memory write with its journal entries; returns bb's reply."""
    if "--pinned" in cmd:
        sys.exit("refused: dreaming never pins a memory")
    state = op_state(journal, op)
    if state == "done":
        return {"ok": True, "skipped": "already applied", "op": op}
    if state in ("intent", "uncertain"):
        print(f"error: op {op} is unresolved; check the memory, then run resolve", file=sys.stderr)
        sys.exit(3)
    before = None
    if cmd[0] in ("update", "forget"):
        before = bb(["memory", "get", cmd[1], "--json"], project)["memory"]
        if before.get("pinned"):
            sys.exit(f"refused: {before['name']} is pinned; suggest the change in the report instead")
    args = ["memory", *cmd]
    if "--json" not in args:
        args.append("--json")
    base = {"op": op, "project": project, "command": cmd}
    append(journal, {**base, "status": "intent", "time": now(), "before": before})
    try:
        result = bb(args, project)
    except RuntimeError as err:
        status = "failed" if rejected(getattr(err, "stdout", None)) else "uncertain"
        append(journal, {**base, "status": status, "time": now(), "error": str(err)})
        raise
    append(journal, {**base, "status": "done", "time": now(), "result": result})
    return result


def write(a):
    cmd = a.args[1:] if a.args and a.args[0] == "--" else a.args
    if not cmd or cmd[0] not in ("add", "update", "forget"):
        sys.exit("usage: memory.py write --op <id> [--project <id>] -- add|update|forget ...")
    print(json.dumps(journaled(a.journal, a.op, a.project, cmd), ensure_ascii=False))


def memory_id(entry):
    """The memory an op touched: the id for update/forget, the new id for a done add."""
    cmd = entry.get("command") or []
    if cmd and cmd[0] != "add":
        return (entry.get("before") or {}).get("id") or cmd[1]
    return ((entry.get("result") or {}).get("memory") or {}).get("id")


def undo(a):
    lines = journal_lines(a.journal)
    done = next((e for e in reversed(lines) if e.get("op") == a.op and e.get("status") == "done"), None)
    if not done:
        sys.exit(f"op {a.op} is not done; nothing to undo")
    intent = next((e for e in lines if e.get("op") == a.op and e.get("status") == "intent"), {})
    cmd, project, before = intent.get("command") or done.get("command"), intent.get("project"), intent.get("before")
    if not cmd:
        sys.exit(f"op {a.op} was resolved by hand and has no command; undo it by hand")
    reason = ["--reason", a.reason[:500]]
    if cmd[0] == "add":
        mid = memory_id(done)
        if not mid:  # resolved "done" after a crash: find it by scope and name
            scope = flag(cmd, "--scope")
            mid = next((m["id"] for m in catalog(scope, project if scope == "project" else None)
                        if m["name"] == flag(cmd, "--name")), None)
        if not mid:
            sys.exit(f"the memory added by {a.op} is already gone")
        cur = bb(["memory", "get", mid, "--json"], project)["memory"]
        inverse = ["forget", mid, "--expected-version", str(cur["version"]), *reason]
    elif cmd[0] == "update":
        cur = bb(["memory", "get", before["id"], "--json"], project)["memory"]
        inverse = ["update", before["id"], "--expected-version", str(cur["version"]), *reason,
                   "--summary", before["summary"], "--details", before.get("details", ""),
                   "--kind", before["kind"], "--importance", str(before["importance"])]
        if before.get("tags"):
            inverse += ["--tag", ",".join(before["tags"])]
    else:
        inverse = ["add", "--scope", before["scope"], "--name", before["name"], "--summary", before["summary"],
                   "--details", before.get("details", ""), "--kind", before["kind"],
                   "--importance", str(before["importance"]), *reason]
        if before.get("tags"):
            inverse += ["--tag", ",".join(before["tags"])]
    print(json.dumps(journaled(a.journal, f"{a.op}:undo", project, inverse), ensure_ascii=False))


def history(a):
    ops = {}
    for e in journal_lines(a.journal):
        o = ops.setdefault(e["op"], {"op": e["op"]})
        if e.get("command"):
            o.update(action=e["command"][0], project=e.get("project"),
                     name=flag(e["command"], "--name") or (e.get("before") or {}).get("name"))
        o.update(status=e.get("status"), time=e.get("time"))
        o["id"] = memory_id(e) or o.get("id")
    for o in ops.values():
        if a.since and (o.get("time") or "") < a.since:
            continue
        if a.run and not o["op"].startswith(f"{a.run}:"):
            continue
        print(json.dumps(o, ensure_ascii=False))


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
    journal = os.path.join(os.path.expanduser(os.environ.get("DREAMING_HOME", "~/.bb/dreaming")), "journal.jsonl")
    w = sub.add_parser("write")
    w.add_argument("--op", required=True)
    w.add_argument("--project")
    pe = sub.add_parser("pending")
    ck = sub.add_parser("check")
    ck.add_argument("--op", required=True)
    rs = sub.add_parser("resolve")
    rs.add_argument("--op", required=True)
    rs.add_argument("--status", required=True, choices=["done", "failed"])
    rs.add_argument("--note", required=True)
    un = sub.add_parser("undo")
    un.add_argument("--op", required=True)
    un.add_argument("--reason", required=True)
    hi = sub.add_parser("history")
    hi.add_argument("--since")
    hi.add_argument("--run")
    for sp in (w, pe, ck, rs, un, hi):
        sp.add_argument("--journal", default=journal)
    w.add_argument("args", nargs=argparse.REMAINDER)
    a = p.parse_args()
    try:
        {"dump": dump, "write": write, "pending": pending, "check": check, "resolve": resolve,
         "undo": undo, "history": history}[a.cmd](a)
    except RuntimeError as err:
        print(f"error: {err}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

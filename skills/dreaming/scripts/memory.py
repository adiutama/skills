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
         forget, and flushes it to disk before touching memory. An add whose name
         is already taken is refused before the intent.
      3. Runs the write, then appends "done", "failed" (bb rejected it: version
         conflict, not found, invalid input, so nothing changed), or "uncertain"
         (any other error: it may have been applied).
      Every change therefore has its undo record before it happens.
      Refuses --pinned and any update or forget of a pinned memory.

  memory.py pending
      Unresolved ops, one JSON per line: an intent with no outcome (a run crashed
      mid-write) or an uncertain outcome. Check each memory before resolving it.

  memory.py check --op <op id>
      For an unresolved op's latest attempt: the memory before, the memory now, and
      a hint whether it happened. An add counts as done only if a memory with its
      name was created after the intent with the intended text (and the name was
      free before); then check prints its id. Read errors other than bb's
      not-found exit 1 and leave the op unresolved.

  memory.py resolve --op <op id> --status done|failed --note <what you checked> [--id <mem id>]
      Records the outcome of an unresolved op after checking the memory. An add
      resolved as done needs --id, which is verified and recorded for undo.

  memory.py undo --op <op id> --reason <why>
      Reverses a done op as a new journaled op "<op id>:undo", using the attempt
      that succeeded: an add is forgotten, an update restored to the memory as it
      was, a forget added back (new id). Based on the version the op produced, so
      bb refuses if the memory changed since. Refuses an update that added tags to
      a memory that had none (bb cannot clear tags).

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
    """Parsed journal entries. A torn last line (a crash mid-append) is skipped with a
    warning, so the intent before it stays unresolved; a bad line anywhere else stops."""
    if not os.path.exists(path):
        return []
    with open(path) as f:
        lines = f.read().split("\n")
    out = []
    for i, line in enumerate(lines):
        if not line.strip():
            continue
        try:
            out.append(json.loads(line))
        except ValueError:
            if any(rest.strip() for rest in lines[i + 1:]):
                raise RuntimeError(f"{path} line {i + 1} is corrupt; repair it by hand before any memory write")
            print(f"warning: skipping a torn last journal line (crash mid-append): {line[:80]}", file=sys.stderr)
    return out


def append(path, entry):
    """Append one entry durably. A torn tail is moved to <journal>.torn-<time> first,
    so it never ends up in the middle of the journal."""
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "a+b") as f:
        f.seek(0, os.SEEK_END)
        size = f.tell()
        if size:
            f.seek(0)
            data = f.read()
            keep = data.rfind(b"\n") + 1
            tail = data[keep:]
            if tail:
                try:
                    json.loads(tail)  # a whole record that only lacks its newline
                    f.write(b"\n")
                except ValueError:
                    with open(f"{path}.torn-{int(dt.datetime.now().timestamp())}", "wb") as t:
                        t.write(tail)
                    f.truncate(keep)
        f.seek(0, os.SEEK_END)
        f.write((json.dumps(entry, ensure_ascii=False) + "\n").encode())
        f.flush()
        os.fsync(f.fileno())


def now():
    return dt.datetime.now().astimezone().isoformat(timespec="seconds")


def bb_message(err):
    """The message of bb's structured {"ok": false} reply, or None."""
    try:
        reply = json.loads(getattr(err, "stdout", None) or "")
    except (TypeError, ValueError):
        return None
    return (reply.get("error") or {}).get("message") if isinstance(reply, dict) and reply.get("ok") is False else None


# bb's own refusals, checked before anything is stored. Only a structured
# {"ok": false} reply whose message matches one of these counts as "failed";
# any other error may have happened after the write, so it is "uncertain".
NOT_FOUND = re.compile(r'^memory "[^"]+" was not found in the current scope$')
REJECTED = [re.compile(p) for p in (
    r"^version conflict for mem_\S+: expected \d+, current \d+$",
    NOT_FOUND.pattern,
    r'^an active (global|project) memory named "[^"]+" already exists$',
    r"^name must be ",
)]


def rejected(err):
    msg = bb_message(err) or ""
    return any(p.match(msg) for p in REJECTED)


def get_or_none(ref, project, scope=None):
    """The memory, or None only when bb says it was not found. Any other error is raised."""
    args = ["memory", "get", ref, "--json"] + (["--scope", scope] if scope else [])
    try:
        return bb(args, project)["memory"]
    except RuntimeError as err:
        if NOT_FOUND.match(bb_message(err) or ""):
            return None
        raise


def entries(path, op):
    return [e for e in journal_lines(path) if e.get("op") == op]


def op_state(path, op):
    """Last status of an op: None (never seen), intent, done, failed, uncertain."""
    es = entries(path, op)
    return es[-1].get("status") if es else None


def last_intent(es):
    """The intent of the latest attempt: every outcome belongs to the intent before it."""
    return next((e for e in reversed(es) if e.get("status") == "intent"), None)


def flag(cmd, name):
    return cmd[cmd.index(name) + 1] if name in cmd and cmd.index(name) + 1 < len(cmd) else None


def journaled(journal, op, project, cmd):
    """Run one memory write with its journal entries; returns bb's reply."""
    if "--pinned" in cmd:
        sys.exit("refused: dreaming never pins a memory")
    es = entries(journal, op)
    state = es[-1].get("status") if es else None
    if state == "done":
        return {"ok": True, "skipped": "already applied", "op": op}
    if state in ("intent", "uncertain"):
        print(f"error: op {op} is unresolved; check the memory, then run resolve", file=sys.stderr)
        sys.exit(3)
    before = None
    if cmd[0] == "add":
        # Proves later that a memory with this name was created by this attempt.
        scope = flag(cmd, "--scope")
        if get_or_none(flag(cmd, "--name"), project if scope == "project" else None, scope):
            sys.exit(f"refused: a {scope} memory named {flag(cmd, '--name')} already exists; update it or pick another name")
    else:
        before = bb(["memory", "get", cmd[1], "--json"], project)["memory"]
        if before.get("pinned"):
            sys.exit(f"refused: {before['name']} is pinned; suggest the change in the report instead")
    args = ["memory", *cmd]
    if "--json" not in args:
        args.append("--json")
    base = {"op": op, "project": project, "command": cmd}
    attempt = sum(1 for e in es if e.get("status") == "intent") + 1
    append(journal, {**base, "status": "intent", "attempt": attempt, "time": now(),
                     "timeMs": int(dt.datetime.now().timestamp() * 1000), "before": before,
                     **({"nameFree": True} if cmd[0] == "add" else {})})
    try:
        result = bb(args, project)
    except RuntimeError as err:
        status = "failed" if rejected(err) else "uncertain"
        append(journal, {**base, "status": status, "attempt": attempt, "time": now(), "error": str(err)})
        raise
    append(journal, {**base, "status": "done", "attempt": attempt, "time": now(), "result": result})
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


def matches(cmd, mem):
    """Whether a memory holds what the command wrote (the fields the command sets)."""
    for opt, key in (("--summary", "summary"), ("--details", "details"), ("--kind", "kind")):
        if flag(cmd, opt) is not None and flag(cmd, opt) != mem.get(key):
            return False
    if flag(cmd, "--importance") is not None and int(flag(cmd, "--importance")) != mem.get("importance"):
        return False
    return True


def undo(a):
    es = entries(a.journal, a.op)
    di = next((i for i in range(len(es) - 1, -1, -1) if es[i].get("status") == "done"), None)
    if di is None:
        sys.exit(f"op {a.op} is not done; nothing to undo")
    done, intent = es[di], last_intent(es[:di])
    if not intent:
        sys.exit(f"op {a.op} has no intent; undo it by hand")
    cmd, project, before = intent["command"], intent.get("project"), intent.get("before")
    after = (done.get("result") or {}).get("memory") or {}
    reason = ["--reason", a.reason[:500]]
    if cmd[0] == "add":
        mid = memory_id(done)
        if not mid:
            sys.exit(f"op {a.op} has no recorded memory id; undo it by hand")
        cur = get_or_none(mid, project)
        if cur is None:
            sys.exit(f"the memory added by {a.op} ({mid}) is already gone")
        # Expected version = the one the op produced, so later edits make bb refuse.
        inverse = ["forget", mid, "--expected-version", str(after.get("version") or cur["version"]), *reason]
    elif cmd[0] == "update":
        cur = bb(["memory", "get", before["id"], "--json"], project)["memory"]
        if not before.get("tags") and cur.get("tags"):
            sys.exit(f"refused: {before['name']} had no tags before and bb cannot clear tags; restore it by hand")
        inverse = ["update", before["id"], "--expected-version", str(after.get("version") or cur["version"]), *reason,
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


def inspect(intent):
    """(memory now, hint, id to record) for an unresolved attempt. Raises on read errors."""
    cmd, project = intent["command"], intent.get("project")
    if cmd[0] == "add":
        scope, name = flag(cmd, "--scope"), flag(cmd, "--name")
        now_ = get_or_none(name, project if scope == "project" else None, scope)
        if now_ is None:
            return None, "absent → the add did not happen (failed)", None
        created_after = now_.get("createdAt", 0) >= intent.get("timeMs", float("inf"))
        if intent.get("nameFree") and matches(cmd, now_) and created_after:
            return now_, "created after the intent with the intended text → done", now_["id"]
        return now_, "a memory with this name exists but is not provably this add; check by hand", None
    now_ = get_or_none(cmd[1], project)
    was = (intent.get("before") or {}).get("version")
    if cmd[0] == "forget":
        if now_ is None:
            return None, "gone → done", None
        if now_["version"] == was:
            return now_, f"still at v{was} → failed", None
        return now_, "changed since; check by hand", None
    if now_ is None:
        return None, "memory gone; check by hand", None
    if now_["version"] == was:
        return now_, f"still v{was} → failed", None
    if now_["version"] == was + 1 and matches(cmd, now_):
        return now_, f"v{now_['version']} holds the intended text → done", None
    return now_, "newer version; compare it with the command to decide", None


def check(a):
    """Show what memory looks like now for an unresolved op, so it can be resolved."""
    es = entries(a.journal, a.op)
    intent = last_intent(es)
    if not intent or es[-1].get("status") not in ("intent", "uncertain"):
        sys.exit(f"op {a.op} is not unresolved")
    now_, hint, mid = inspect(intent)
    print(json.dumps({"op": a.op, "attempt": intent.get("attempt"), "command": intent["command"],
                      "before": intent.get("before"), "now": now_, "hint": hint,
                      **({"id": mid} if mid else {})}, ensure_ascii=False, indent=1))


def resolve(a):
    es = entries(a.journal, a.op)
    if not es or es[-1].get("status") not in ("intent", "uncertain"):
        sys.exit(f"op {a.op} is not unresolved")
    intent = last_intent(es)
    entry = {"op": a.op, "status": a.status, "attempt": intent.get("attempt"), "time": now(),
             "resolved": True, "note": a.note}
    if a.status == "done":
        cmd, project = intent["command"], intent.get("project")
        if cmd[0] == "add":
            if not a.id:
                sys.exit("resolving an add as done needs --id <the memory it created> (from check)")
            mem = get_or_none(a.id, project)
            if not mem or mem["name"] != flag(cmd, "--name") or not matches(cmd, mem):
                sys.exit(f"{a.id} is not the memory this add would have created; leave the op unresolved")
            entry["result"] = {"memory": mem}
        elif cmd[0] == "update":
            entry["result"] = {"memory": get_or_none(cmd[1], project)}
    append(a.journal, entry)
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
    rs.add_argument("--id", help="for an add resolved as done: the memory it created")
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

#!/usr/bin/env python3
"""Idempotent run control for dreaming.

  dream.py begin  <run>   lock the run, then collect (or reuse) its batches; prints status
  dream.py lock   <run>   lock only (deep sleep reads no threads); prints status
  dream.py status <run>   print status: batches, which steps are done, config, guard
  dream.py commit <run>   after the log is written: advance state.json (max-merge), mark committed
  dream.py record <run> --memories <n>
                          after applying: store the memory count and this run's journaled
                          writes in state.json (the bloat guard reads them)
  dream.py reconcile <run>
                          before applying: give log items without an op their op id, and mark
                          every `proposed` item with no journal history that already took
                          effect as `applied` (legacy logs, or a crash before the write was
                          journaled). One atomic save; safe to repeat.
  dream.py backlog <run>  after applying: rebuild backlog.json from the run's log. Items are
                          keyed by scope + projectId + name; every key in the log is replaced
                          by the log's deferred, backlog and failed items. Safe to repeat.
  dream.py release <run>  drop the lock

state.json only moves forward in `commit`, so a run that fails before then can
be re-run and sees the same messages. A rerun reuses the run's batches; if a
later run committed meanwhile, the stale batches are discarded and re-collected.
Exit 3 from begin/lock: another live attempt holds the lock.
"""
import glob, importlib.util, json, os, shutil, subprocess, sys, time

HOME = os.path.expanduser(os.environ.get("DREAMING_HOME", "~/.bb/dreaming"))  # data, not code
STATE = os.path.join(HOME, "state.json")
CONFIG = os.path.join(HOME, "config.json")
JOURNAL = os.path.join(HOME, "journal.jsonl")
BATCHES = os.path.join(HOME, "batches")
BACKLOG_STATUSES = ("deferred", "backlog", "failed")
BATCH_BYTES = 100_000
MAX_THREAD_BYTES = 40_000  # one thread block; longer threads are split into parts
FIRST_RUN_LOOKBACK_MS = 24 * 3600 * 1000
LOCK_MAX_AGE_S = 3 * 3600
KEEP_RUN_STATS = 60
DEFAULTS = {
    "mode": "apply",               # apply | propose (emergency brake: logs only); only the user changes it
    "scannerModel": "claude-haiku-5-5",
    "judgeModel": "claude-opus-5-5",
    "keepBatchesDays": 14,
    "addsPerRun": 10,              # bloat guard: adds beyond this in one run wait in the backlog
    "memoryLimit": 200,            # bloat guard: at or above this store size, new adds wait
    "forgetAlert": 5,              # a run forgetting more than this is flagged in the report
    "unusedMinAgeDays": 28,        # deep sleep: a memory younger than this is never "unused"
    "unusedWeeks": 8,              # deep sleep: no thread updated in this many weeks mentions it
    "backlogMaxRuns": 4,           # drop a backlog item after this many runs with no new evidence
}


def bb(*args):
    out = subprocess.run(["bb", *args], capture_output=True, text=True, check=True).stdout
    return json.loads(out)


def read_json(path, default=None):
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def write_json(path, data):
    tmp = f"{path}.tmp-{os.getpid()}"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=1)
    os.replace(tmp, path)


def load_config():
    return {**DEFAULTS, **(read_json(CONFIG) or {})}


def load_state():
    return read_json(STATE) or {
        "cursorMs": int(time.time() * 1000) - FIRST_RUN_LOOKBACK_MS, "lastSeq": {}, "dreamThreads": []}


def state_committed(state, run):
    """Whether state.json already holds this run's cursor (lastCommittedRun covers older state files)."""
    return run in state.get("committedRuns", []) or state.get("lastCommittedRun") == run


def register_me(state):
    me = os.environ.get("BB_THREAD_ID")
    if me and me not in state.setdefault("dreamThreads", []):
        state["dreamThreads"] = (state["dreamThreads"] + [me])[-120:]
        write_json(STATE, state)
    return me


_mem = None


def mem():
    """memory.py from this folder (python3 -I does not put it on sys.path)."""
    global _mem
    if _mem is None:
        spec = importlib.util.spec_from_file_location(
            "dreaming_memory", os.path.join(os.path.dirname(os.path.abspath(__file__)), "memory.py"))
        _mem = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_mem)
    return _mem


def run_ops(run):
    """Final status per journaled op of this run: {op: (action, status)}."""
    ops = {}
    for e in mem().journal_lines(JOURNAL):
        if e.get("op", "").startswith(f"{run}:"):
            action = (e.get("command") or [None])[0] or ops.get(e["op"], (None,))[0]
            ops[e["op"]] = (action, e.get("status"))
    return ops


def write_counts(run):
    counts = {}
    for action, st in run_ops(run).values():
        key = action if st == "done" else st
        counts[key] = counts.get(key, 0) + 1
    return counts


# ---------- lock ----------

def lock_path(run):
    return os.path.join(BATCHES, f"{run}.lock")


def holder_alive(lock):
    if time.time() - lock.get("at", 0) > LOCK_MAX_AGE_S:
        return False
    tid = lock.get("thread")
    if not tid or tid == os.environ.get("BB_THREAD_ID"):
        return False
    try:
        return bb("thread", "show", tid, "--json")["thread"]["status"] == "active"
    except Exception:
        return False


def take_lock(run):
    os.makedirs(BATCHES, exist_ok=True)
    path = lock_path(run)
    lock = read_json(path)
    if lock and holder_alive(lock):
        print(json.dumps({"run": run, "locked": True, "holder": lock["thread"],
                          "hint": "another attempt is still running; stop"}))
        sys.exit(3)
    write_json(path, {"thread": os.environ.get("BB_THREAD_ID"), "at": time.time()})


# ---------- collect ----------

def events_after(tid, after):
    evs, cur = [], after
    while True:
        page = bb("thread", "log", tid, "--json", "--limit", "500", "--after-seq", str(cur))
        if not page:
            return evs
        evs += page
        cur = page[-1]["seq"]
        if len(page) < 500:
            return evs


def conversation(evs):
    """One string per message, oldest first."""
    msgs = []
    for e in evs:
        d = e.get("data") or {}
        if e["type"] == "client/turn/requested" and d.get("initiator") == "user":
            who = "AGENT:" + d["senderThreadId"] if d.get("senderThreadId") else "USER"
            text = "\n".join(i.get("text", "") for i in d.get("input", []) if i.get("type") == "text")
            if text.strip():
                msgs.append(f"## {who} (seq {e['seq']})\n{text.strip()}")
        elif e["type"] == "item/completed":
            it = d.get("item", d)
            if it.get("type") == "agentMessage" and it.get("text", "").strip():
                msgs.append(f"## ASSISTANT (seq {e['seq']})\n{it['text'].strip()}")
    return msgs


def chunks(msgs, limit=MAX_THREAD_BYTES):
    """Group messages into chunks of at most `limit` chars; a longer message is cut
    into parts. Nothing is dropped, so every new message reaches a scanner."""
    out, cur, size = [], [], 0
    for m in msgs:
        parts = [m] if len(m) <= limit else [
            f"{m[:m.index(chr(10))]} [part {i + 1}/{-(-len(m) // limit)}]\n{m[j:j + limit]}"
            for i, j in enumerate(range(0, len(m), limit))]
        for part in parts:
            if cur and size + len(part) > limit:
                out.append("\n\n".join(cur)); cur, size = [], 0
            cur.append(part); size += len(part) + 2
    if cur:
        out.append("\n\n".join(cur))
    return out


def collect(run, state, me):
    now = int(time.time() * 1000)
    projects = {p["id"]: p.get("name") for p in bb("project", "list", "--include-personal", "--json")}
    skip = set(state.get("dreamThreads", [])) | {me}
    threads = [t for t in bb("thread", "list", "--json")
               if t["updatedAt"] > state["cursorMs"]
               and t["id"] not in skip and t.get("parentThreadId") not in skip
               and not (t.get("title") or "").lower().startswith("dream")]
    final = os.path.join(BATCHES, run)
    work = f"{final}.tmp-{os.getpid()}"
    os.makedirs(work)
    batches, cur, size, seen, new_seq = [], [], 0, [], {}
    for t in threads:
        evs = events_after(t["id"], state["lastSeq"].get(t["id"], 0))
        if not evs:
            continue
        new_seq[t["id"]] = evs[-1]["seq"]
        parts = chunks(conversation(evs))
        for k, text in enumerate(parts, 1):
            more = f" | part {k}/{len(parts)}" if len(parts) > 1 else ""
            block = (f"# THREAD {t['id']} | project {t['projectId']} ({projects.get(t['projectId'])}) "
                     f"| title: {t.get('title')}{more}\n{text}\n\n")
            if cur and size + len(block) > BATCH_BYTES:
                batches.append(cur); cur, size = [], 0
            cur.append(block); size += len(block)
        if parts:
            seen.append(t["id"])
    if cur:
        batches.append(cur)
    names = []
    for i, b in enumerate(batches, 1):
        name = f"batch-{i:02d}.md"
        with open(os.path.join(work, name), "w") as f:
            f.write("".join(b))
        names.append(name)
    manifest = {"run": run, "createdAt": now, "baseCursorMs": state["cursorMs"],
                "pending": {"cursorMs": now, "lastSeq": new_seq},
                "threads": seen, "batches": names, "committed": False}
    write_json(os.path.join(work, "manifest.json"), manifest)
    if os.path.exists(final):  # stale or legacy dir without a usable manifest
        shutil.move(final, f"{final}.stale-{int(time.time())}")
    os.rename(work, final)
    return manifest


def status(run, manifest):
    d = os.path.join(BATCHES, run)
    manifest = manifest or {}
    done = {}
    for b in manifest.get("batches", []):
        c = os.path.join(d, b.replace("batch-", "candidates-").replace(".md", ".json"))
        done[b] = read_json(c) is not None
    log = read_json(os.path.join(HOME, "logs", f"{run}.json"))
    cfg, state = load_config(), load_state()
    counts = write_counts(run)
    dump = os.path.join(d, "memory.md")
    return {"run": run, "dir": d, "batches": [os.path.join(d, b) for b in manifest.get("batches", [])],
            "threads": len(manifest.get("threads", [])), "scanned": done,
            "memoryDump": dump if os.path.exists(dump) and os.path.getsize(dump) > 0 else None,
            "logWritten": log is not None, "committed": manifest.get("committed", False),
            "config": cfg,
            "guard": {"memoryCount": state.get("memoryCount"), "addsDone": counts.get("add", 0),
                      "addsPerRun": cfg["addsPerRun"], "memoryLimit": cfg["memoryLimit"]},
            "writes": counts}


def begin(run):
    take_lock(run)
    state = load_state()
    me = register_me(state)
    mpath = os.path.join(BATCHES, run, "manifest.json")
    manifest = read_json(mpath)
    if manifest and not manifest["committed"] and state_committed(state, run):
        manifest["committed"] = True  # crashed between state.json and the manifest: finish the commit
        write_json(mpath, manifest)
    if manifest and not manifest["committed"] and state["cursorMs"] > manifest["baseCursorMs"]:
        manifest = None  # a later run committed after this one collected: re-collect
    if manifest is None:
        for ext in ("json", "md"):  # a log from an older collection no longer matches
            old = os.path.join(HOME, "logs", f"{run}.{ext}")
            if os.path.exists(old):
                shutil.move(old, os.path.join(HOME, "logs", f"{run}.superseded-{int(time.time())}.{ext}"))
        manifest = collect(run, state, me)
    print(json.dumps(status(run, manifest), indent=1))


def lock(run):
    take_lock(run)
    register_me(load_state())
    os.makedirs(os.path.join(BATCHES, run), exist_ok=True)
    print(json.dumps(status(run, None), indent=1))


def commit(run):
    path = os.path.join(BATCHES, run, "manifest.json")
    manifest = read_json(path)
    if manifest is None:
        sys.exit(f"no manifest for {run}")
    if manifest["committed"]:
        print(json.dumps({"run": run, "committed": True, "alreadyCommitted": True})); return
    if read_json(os.path.join(HOME, "logs", f"{run}.json")) is None:
        sys.exit(f"logs/{run}.json missing or invalid; write the log before committing")
    state = load_state()
    if not state_committed(state, run):
        # One atomic state.json write records the cursor and that this run committed,
        # so a crash before the manifest below is finished by the next begin/commit.
        p = manifest["pending"]
        state["cursorMs"] = max(state["cursorMs"], p["cursorMs"])
        for tid, seq in p["lastSeq"].items():
            state["lastSeq"][tid] = max(state["lastSeq"].get(tid, 0), seq)
        state["lastCommittedRun"] = run
        state["committedRuns"] = (state.get("committedRuns", []) + [run])[-KEEP_RUN_STATS:]
        write_json(STATE, state)
    manifest["committed"] = True
    write_json(path, manifest)
    print(json.dumps({"run": run, "committed": True}))


def record(run, memories):
    state = load_state()
    state["memoryCount"] = memories
    runs = state.setdefault("runs", {})
    runs[run] = {"at": int(time.time() * 1000), "memories": memories, "writes": write_counts(run)}
    state["runs"] = dict(sorted(runs.items(), key=lambda kv: kv[1]["at"])[-KEEP_RUN_STATS:])
    write_json(STATE, state)
    print(json.dumps({"run": run, **runs[run]}))


def log_path(run):
    return os.path.join(HOME, "logs", f"{run}.json")


def tags_of(value):
    if isinstance(value, str):
        value = value.split(",")
    return sorted(t.strip() for t in (value or []) if t.strip())


def holds(item, cur):
    """Whether a memory already holds every field the proposal sets."""
    if item.get("scope") is not None and cur.get("scope") != item["scope"]:
        return False
    if item.get("scope") == "project" and item.get("projectId") and cur.get("projectId") != item["projectId"]:
        return False
    for k in ("summary", "details", "kind"):
        if item.get(k) is not None and cur.get(k) != item[k]:
            return False
    if item.get("importance") is not None and cur.get("importance") != int(item["importance"]):
        return False
    if item.get("tags") is not None and tags_of(cur.get("tags")) != tags_of(item["tags"]):
        return False
    return True


SETS = ("summary", "details", "kind", "tags", "importance")


def took_effect(item):
    """The memory id if a proposal is already true in memory, else None. Every field the
    proposal sets must match, or it stays proposed. Read errors other than bb's
    not-found are raised, so nothing is saved on a partial pass."""
    m = mem()
    project = item.get("projectId") if item.get("scope") == "project" else None
    if item["action"] == "add":
        cur = m.get_or_none(item["name"], project, item.get("scope"))
        return cur["id"] if cur and holds(item, cur) else None
    if not item.get("id"):
        return None
    cur = m.get_or_none(item["id"], project)
    if item["action"] == "forget":
        return item["id"] if cur is None else None
    sets_something = any(item.get(k) is not None for k in SETS)
    return cur["id"] if cur and sets_something and holds(item, cur) else None


def reconcile(run):
    items = read_json(log_path(run))
    if items is None:
        sys.exit(f"logs/{run}.json missing or invalid")
    journaled = {e.get("op") for e in mem().journal_lines(JOURNAL)}
    changed = []
    for idx, item in enumerate(items, 1):
        if not item.get("op"):
            item["op"] = f"{run}:{item.get('n', idx)}:{item['action']}:{item['name']}"
            changed.append(item["op"])
        if item.get("status") != "proposed" or item["op"] in journaled:
            continue
        mid = took_effect(item)
        if mid:
            item.update(status="applied", memoryId=mid, reconciled=True)
            changed.append(item["op"])
    if changed:
        write_json(log_path(run), items)  # op ids and reconciled statuses land together
    print(json.dumps({"run": run, "changed": sorted(set(changed)),
                      "applied": [i["op"] for i in items if i.get("reconciled")]}))


def backlog_key(item):
    scope = item.get("scope")
    return (scope, item.get("projectId") if scope == "project" else None, item.get("name"))


def backlog(run):
    items = read_json(log_path(run))
    if items is None:
        sys.exit(f"logs/{run}.json missing or invalid")
    keys = {backlog_key(i) for i in items}
    kept = [b for b in (read_json(os.path.join(HOME, "backlog.json")) or []) if backlog_key(b) not in keys]
    added = []
    for i in items:
        if i.get("status") in BACKLOG_STATUSES:
            entry = {k: v for k, v in i.items() if k not in ("n", "op", "status")}
            entry.update(why=i["status"], since=i.get("since", run), waited=i.get("waited", 0), lastRun=run)
            added.append(entry)
    write_json(os.path.join(HOME, "backlog.json"), kept + added)
    print(json.dumps({"run": run, "backlog": len(kept) + len(added), "fromLog": len(added)}))


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    cmd, run = sys.argv[1], sys.argv[2]
    if cmd == "begin":
        begin(run)
    elif cmd == "lock":
        lock(run)
    elif cmd == "commit":
        commit(run)
    elif cmd == "record":
        if len(sys.argv) != 5 or sys.argv[3] != "--memories":
            sys.exit("usage: dream.py record <run> --memories <n>")
        record(run, int(sys.argv[4]))
    elif cmd == "reconcile":
        reconcile(run)
    elif cmd == "backlog":
        backlog(run)
    elif cmd == "release":
        lp = lock_path(run)
        if os.path.exists(lp):
            os.remove(lp)
    elif cmd == "status":
        m = read_json(os.path.join(BATCHES, run, "manifest.json"))
        print(json.dumps({**status(run, m), "collected": m is not None}, indent=1))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()

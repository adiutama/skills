#!/usr/bin/env python3
"""Collect one calendar day of the user's prompts across all bb threads.

  collect-day.py pending --home <dir> [--since YYYY-MM-DD] [--window 7] [--max 3] [--tz Area/City]
      Days to process, oldest first, one per line, at most --max: every day before
      today with no <home>/days/<day>.md yet, starting the day after the oldest
      day file (or --since, or --window days ago when there are none). No day is
      dropped after an outage; later runs catch up. Empty output = nothing to do.

  collect-day.py keys --home <dir>
      Signal keys seen so far, derived from the Signals tables of every day file:
      key, days seen, first and last day, latest scope and evidence. Always
      current, so there is no registry to keep in sync.

  collect-day.py digest <YYYY-MM-DD> [--tz Area/City] [--reply-chars 600] [--prompt-chars 1500]
      Markdown digest of that day on stdout: every prompt the user typed, grouped
      by thread, each with the tail of the agent message it answered.

Run with `python3 -I`. Needs the bb CLI. Thread data never leaves this machine.
"""
import argparse
import datetime as dt
import json
import os
import subprocess
import sys
from zoneinfo import ZoneInfo

# Automation prompts arrive as user spawn prompts; relayed messages are also
# caught by senderThreadId, the prefix is a second guard.
SKIP_PREFIXES = ("[bb message from thread", "[bb automation")


def bb(*args, env=None):
    out = subprocess.run(["bb", *args], capture_output=True, text=True, env=env)
    if out.returncode != 0:
        raise RuntimeError(f"bb {' '.join(args)}: {out.stderr.strip() or out.stdout.strip()}")
    return json.loads(out.stdout)


def tz_of(name):
    if name:
        return ZoneInfo(name)
    link = os.path.realpath("/etc/localtime")
    if "zoneinfo/" in link:
        return ZoneInfo(link.split("zoneinfo/", 1)[1])
    raise RuntimeError("cannot tell this machine's timezone; pass --tz <Area/City>")


def day_bounds(day, tz):
    start = dt.datetime.combine(day, dt.time(), tzinfo=tz)
    end = start + dt.timedelta(days=1)
    return int(start.timestamp() * 1000), int(end.timestamp() * 1000)


def pending(a):
    tz = tz_of(a.tz)
    today = dt.datetime.now(tz).date()
    days_dir = os.path.join(os.path.expanduser(a.home), "days")
    done = sorted(
        dt.date.fromisoformat(f[:-3])
        for f in (os.listdir(days_dir) if os.path.isdir(days_dir) else [])
        if len(f) == 13 and f.endswith(".md")
    )
    if a.since:
        first = dt.date.fromisoformat(a.since)
    elif done:
        first = done[0]
    else:
        first = today - dt.timedelta(days=a.window)
    todo = []
    d = first
    while d < today:
        if not os.path.exists(os.path.join(days_dir, f"{d.isoformat()}.md")):
            todo.append(d.isoformat())
        d += dt.timedelta(days=1)
    print("\n".join(todo[: a.max]))


def keys(a):
    days_dir = os.path.join(os.path.expanduser(a.home), "days")
    seen = {}
    files = sorted(f for f in (os.listdir(days_dir) if os.path.isdir(days_dir) else []) if len(f) == 13 and f.endswith(".md"))
    for f in files:
        day, in_table = f[:-3], False
        with open(os.path.join(days_dir, f)) as fh:
            for line in fh:
                if line.startswith("## "):
                    in_table = line.strip() == "## Signals"
                    continue
                cells = [c.strip() for c in line.strip().strip("|").split("|")]
                if not in_table or not line.startswith("|") or len(cells) < 3 or cells[0] in ("key", "") or set(cells[0]) <= set("-: "):
                    continue
                k = cells[0].strip("`")
                e = seen.setdefault(k, {"days": [], "scope": "", "evidence": ""})
                if day not in e["days"]:
                    e["days"].append(day)
                e["scope"], e["evidence"] = cells[1], cells[2]
    print("| key | days seen | first | last | scope | latest evidence |\n|---|---|---|---|---|---|")
    for k in sorted(seen):
        e = seen[k]
        print(f"| {k} | {len(e['days'])} | {e['days'][0]} | {e['days'][-1]} | {e['scope']} | {clip(e['evidence'], 160)} |")


def text_of(entry):
    parts = []
    for item in entry.get("input", []):
        if item.get("type") == "text":
            parts.append(item.get("text", ""))
        else:
            parts.append("[image]" if "image" in item.get("type", "").lower() else f"[{item.get('type')}]")
    return " ".join(p for p in parts if p).strip()


def clip(s, n, tail=False):
    s = " ".join(s.split())
    if len(s) <= n:
        return s
    return "…" + s[-n:] if tail else s[:n] + "…"


HISTORY_CAP = 50


def norm(txt):
    return " ".join(txt.split())


def turns(thread):
    """(user prompts, agent messages) for one thread.

    Two sources, because neither is complete alone:
    - `thread history` holds exactly the prompts the user typed (no automation
      prompts, worker briefs, or briefs of threads an agent started), but only
      the newest 50.
    - the event log holds every prompt ever sent, but cannot tell a typed prompt
      from the brief of a thread an agent started with no parent.
    Where history reaches, a log prompt counts only if history has it. Older
    than that, only follow-up prompts count: sent by the user, from no other
    thread, not a thread's opening (spawn) prompt, not an automation.
    """
    hist = bb("thread", "history", thread["id"], "--json", "--limit", str(HISTORY_CAP))
    typed = {norm(text_of(h)) for h in hist}
    reach = min((h["createdAt"] for h in hist), default=None) if len(hist) >= HISTORY_CAP else float("-inf")
    events = bb("thread", "log", thread["id"], "--json", "--limit", "1000000")
    prompts, msgs, gaps = [], [], []
    for e in events:
        data = e.get("data") or {}
        if e.get("type") == "client/turn/requested":
            if data.get("initiator") != "user" or data.get("senderThreadId"):
                continue
            txt = text_of(data)
            if not txt or txt.startswith(SKIP_PREFIXES):
                continue
            if e["createdAt"] >= reach - 60_000:
                if norm(txt) not in typed:
                    continue
            elif data.get("source") == "spawn":
                # Beyond history's reach a spawn prompt may be a brief an agent
                # wrote; the log can't tell. Drop it, and say so in the digest.
                gaps.append(e["createdAt"])
                continue
            prompts.append((e["createdAt"], txt))
        elif e.get("type") == "item/completed":
            item = data.get("item") or {}
            if item.get("type") == "agentMessage" and item.get("text"):
                msgs.append((e["createdAt"], item["text"]))
    return sorted(prompts), msgs, gaps


def digest(a):
    tz = tz_of(a.tz)
    day = dt.date.fromisoformat(a.day)
    start, end = day_bounds(day, tz)
    me = os.environ.get("BB_THREAD_ID")

    projects = {p["id"]: p.get("name") or p["id"] for p in bb("project", "list", "--include-personal", "--json")}
    threads = {t["id"]: t for t in bb("thread", "list", "--include-hidden", "--json")}
    for t in bb("thread", "list", "--archived", "--include-hidden", "--json"):
        threads.setdefault(t["id"], t)

    sections, n_prompts, errors = [], 0, []
    candidates = [t for t in threads.values() if t["updatedAt"] >= start and t["id"] != me]
    for t in sorted(candidates, key=lambda t: t["createdAt"]):
        try:
            prompts, replies, gaps = turns(t)
        except RuntimeError as err:
            errors.append(f"{t['id']}: {err}")
            continue
        prompts = [p for p in prompts if start <= p[0] < end]
        gap = any(start <= g < end for g in gaps)
        if not prompts and not gap:
            continue

        head = f"## {t.get('title') or '(untitled)'} · {projects.get(t['projectId'], t['projectId'])} · @thread:{t['id']}"
        if t.get("parentThreadId"):
            head += f" · worker of @thread:{t['parentThreadId']}"
        if t.get("archivedAt"):
            head += " · archived"
        if gap:
            head += " · opening prompt not shown (older than history keeps; may have been an agent's brief)"
        lines = [head]
        for ts, txt in prompts:
            before = [m for m in replies if m[0] < ts]
            when = dt.datetime.fromtimestamp(ts / 1000, tz).strftime("%H:%M")
            if before:
                lines.append(f"- agent before: {clip(before[-1][1], a.reply_chars, tail=True)}")
            lines.append(f"- **{when} user:** {clip(txt, a.prompt_chars)}")
        sections.append("\n".join(lines))
        n_prompts += len(prompts)

    if errors:
        raise RuntimeError("could not read every thread, so the day is incomplete:\n" + "\n".join(errors))
    print(f"# Day {a.day} ({tz}) · {len(sections)} threads · {n_prompts} prompts\n")
    if not sections:
        print("No activity.")
    print("\n\n".join(sections))


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    pe = sub.add_parser("pending")
    pe.add_argument("--home", required=True)
    pe.add_argument("--since")
    pe.add_argument("--window", type=int, default=7)
    pe.add_argument("--max", type=int, default=3)
    pe.add_argument("--tz")
    ke = sub.add_parser("keys")
    ke.add_argument("--home", required=True)
    di = sub.add_parser("digest")
    di.add_argument("day")
    di.add_argument("--tz")
    di.add_argument("--reply-chars", type=int, default=600)
    di.add_argument("--prompt-chars", type=int, default=1500)
    a = p.parse_args()
    try:
        {"pending": pending, "keys": keys, "digest": digest}[a.cmd](a)
    except RuntimeError as err:
        print(f"error: {err}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

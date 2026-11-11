# python3 -m unittest discover -s skills/dreaming/tests
"""Script tests with a fake bb: no real threads or memory are touched."""
import contextlib, copy, importlib.util, io, json, os, tempfile, unittest
from pathlib import Path
from types import SimpleNamespace as NS

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"


def load(name):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def quiet(fn, *a):
    out = io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
        fn(*a)
    return out.getvalue()


def bb_error(message):
    e = RuntimeError(message)
    e.stdout = json.dumps({"ok": False, "error": {"code": "command_failed", "message": message}})
    return e


BASE = dict(id="mem_test", name="rule", scope="global", projectId=None, version=1, summary="original",
            details="original detail", kind="procedure", importance=50, tags=[], pinned=False, createdAt=1)


class FakeStore:
    """bb memory get/add/update/forget over a dict of memories."""

    def __init__(self, m, *mems):
        self.mems = {x["id"]: copy.deepcopy(x) for x in mems}
        self.calls, self.m, self.next = [], m, 0

    def find(self, ref):
        return next((x for x in self.mems.values() if ref in (x["id"], x["name"])), None)

    def __call__(self, args, project=None):
        f = self.m.flag
        self.calls.append(args)
        verb = args[1]
        if verb == "get":
            mem = self.find(args[2])
            if not mem:
                raise bb_error(f'memory "{args[2]}" was not found in the current scope')
            return {"ok": True, "memory": copy.deepcopy(mem)}
        if verb == "add":
            self.next += 1
            mem = dict(BASE, id=f"mem_new{self.next}", name=f(args, "--name"), summary=f(args, "--summary"),
                       details=f(args, "--details"), tags=(f(args, "--tag") or "").split(",") if f(args, "--tag") else [],
                       version=1, createdAt=10**15)
            self.mems[mem["id"]] = mem
            return {"ok": True, "memory": copy.deepcopy(mem)}
        mem = self.find(args[2])
        if not mem:
            raise bb_error(f'memory "{args[2]}" was not found in the current scope')
        exp = int(f(args, "--expected-version"))
        if exp != mem["version"]:
            raise bb_error(f"version conflict for {mem['id']}: expected {exp}, current {mem['version']}")
        if verb == "forget":
            del self.mems[mem["id"]]
            return {"ok": True, "forgotten": {"id": mem["id"], "version": mem["version"] + 1}}
        for opt, key in (("--summary", "summary"), ("--details", "details"), ("--kind", "kind")):
            if f(args, opt) is not None:
                mem[key] = f(args, opt)
        if f(args, "--importance") is not None:
            mem["importance"] = int(f(args, "--importance"))
        if f(args, "--tag"):
            mem["tags"] = f(args, "--tag").split(",")
        mem["version"] += 1
        return {"ok": True, "memory": copy.deepcopy(mem)}


class Memory(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.j = str(Path(self.tmp.name) / "journal.jsonl")
        self.m = load("memory")

    def tearDown(self):
        self.tmp.cleanup()

    def test_undo_uses_the_attempt_that_succeeded(self):  # C1
        store = self.m.bb = FakeStore(self.m, BASE)
        op = "run:1:update:rule"
        with self.assertRaises(RuntimeError):
            self.m.journaled(self.j, op, None, ["update", "mem_test", "--expected-version", "0", "--reason", "t", "--summary", "nightly"])
        store.mems["mem_test"].update(version=2, summary="concurrent user correction")
        self.m.journaled(self.j, op, None, ["update", "mem_test", "--expected-version", "2", "--reason", "t", "--summary", "nightly merged"])
        quiet(self.m.undo, NS(journal=self.j, op=op, reason="undo"))
        self.assertEqual(store.mems["mem_test"]["summary"], "concurrent user correction")

    def test_undo_refuses_when_memory_changed_since(self):  # C1: undo never clobbers a later edit
        store = self.m.bb = FakeStore(self.m, BASE)
        op = "run:1:update:rule"
        self.m.journaled(self.j, op, None, ["update", "mem_test", "--expected-version", "1", "--reason", "t", "--summary", "dream"])
        store.mems["mem_test"].update(version=3, summary="user edit")
        with self.assertRaises(RuntimeError):
            quiet(self.m.undo, NS(journal=self.j, op=op, reason="undo"))
        self.assertEqual(store.mems["mem_test"]["summary"], "user edit")

    def test_add_with_taken_name_is_refused_before_intent(self):  # C2
        self.m.bb = FakeStore(self.m, BASE)
        with self.assertRaises(SystemExit):
            self.m.journaled(self.j, "run:4:add:rule", None, ["add", "--scope", "global", "--name", "rule", "--summary", "new"])
        self.assertFalse(Path(self.j).exists())

    def test_crashed_add_with_preexisting_name_is_not_done(self):  # C2
        self.m.bb = FakeStore(self.m, BASE)
        op = "run:4:add:rule"
        self.m.append(self.j, dict(op=op, status="intent", command=["add", "--scope", "global", "--name", "rule", "--summary", "new proposal"],
                                   project=None, before=None))  # legacy intent: no proof the name was free
        res = json.loads(quiet(self.m.check, NS(journal=self.j, op=op)))
        self.assertIn("check by hand", res["hint"])
        self.assertNotIn("id", res)
        with self.assertRaises(SystemExit):
            quiet(self.m.resolve, NS(journal=self.j, op=op, status="done", note="x", id=None))
        with self.assertRaises(SystemExit):  # the pre-existing memory is not what this add wrote
            quiet(self.m.resolve, NS(journal=self.j, op=op, status="done", note="x", id="mem_test"))
        self.assertEqual(self.m.op_state(self.j, op), "intent")

    def test_crashed_add_that_happened_resolves_with_its_id_and_undoes(self):  # C2
        store = self.m.bb = FakeStore(self.m)
        op, cmd = "run:5:add:fresh", ["add", "--scope", "global", "--name", "fresh", "--summary", "s", "--details", "d", "--reason", "r"]
        real_append = self.m.append

        def crash_after_intent(path, entry):
            real_append(path, entry)
            if entry["status"] == "done":
                raise KeyboardInterrupt  # outcome line lost: simulate by removing it below
        self.m.append = crash_after_intent
        with self.assertRaises(KeyboardInterrupt):
            self.m.journaled(self.j, op, None, cmd)
        self.m.append = real_append
        lines = Path(self.j).read_text().splitlines()[:-1]
        Path(self.j).write_text("\n".join(lines) + "\n")
        res = json.loads(quiet(self.m.check, NS(journal=self.j, op=op)))
        self.assertIn("→ done", res["hint"])
        quiet(self.m.resolve, NS(journal=self.j, op=op, status="done", note="check", id=res["id"]))
        quiet(self.m.undo, NS(journal=self.j, op=op, reason="undo"))
        self.assertNotIn(res["id"], store.mems)

    def test_torn_last_line_keeps_recovery_working(self):  # W2
        self.m.bb = FakeStore(self.m, BASE)
        op = "run:3:forget:rule"
        self.m.append(self.j, dict(op=op, status="intent", command=["forget", "mem_test", "--expected-version", "1"], before=BASE, project=None))
        with open(self.j, "a") as f:
            f.write('{"op":"run:3:forget:rule","status":"do')
        out = quiet(self.m.pending, NS(journal=self.j))
        self.assertEqual(json.loads(out)["status"], "intent")
        quiet(self.m.resolve, NS(journal=self.j, op=op, status="failed", note="still there", id=None))
        self.assertEqual(self.m.op_state(self.j, op), "failed")
        self.assertTrue(list(Path(self.tmp.name).glob("journal.jsonl.torn-*")))

    def test_torn_multibyte_character_keeps_recovery_working(self):  # W2 round 2
        self.m.bb = FakeStore(self.m, BASE)
        op = "r:1:forget:rule"
        self.m.append(self.j, dict(op=op, status="intent", command=["forget", "mem_test", "--expected-version", "1"], before=BASE, project=None))
        with open(self.j, "ab") as f:  # crash inside 🛑 (4 bytes in UTF-8)
            f.write(b'{"op":"r:1:forget:rule","status":"done","note":"' + "🛑".encode()[:2])
        self.assertEqual([e["status"] for e in self.m.journal_lines(self.j)], ["intent"])
        self.assertEqual(json.loads(quiet(self.m.pending, NS(journal=self.j)))["status"], "intent")
        quiet(self.m.resolve, NS(journal=self.j, op=op, status="failed", note="still there 🛑", id=None))
        self.assertEqual([e["status"] for e in self.m.journal_lines(self.j)], ["intent", "failed"])
        torn = list(Path(self.tmp.name).glob("journal.jsonl.torn-*"))
        self.assertEqual(len(torn), 1)
        self.assertTrue(torn[0].read_bytes().endswith("🛑".encode()[:2]))

    def test_corrupt_middle_line_stops(self):  # W2
        Path(self.j).write_text('{"op":"a","status":"done"}\n{broken\n{"op":"b","status":"done"}\n')
        with self.assertRaises(RuntimeError):
            self.m.journal_lines(self.j)

    def test_read_error_is_not_proof_of_forget(self):  # W3
        op = "run:3:forget:rule"
        self.m.append(self.j, dict(op=op, status="intent", command=["forget", "mem_test", "--expected-version", "1"], before=BASE, project=None))

        def outage(*a, **k):
            raise RuntimeError("backend unavailable")
        self.m.bb = outage
        with self.assertRaises(RuntimeError):
            quiet(self.m.check, NS(journal=self.j, op=op))
        self.m.bb = FakeStore(self.m)  # structured not-found does prove it
        self.assertIn("gone → done", json.loads(quiet(self.m.check, NS(journal=self.j, op=op)))["hint"])

    def test_undo_refuses_to_leave_tags_it_cannot_clear(self):  # W4
        store = self.m.bb = FakeStore(self.m, BASE)
        op = "run:2:update:rule"
        self.m.journaled(self.j, op, None, ["update", "mem_test", "--expected-version", "1", "--reason", "t", "--tag", "added"])
        with self.assertRaises(SystemExit):
            quiet(self.m.undo, NS(journal=self.j, op=op, reason="undo"))
        self.assertEqual(store.mems["mem_test"]["version"], 2)

    def test_undo_update_restores_tags(self):
        store = self.m.bb = FakeStore(self.m, dict(BASE, tags=["one", "two"]))
        op = "run:2:update:rule"
        self.m.journaled(self.j, op, None, ["update", "mem_test", "--expected-version", "1", "--reason", "t", "--tag", "x", "--summary", "s2"])
        quiet(self.m.undo, NS(journal=self.j, op=op, reason="undo"))
        self.assertEqual(store.mems["mem_test"]["tags"], ["one", "two"])
        self.assertEqual(store.mems["mem_test"]["summary"], "original")

    def test_pinned_is_refused(self):
        self.m.bb = FakeStore(self.m, dict(BASE, pinned=True))
        with self.assertRaises(SystemExit):
            self.m.journaled(self.j, "p", None, ["forget", "mem_test", "--expected-version", "1", "--reason", "t"])
        self.assertFalse(Path(self.j).exists())


class Dream(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        self.d = d = load("dream")
        d.HOME, d.STATE, d.CONFIG = str(t), str(t / "state.json"), str(t / "config.json")
        d.JOURNAL, d.BATCHES = str(t / "journal.jsonl"), str(t / "batches")
        (t / "batches").mkdir(); (t / "logs").mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def test_commit_crash_is_finished_not_superseded(self):  # W1
        d, t, run = self.d, Path(self.tmp.name), "2026-11-11"
        d.write_json(d.STATE, dict(cursorMs=100, lastSeq={}, dreamThreads=[]))
        folder = t / "batches" / run; folder.mkdir()
        d.write_json(str(folder / "manifest.json"), dict(run=run, committed=False, baseCursorMs=100,
                     pending=dict(cursorMs=200, lastSeq={"thr": 10}), batches=[], threads=[]))
        d.write_json(str(t / "logs" / f"{run}.json"), [dict(op=f"{run}:1:add:rule", status="proposed")])
        real = d.write_json

        def crash(path, obj):
            if path.endswith("manifest.json"):
                raise OSError("crash after state")
            return real(path, obj)
        d.write_json = crash
        with self.assertRaises(OSError):
            d.commit(run)
        d.write_json = real
        d.collect = lambda *a: self.fail("re-collected")
        d.take_lock = lambda run: None
        quiet(d.begin, run)
        self.assertTrue((t / "logs" / f"{run}.json").exists())
        self.assertTrue(d.read_json(str(folder / "manifest.json"))["committed"])
        self.assertEqual(d.load_state()["cursorMs"], 200)
        quiet(d.commit, run)  # repeat is a no-op
        self.assertEqual(d.load_state()["committedRuns"], [run])

    def test_long_thread_keeps_every_message(self):  # W8
        d = self.d
        events = [dict(seq=1, type="client/turn/requested", data=dict(initiator="user", input=[dict(type="text", text="REMEMBER_EARLY_RULE")])),
                  dict(seq=2, type="item/completed", data=dict(item=dict(type="agentMessage", text="x" * 41000 + "TAIL"))),
                  dict(seq=3, type="client/turn/requested", data=dict(initiator="user", input=[dict(type="text", text="LATE_RULE")]))]

        def fake(*args):
            if args[:2] == ("project", "list"):
                return [dict(id="proj", name="project")]
            if args[:2] == ("thread", "list"):
                return [dict(id="thr", updatedAt=1000, projectId="proj", title="normal")]
            if args[:2] == ("thread", "log"):
                return events
            raise AssertionError(args)
        d.bb = fake
        manifest = d.collect("long", dict(cursorMs=0, lastSeq={}, dreamThreads=[]), "me")
        text = "".join((Path(d.BATCHES) / "long" / b).read_text() for b in manifest["batches"])
        for needle in ("REMEMBER_EARLY_RULE", "TAIL", "LATE_RULE"):
            self.assertIn(needle, text)
        self.assertEqual(text.count("x"), 41000)
        self.assertEqual(manifest["pending"]["lastSeq"]["thr"], 3)

    def log(self, run, items):
        self.d.write_json(str(Path(self.tmp.name) / "logs" / f"{run}.json"), items)

    def backlog(self):
        return self.d.read_json(str(Path(self.tmp.name) / "backlog.json"))

    def test_failed_item_survives_backlog_replay(self):  # W5 trace 1
        d, run = self.d, "2026-11-11"
        failed = dict(n=1, op=f"{run}:1:add:rule", action="add", name="rule", scope="project", projectId="A", status="failed", error="conflict")
        self.log(run, [failed])
        quiet(d.backlog, run)
        quiet(d.backlog, run)  # crash before the report, then the rerun replays step 5
        self.assertEqual([(b["name"], b["why"], b["projectId"]) for b in self.backlog()], [("rule", "failed", "A")])

    def test_backlog_replay_keys_by_scope_and_project(self):  # W5 trace 2
        d, run = self.d, "2026-11-11"
        deferred = dict(name="build-command", scope="project", projectId="A", why="deferred", since="2026-11-10", waited=0)
        d.write_json(str(Path(self.tmp.name) / "backlog.json"), [deferred])
        self.log(run, [dict(n=1, op=f"{run}:1:add:build-command", action="add", name="build-command", scope="project", projectId="B", status="applied"),
                       dict(n=2, op=f"{run}:2:add:build-command", action="add", name="build-command", scope="global", projectId="A", status="applied")])
        quiet(d.backlog, run)
        self.assertEqual(self.backlog(), [deferred])
        self.log(run, [dict(n=1, op=f"{run}:1:add:build-command", action="add", name="build-command", scope="project", projectId="A", status="applied")])
        quiet(d.backlog, run)
        self.assertEqual(self.backlog(), [])

    def test_reconcile_after_crash_between_op_assignment_and_check(self):  # W9
        d, run = self.d, "2026-11-11"
        m = d.mem()
        m.bb = FakeStore(m, dict(BASE, name="rule", summary="already effective"))
        # The state the reviewer reproduced: op ids saved, reconciliation never ran.
        self.log(run, [dict(n=1, op=f"{run}:1:add:rule", action="add", scope="global", name="rule", summary="already effective", status="proposed"),
                       dict(n=2, op=f"{run}:2:add:other", action="add", scope="global", name="other", summary="new", status="proposed"),
                       dict(n=3, op=f"{run}:3:add:old", action="add", scope="global", name="old", summary="x", status="rejected")])
        quiet(d.reconcile, run)
        items = d.read_json(d.log_path(run))
        self.assertEqual([(i["status"], i.get("memoryId")) for i in items], [("applied", "mem_test"), ("proposed", None), ("rejected", None)])

    def test_reconcile_update_needs_every_field_to_match(self):  # W9 round 3
        d, run = self.d, "2026-11-11"
        m = d.mem()
        m.bb = FakeStore(m, dict(BASE, tags=["a", "b"], importance=50, kind="procedure"))
        same_text = dict(action="update", scope="global", id="mem_test", name="rule", summary="original", details="original detail")
        self.log(run, [dict(same_text, n=1, kind="preference", status="proposed"),
                       dict(same_text, n=2, tags=["a", "c"], status="proposed"),
                       dict(same_text, n=3, importance=70, status="proposed"),
                       dict(same_text, n=4, scope="project", projectId="P", status="proposed"),
                       dict(same_text, n=5, kind="procedure", tags=["b", "a"], importance=50, status="proposed")])
        quiet(d.reconcile, run)
        self.assertEqual([i["status"] for i in d.read_json(d.log_path(run))],
                         ["proposed", "proposed", "proposed", "proposed", "applied"])

    def test_reconcile_legacy_log_is_atomic(self):  # W9: a crash mid-pass saves nothing
        d, run = self.d, "2026-11-11"
        m = d.mem()
        store = m.bb = FakeStore(m, dict(BASE, name="rule", summary="already effective"))
        legacy = [dict(n=1, action="add", scope="global", name="rule", summary="already effective", status="proposed"),
                  dict(n=2, action="forget", scope="global", id="mem_gone", name="gone", status="proposed"),
                  dict(n=3, action="update", scope="global", id="mem_test", name="rule", summary="other", status="applied")]
        self.log(run, legacy)

        def outage(args, project=None):
            if args[2] == "mem_gone":
                raise RuntimeError("backend unavailable")
            return store(args, project)
        m.bb = outage
        with self.assertRaises(RuntimeError):
            quiet(d.reconcile, run)
        self.assertEqual(d.read_json(d.log_path(run)), legacy)
        m.bb = store
        quiet(d.reconcile, run)
        items = d.read_json(d.log_path(run))
        self.assertEqual([i["op"] for i in items], [f"{run}:1:add:rule", f"{run}:2:forget:gone", f"{run}:3:update:rule"])
        self.assertEqual([(i["status"], i.get("memoryId")) for i in items],
                         [("applied", "mem_test"), ("applied", "mem_gone"), ("applied", None)])

    def test_legacy_state_and_config_load(self):
        d = self.d
        state = dict(cursorMs=123, lastSeq={"thr_old": 7}, dreamThreads=["t"], lastCommittedRun="2026-11-10")
        d.write_json(d.STATE, state)
        d.write_json(d.CONFIG, dict(mode="apply", scannerModel="claude-haiku-5-5", judgeModel="claude-opus-5-5", keepBatchesDays=14))
        self.assertEqual(d.load_state(), state)
        self.assertEqual(d.load_config()["memoryLimit"], 200)


if __name__ == "__main__":
    unittest.main()

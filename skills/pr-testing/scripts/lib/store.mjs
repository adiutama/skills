// Checklist store: plain JSON files under one state directory, written atomically.
//
//   <dir>/session.json         token, port, host, notify target, active PR
//   <dir>/prs/<n>.json         one PR: current cases + revisions (each with its results)
//   <dir>/submissions/<id>.json  one button press, saved before delivery
//   <dir>/events.jsonl         append-only event log the bridge and the agent read
//
// Every read goes to disk, so the CLI and the server can share a directory.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

export const USER_STATUSES = ['pending', 'pass', 'fail', 'blocked'];
export const STATUSES = [...USER_STATUSES, 'needs-retest'];
export const KINDS = ['feedback', 'fix-request', 'complete'];

const ID_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,39}$/;
const SHA_RE = /^[0-9a-f]{7,40}$/;
const LIMITS = { title: 200, step: 500, steps: 30, expected: 1000, note: 4000, message: 8000, cases: 200 };

export class InputError extends Error {
  constructor(message, status = 400) { super(message); this.status = status; }
}

function check(cond, message, status) { if (!cond) throw new InputError(message, status); }

export function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 });
  const tmp = `${file}.${process.pid}.${crypto.randomBytes(4).toString('hex')}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(value, null, 2) + '\n', { mode: 0o600 });
  fs.renameSync(tmp, file);
}

export function readJson(file, fallback) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); }
  catch (e) { if (e.code === 'ENOENT') return fallback; throw e; }
}

export function prNumber(value) {
  const n = Number(value);
  check(Number.isInteger(n) && n > 0 && n < 1e9, `invalid PR number: ${value}`);
  return n;
}

export function sha(value) {
  check(typeof value === 'string' && SHA_RE.test(value), `invalid SHA: ${value}`);
  return value;
}

function text(value, max, name, required = true) {
  if (value === undefined || value === null || value === '') {
    check(!required, `${name} is required`);
    return '';
  }
  check(typeof value === 'string', `${name} must be a string`);
  check(value.length <= max, `${name} is longer than ${max} characters`);
  return value;
}

// Cases come from the agent, written after reading the PR. The dashboard only renders them.
export function validateCases(input) {
  const list = Array.isArray(input) ? input : input?.cases;
  check(Array.isArray(list) && list.length > 0, 'cases must be a non-empty array');
  check(list.length <= LIMITS.cases, `at most ${LIMITS.cases} cases`);
  const seen = new Set();
  return list.map((c, i) => {
    check(c && typeof c === 'object', `case ${i} must be an object`);
    check(typeof c.id === 'string' && ID_RE.test(c.id), `case ${i}: id must match ${ID_RE}`);
    check(!seen.has(c.id), `duplicate case id ${c.id}`);
    seen.add(c.id);
    check(Array.isArray(c.steps) && c.steps.length > 0 && c.steps.length <= LIMITS.steps, `case ${c.id}: 1-${LIMITS.steps} steps`);
    return {
      id: c.id,
      title: text(c.title, LIMITS.title, `case ${c.id} title`),
      steps: c.steps.map((s) => text(s, LIMITS.step, `case ${c.id} step`)),
      expected: text(c.expected, LIMITS.expected, `case ${c.id} expected`),
      ...(c.area ? { area: text(c.area, 80, `case ${c.id} area`) } : {}),
    };
  });
}

export class Store {
  constructor(dir) {
    this.dir = path.resolve(dir);
    fs.mkdirSync(this.dir, { recursive: true, mode: 0o700 });
  }

  // ---- session ----
  sessionFile() { return path.join(this.dir, 'session.json'); }
  session() { return readJson(this.sessionFile(), null); }
  ensureSession(defaults = {}) {
    let s = this.session();
    if (!s) {
      s = {
        version: 1,
        token: crypto.randomBytes(24).toString('base64url'),
        createdAt: new Date().toISOString(),
        port: null, host: '127.0.0.1', notify: 'none', publicUrl: null, active: null,
        ...defaults,
      };
      writeJson(this.sessionFile(), s);
    }
    return s;
  }
  updateSession(patch) {
    const s = { ...this.ensureSession(), ...patch };
    writeJson(this.sessionFile(), s);
    return s;
  }
  setActive({ pr, sha: head, appUrl }) {
    const n = prNumber(pr);
    const doc = this.pr(n);
    check(doc, `PR ${n} has no checklist yet`, 404);
    check(this.current(doc).sha === sha(head), `PR ${n} current revision is ${this.current(doc).sha}, not ${head}`, 409);
    if (appUrl) check(/^https?:\/\/[^\s]+$/.test(appUrl), 'app URL must be http(s)');
    return this.updateSession({ active: { pr: n, sha: head, appUrl: appUrl || null, at: new Date().toISOString() } });
  }

  // ---- PRs ----
  prFile(n) { return path.join(this.dir, 'prs', `${prNumber(n)}.json`); }
  pr(n) { return readJson(this.prFile(n), null); }
  prs() {
    const d = path.join(this.dir, 'prs');
    if (!fs.existsSync(d)) return [];
    return fs.readdirSync(d).filter((f) => /^\d+\.json$/.test(f))
      .map((f) => readJson(path.join(d, f), null)).filter(Boolean)
      .sort((a, b) => a.number - b.number);
  }
  current(doc) { return doc.revisions[doc.revisions.length - 1]; }

  // First checklist for a PR, or a replacement case list at the same revision.
  setCases({ pr, sha: head, cases, title, url }) {
    const n = prNumber(pr);
    sha(head);
    const list = validateCases(cases);
    const now = new Date().toISOString();
    let doc = this.pr(n);
    if (!doc) {
      doc = { version: 1, number: n, title: '', url: '', cases: [], revisions: [{ sha: head, at: now, retest: 'all', results: {} }] };
    }
    check(this.current(doc).sha === head, `PR ${n} is at revision ${this.current(doc).sha}; use revision for ${head}`, 409);
    if (title !== undefined) doc.title = text(title, LIMITS.title, 'title', false);
    if (url !== undefined) doc.url = text(url, 500, 'url', false);
    doc.cases = list;
    const rev = this.current(doc);
    for (const c of list) if (!rev.results[c.id]) rev.results[c.id] = { status: 'pending', note: '', at: now };
    writeJson(this.prFile(n), doc);
    return doc;
  }

  // A new head for a PR. Cases in `retest` (or all) become needs-retest; the rest carry their
  // previous result, still stamped with the SHA they were tested at. Old revisions stay intact.
  addRevision({ pr, sha: head, retest = 'all', cases }) {
    const n = prNumber(pr);
    sha(head);
    const doc = this.pr(n);
    check(doc, `PR ${n} has no checklist yet`, 404);
    const prev = this.current(doc);
    if (prev.sha === head) return doc;
    if (cases) doc.cases = validateCases(cases);
    const ids = new Set(doc.cases.map((c) => c.id));
    let affected;
    if (retest === 'all') affected = ids;
    else {
      const list = Array.isArray(retest) ? retest : String(retest).split(',').map((s) => s.trim()).filter(Boolean);
      for (const id of list) check(ids.has(id), `unknown case id in retest: ${id}`);
      affected = new Set(list);
    }
    const now = new Date().toISOString();
    const results = {};
    for (const c of doc.cases) {
      const old = prev.results[c.id];
      if (!old) results[c.id] = { status: 'pending', note: '', at: now };
      else if (affected.has(c.id)) results[c.id] = { status: 'needs-retest', note: '', at: now, previous: { status: old.status, note: old.note, sha: old.testedSha || prev.sha } };
      else results[c.id] = { ...old, carried: true };
    }
    doc.revisions.push({ sha: head, at: now, retest: retest === 'all' ? 'all' : [...affected], results });
    writeJson(this.prFile(n), doc);
    return doc;
  }

  setResult({ pr, sha: head, caseId, status, note }) {
    const n = prNumber(pr);
    const doc = this.pr(n);
    check(doc, `PR ${n} has no checklist`, 404);
    const rev = this.current(doc);
    check(rev.sha === sha(head), `this page shows ${head}, but PR ${n} is now at ${rev.sha}; reload`, 409);
    check(doc.cases.some((c) => c.id === caseId), `unknown case ${caseId}`, 404);
    check(USER_STATUSES.includes(status), `status must be one of ${USER_STATUSES.join(', ')}`);
    const prev = rev.results[caseId] || {};
    rev.results[caseId] = {
      status, note: text(note ?? prev.note ?? '', LIMITS.note, 'note', false),
      at: new Date().toISOString(), testedSha: head,
      ...(prev.previous ? { previous: prev.previous } : {}),
    };
    writeJson(this.prFile(n), doc);
    return rev.results[caseId];
  }

  // ---- submissions ----
  subFile(id) {
    check(/^s-[0-9a-f-]{8,40}$/.test(id), 'invalid submission id', 404);
    return path.join(this.dir, 'submissions', `${id}.json`);
  }
  submission(id) { return readJson(this.subFile(id), null); }
  submissions({ pr } = {}) {
    const d = path.join(this.dir, 'submissions');
    if (!fs.existsSync(d)) return [];
    return fs.readdirSync(d).filter((f) => f.endsWith('.json'))
      .map((f) => readJson(path.join(d, f), null)).filter(Boolean)
      .filter((s) => pr === undefined || s.pr === pr)
      .sort((a, b) => a.createdAt.localeCompare(b.createdAt));
  }
  saveSubmission(sub) { writeJson(this.subFile(sub.id), sub); return sub; }

  // Saves a button press before anything is delivered. Returns { submission, duplicate }.
  // Same client key → the earlier submission (double click, retried request).
  // A fix request identical to an open one at the same SHA → that one (no second fix batch).
  createSubmission({ kind, pr, sha: head, message, key }) {
    check(KINDS.includes(kind), `kind must be one of ${KINDS.join(', ')}`);
    const n = prNumber(pr);
    check(typeof key === 'string' && /^[A-Za-z0-9_-]{8,64}$/.test(key), 'key must be 8-64 url-safe characters');
    const doc = this.pr(n);
    check(doc, `PR ${n} has no checklist`, 404);
    const rev = this.current(doc);
    check(rev.sha === sha(head), `this page shows ${head}, but PR ${n} is now at ${rev.sha}; reload`, 409);
    const msg = text(message, LIMITS.message, 'message', false).trim();

    const all = this.submissions({ pr: n });
    const same = all.find((s) => s.key === key);
    if (same) return { submission: same, duplicate: true };

    const cases = doc.cases.map((c) => ({ id: c.id, title: c.title, ...pick(rev.results[c.id]) }));
    const failing = cases.filter((c) => c.status === 'fail' || c.status === 'blocked');
    if (kind === 'fix-request') check(failing.length > 0 || msg, 'a fix request needs a failed or blocked case, or a note');
    if (kind === 'feedback') check(msg || cases.some((c) => c.note), 'feedback needs a message or a case note');
    const fingerprint = crypto.createHash('sha256')
      .update(JSON.stringify([kind, n, head, msg, kind === 'fix-request' ? failing : cases])).digest('hex');
    if (kind === 'fix-request') {
      const open = all.find((s) => s.kind === 'fix-request' && s.sha === head && s.fingerprint === fingerprint && s.state !== 'failed');
      if (open) return { submission: open, duplicate: true };
    }
    const now = new Date();
    const id = `s-${now.toISOString().slice(0, 10).replace(/-/g, '')}-${crypto.randomBytes(4).toString('hex')}`;
    const sub = {
      version: 1, id, key, kind, pr: n, title: doc.title, url: doc.url, sha: head, message: msg,
      cases: kind === 'fix-request' ? failing : cases,
      summary: summarize(cases), fingerprint,
      state: 'saved', attempts: [], createdAt: now.toISOString(), ackedAt: null,
    };
    this.saveSubmission(sub);
    this.event({ type: 'submission', id, kind, pr: n, sha: head });
    return { submission: sub, duplicate: false };
  }

  ack(id) {
    const s = this.submission(id);
    check(s, `no submission ${id}`, 404);
    s.ackedAt = new Date().toISOString();
    return this.saveSubmission(s);
  }

  event(e) {
    fs.appendFileSync(path.join(this.dir, 'events.jsonl'), JSON.stringify({ at: new Date().toISOString(), ...e }) + '\n', { mode: 0o600 });
  }
}

function pick(r = {}) {
  const out = { status: r.status || 'pending', note: r.note || '' };
  if (r.testedSha) out.testedSha = r.testedSha;
  return out;
}

export function summarize(cases) {
  const s = Object.fromEntries(STATUSES.map((k) => [k, 0]));
  for (const c of cases) s[c.status] = (s[c.status] || 0) + 1;
  return s;
}

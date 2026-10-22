// node --test skills/pr-testing/tests/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { Store } from '../scripts/lib/store.mjs';
import { createBridge, features, messageFor } from '../scripts/lib/bridge.mjs';
import { createServer } from '../scripts/lib/server.mjs';

const CLI = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../scripts/dashboard.mjs');
const A = 'a'.repeat(40);
const B = 'b'.repeat(40);
const C = 'c'.repeat(40);
const CASES = [
  { id: 'login', title: 'Log in', steps: ['Open /login', 'Sign in'], expected: 'Dashboard shows' },
  { id: 'export', title: 'Export CSV', steps: ['Click Export'], expected: 'A CSV downloads' },
  { id: 'audit', title: 'Audit row', steps: ['Open audit log'], expected: 'Export is logged' },
];

const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'prt-'));

test('checklists persist per PR and survive a new store (restart)', () => {
  const dir = tmp();
  const s1 = new Store(dir);
  s1.setCases({ pr: 1, sha: A, cases: CASES, title: 'One' });
  s1.setCases({ pr: 2, sha: B, cases: CASES.slice(0, 1), title: 'Two' });
  s1.setResult({ pr: 1, sha: A, caseId: 'login', status: 'fail', note: 'blank page' });
  const s2 = new Store(dir);
  assert.equal(s2.pr(1).revisions[0].results.login.status, 'fail');
  assert.equal(s2.pr(1).revisions[0].results.login.testedSha, A);
  assert.equal(s2.pr(2).revisions[0].results.login.status, 'pending', 'PR 2 is isolated from PR 1');
  assert.deepEqual(s2.prs().map((p) => p.number), [1, 2]);
  assert.equal(fs.statSync(path.join(dir, 'prs', '1.json')).mode & 0o777, 0o600);
});

test('cases are validated, not invented', () => {
  const s = new Store(tmp());
  assert.throws(() => s.setCases({ pr: 1, sha: A, cases: [] }), /non-empty/);
  assert.throws(() => s.setCases({ pr: 1, sha: A, cases: [{ id: 'bad id', title: 't', steps: ['x'], expected: 'y' }] }), /id must match/);
  assert.throws(() => s.setCases({ pr: 1, sha: A, cases: [CASES[0], CASES[0]] }), /duplicate/);
  assert.throws(() => s.setCases({ pr: 1, sha: 'nope', cases: CASES }), /invalid SHA/);
});

test('a new revision marks affected checks for retest and keeps history', () => {
  const s = new Store(tmp());
  s.setCases({ pr: 7, sha: A, cases: CASES });
  s.setResult({ pr: 7, sha: A, caseId: 'login', status: 'pass' });
  s.setResult({ pr: 7, sha: A, caseId: 'export', status: 'fail', note: 'wrong header' });
  let doc = s.addRevision({ pr: 7, sha: B, retest: 'export' });
  let rev = s.current(doc);
  assert.equal(rev.results.export.status, 'needs-retest');
  assert.deepEqual(rev.results.export.previous, { status: 'fail', note: 'wrong header', sha: A });
  assert.equal(rev.results.login.status, 'pass');
  assert.equal(rev.results.login.testedSha, A, 'carried result keeps the SHA it was tested at');
  assert.equal(doc.revisions[0].results.export.status, 'fail', 'old revision untouched');

  doc = s.addRevision({ pr: 7, sha: C });
  rev = s.current(doc);
  assert.ok(Object.values(rev.results).every((r) => r.status === 'needs-retest' || r.status === 'pending'), 'no subset given → everything retests');
  assert.equal(doc.revisions.length, 3);
  assert.throws(() => s.addRevision({ pr: 7, sha: A.replace('a', 'd'), retest: 'ghost' }), /unknown case id/);
  assert.throws(() => s.setResult({ pr: 7, sha: B, caseId: 'login', status: 'pass' }), (e) => e.status === 409);
  assert.throws(() => s.setResult({ pr: 7, sha: C, caseId: 'login', status: 'needs-retest' }), /status must be/);
});

test('submissions dedupe double clicks and repeated fix requests', () => {
  const s = new Store(tmp());
  s.setCases({ pr: 3, sha: A, cases: CASES });
  assert.throws(() => s.createSubmission({ kind: 'fix-request', pr: 3, sha: A, message: '', key: 'k1234567' }), /needs a failed/);
  s.setResult({ pr: 3, sha: A, caseId: 'export', status: 'fail', note: 'no file' });
  const first = s.createSubmission({ kind: 'fix-request', pr: 3, sha: A, message: 'fix export', key: 'k1234567' });
  assert.equal(first.duplicate, false);
  assert.equal(first.submission.state, 'saved');
  assert.deepEqual(first.submission.cases.map((c) => c.id), ['export']);
  assert.equal(s.createSubmission({ kind: 'fix-request', pr: 3, sha: A, message: 'fix export', key: 'k1234567' }).duplicate, true, 'same key');
  const again = s.createSubmission({ kind: 'fix-request', pr: 3, sha: A, message: 'fix export', key: 'k7654321' });
  assert.equal(again.duplicate, true, 'same content at the same SHA');
  assert.equal(again.submission.id, first.submission.id);
  first.submission.state = 'failed';
  s.saveSubmission(first.submission);
  assert.equal(s.createSubmission({ kind: 'fix-request', pr: 3, sha: A, message: 'fix export', key: 'k0000000' }).duplicate, false, 'a failed one may be sent anew');
  assert.equal(s.createSubmission({ kind: 'complete', pr: 3, sha: A, message: '', key: 'k1111111' }).duplicate, false);
  assert.throws(() => s.createSubmission({ kind: 'merge', pr: 3, sha: A, key: 'k2222222' }), /kind must be/);
  assert.throws(() => s.createSubmission({ kind: 'complete', pr: 3, sha: B, key: 'k3333333' }), (e) => e.status === 409);
  const events = fs.readFileSync(path.join(s.dir, 'events.jsonl'), 'utf8').trim().split('\n');
  assert.equal(events.length, 3);
});

test('message tells the agent what the button means', () => {
  const s = new Store(tmp());
  s.setCases({ pr: 3, sha: A, cases: CASES, title: 'Export' });
  s.setResult({ pr: 3, sha: A, caseId: 'export', status: 'fail', note: 'no file' });
  const { submission } = s.createSubmission({ kind: 'complete', pr: 3, sha: A, message: 'all good otherwise', key: 'k1234567' });
  const text = messageFor(submission);
  assert.match(text, /not merge authorization/);
  assert.match(text, /export \[fail\]/);
  assert.match(text, new RegExp(A));
});

test('bb bridge: fixed argv, no shell, payload on stdin, delivery states', async () => {
  const calls = [];
  const fake = (reply, code = 0) => (bin, args, opts, cb) => {
    const call = { bin, args, opts, stdin: '' };
    calls.push(call);
    setImmediate(() => cb(code ? Object.assign(new Error('exit 1'), { code }) : null, JSON.stringify(reply), ''));
    return { stdin: { on() {}, end: (t) => { call.stdin = t; } } };
  };
  let b = createBridge('bb:thr_abcdef12', { exec: fake({ threadId: 'thr_abcdef12', ok: true, delivery: 'sent', mode: 'auto' }) });
  assert.deepEqual(await b.deliver('hello; rm -rf /'), { state: 'sent', detail: 'delivered to the agent thread' });
  assert.deepEqual(calls[0].args, ['thread', 'tell', 'thr_abcdef12', '--mode', 'auto', '--json', '--message-file', '-']);
  assert.equal(calls[0].bin, 'bb');
  assert.equal(calls[0].opts.shell, false);
  assert.equal(calls[0].stdin, 'hello; rm -rf /');

  b = createBridge('bb:thr_abcdef12', { exec: fake({ ok: true, delivery: 'queued', queuedMessage: { waitingOn: 'interaction' } }) });
  assert.equal((await b.deliver('x')).state, 'queued');
  b = createBridge('bb:thr_abcdef12', { exec: fake({ ok: false, error: { code: 'thread_not_found', message: 'HTTP 404: Thread not found' } }, 1) });
  assert.deepEqual(await b.deliver('x'), { state: 'failed', detail: 'HTTP 404: Thread not found' });

  assert.throws(() => createBridge('bb:thr_x; rm -rf /'), /invalid notify target/);
  assert.throws(() => createBridge('sh:echo'), /invalid notify target/);
  assert.equal(features('none').notify, false);
  assert.equal(features('bb:thr_abcdef12').notify, true);
});

// ---- HTTP ----

async function boot({ notify = 'none', bridge } = {}) {
  const dir = tmp();
  const st = new Store(dir);
  st.ensureSession({ notify });
  st.setCases({ pr: 5, sha: A, cases: CASES, title: 'Five' });
  const app = createServer({ dir, bridge });
  await new Promise((r) => app.server.listen(0, '127.0.0.1', r));
  const base = `http://127.0.0.1:${app.server.address().port}`;
  const token = st.session().token;
  const login = await fetch(`${base}/?k=${token}`, { redirect: 'manual' });
  const cookie = login.headers.get('set-cookie').split(';')[0];
  const post = (p, body, headers = {}) => fetch(base + p, {
    method: 'POST', body: JSON.stringify(body),
    headers: { 'Content-Type': 'application/json', Cookie: cookie, 'X-PRT-CSRF': app.csrf, ...headers },
  });
  const get = (p) => fetch(base + p, { headers: { Cookie: cookie } });
  return { dir, st, app, base, token, cookie, login, post, get, close: () => new Promise((r) => app.server.close(r)) };
}

test('auth: key → HttpOnly SameSite cookie; no cookie, wrong key, or no CSRF is refused', async () => {
  const t = await boot();
  try {
    assert.equal(t.login.status, 302);
    assert.match(t.login.headers.get('set-cookie'), /HttpOnly; SameSite=Strict/);
    assert.equal((await fetch(`${t.base}/api/state`)).status, 401);
    assert.equal((await fetch(`${t.base}/?k=wrong`)).status, 401);
    assert.equal((await fetch(`${t.base}/dashboard.js`)).status, 401);
    const state = await (await t.get('/api/state')).json();
    assert.equal(state.csrf, t.app.csrf);
    assert.equal(state.prs[0].number, 5);
    assert.equal((await t.post('/api/result', { pr: 5, sha: A, caseId: 'login', status: 'pass' }, { 'X-PRT-CSRF': 'nope' })).status, 403);
    assert.equal((await fetch(`${t.base}/api/result`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-PRT-CSRF': t.app.csrf }, body: '{}' })).status, 401);
    assert.equal((await t.post('/api/result', { pr: 5, sha: A, caseId: 'login', status: 'pass' }, { 'Content-Type': 'text/plain' })).status, 415);
    assert.equal((await t.post('/api/result', { pr: 5, sha: A, caseId: 'login', status: 'pass' })).status, 200);
    assert.equal((await t.post('/api/result', { pr: 5, sha: A, caseId: '../../x', status: 'pass' })).status, 404);
    assert.equal((await t.post('/api/run', { cmd: 'id' })).status, 404);
    const big = await t.post('/api/submit', { kind: 'feedback', pr: 5, sha: A, key: 'k1234567', message: 'x'.repeat(70000) });
    assert.equal(big.status, 413);
    const page = await t.get('/');
    assert.match(page.headers.get('content-security-policy'), /default-src 'self'/);
    assert.equal(page.headers.get('referrer-policy'), 'no-referrer');
  } finally { await t.close(); }
});

test('no bridge: saved honestly, copy text offered, nothing claims delivery', async () => {
  const t = await boot();
  try {
    const res = await t.post('/api/submit', { kind: 'feedback', pr: 5, sha: A, message: 'Export label is confusing', key: 'k1234567' });
    assert.equal(res.status, 201);
    const { submission } = await res.json();
    assert.equal(submission.state, 'saved');
    assert.match(submission.copyText, /Send feedback — discussion only/);
    assert.equal(submission.key, undefined);
    const state = await (await t.get('/api/state')).json();
    assert.equal(state.session.features.notify, false);
    assert.match(state.session.features.deliveryNote, /cannot wake the agent/);
    const retry = await t.post(`/api/submissions/${submission.id}/retry`, {});
    assert.equal(retry.status, 409);
    const txt = await t.get(`/api/submissions/${submission.id}/text`);
    assert.match(await txt.text(), /Export label is confusing/);
  } finally { await t.close(); }
});

test('bridge failure is shown, retry delivers once, double click sends once', async () => {
  let fail = true;
  let sent = 0;
  const bridge = { kind: 'bb', deliver: async () => { sent++; return fail ? { state: 'failed', detail: 'bb not running' } : { state: 'sent', detail: 'delivered to the agent thread' }; } };
  const t = await boot({ notify: 'bb:thr_abcdef12', bridge });
  try {
    await t.post('/api/result', { pr: 5, sha: A, caseId: 'export', status: 'fail', note: 'no file' });
    const body = { kind: 'fix-request', pr: 5, sha: A, message: '', key: 'k1234567' };
    const [r1, r2] = await Promise.all([t.post('/api/submit', body), t.post('/api/submit', body)]);
    const s1 = (await r1.json()).submission;
    const s2 = (await r2.json()).submission;
    assert.equal(s1.id, s2.id);
    assert.equal(sent, 1, 'two clicks, one delivery');
    const stored = t.st.submission(s1.id);
    assert.equal(stored.state, 'failed');
    assert.equal(stored.attempts[0].detail, 'bb not running');
    fail = false;
    const retry = await (await t.post(`/api/submissions/${s1.id}/retry`, {})).json();
    assert.equal(retry.submission.state, 'sent');
    assert.equal(sent, 2);
    assert.equal((await t.post(`/api/submissions/${s1.id}/retry`, {})).status, 409, 'a sent one is never resent');
  } finally { await t.close(); }
});

test('a delivery cut off by a restart is reported as possibly delivered, not resent', () => {
  const dir = tmp();
  const st = new Store(dir);
  st.ensureSession({ notify: 'bb:thr_abcdef12' });
  st.setCases({ pr: 5, sha: A, cases: CASES });
  const { submission } = st.createSubmission({ kind: 'complete', pr: 5, sha: A, key: 'k1234567' });
  submission.state = 'sending';
  st.saveSubmission(submission);
  createServer({ dir, bridge: { deliver: async () => assert.fail('must not resend') } });
  const after = st.submission(submission.id);
  assert.equal(after.state, 'failed');
  assert.match(after.attempts[0].detail, /may have arrived/);
});

test('CLI: init keeps a stable port, cases/revision/results/inbox/ack work', () => {
  const dir = tmp();
  const run = (...args) => execFileSync(process.execPath, [CLI, ...args, '--dir', dir], { encoding: 'utf8' });
  const first = run('init', '--notify', 'none');
  const port = /port (\d+)/.exec(first)[1];
  assert.equal(/port (\d+)/.exec(run('init'))[1], port, 'port is reused');
  const file = path.join(dir, 'cases.json');
  fs.writeFileSync(file, JSON.stringify({ cases: CASES }));
  assert.match(run('cases', '--pr', '9', '--sha', A, '--file', file, '--title', 'Nine'), /3 cases/);
  assert.match(run('active', '--pr', '9', '--sha', A, '--app-url', 'http://127.0.0.1:3000'), /active PR #9/);
  assert.match(run('revision', '--pr', '9', '--sha', B, '--retest', 'login'), /1 need retest/);
  assert.match(run('results', '--pr', '9'), /needs-retest\s+login/);
  assert.match(run('inbox'), /inbox empty/);
  assert.match(run('url'), /\?k=/);
  assert.throws(() => run('cases', '--pr', '9', '--sha', 'zzz', '--file', file), /invalid SHA/);
  assert.throws(() => run('init', '--host', '10.0.0.5'), /--host must be/);
});

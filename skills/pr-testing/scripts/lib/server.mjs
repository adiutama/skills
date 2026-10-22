// HTTP server for the checklist dashboard. Node built-ins only.
// Auth: the key from the printed link becomes an HttpOnly SameSite=Strict cookie; every POST also
// needs the CSRF header the page reads from /api/state. No endpoint runs a command the request names.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { Store, InputError } from './store.mjs';
import { createBridge, features, messageFor } from './bridge.mjs';

const ASSETS = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../assets');
const STATIC = {
  '/': ['index.html', 'text/html; charset=utf-8'],
  '/dashboard.js': ['dashboard.js', 'text/javascript; charset=utf-8'],
  '/dashboard.css': ['dashboard.css', 'text/css; charset=utf-8'],
};
const MAX_BODY = 64 * 1024;

const sha256 = (s) => crypto.createHash('sha256').update(s).digest('hex');
const same = (a, b) => typeof a === 'string' && typeof b === 'string' && a.length === b.length
  && crypto.timingSafeEqual(Buffer.from(a), Buffer.from(b));

export function createServer({ dir, bridge: bridgeOverride } = {}) {
  const store = new Store(dir);
  const session = store.ensureSession();
  const target = session.notify || 'none';
  const bridge = bridgeOverride || createBridge(target);
  const feat = features(target);
  const cookieName = `prt_${sha256(session.token).slice(0, 8)}`;
  const csrf = crypto.createHmac('sha256', session.token).update('csrf').digest('base64url');
  const sending = new Set();

  // A delivery cut off by a restart may or may not have arrived: say so, never resend on our own.
  for (const s of store.submissions()) {
    if (s.state === 'sending') {
      s.state = 'failed';
      s.attempts.push({ at: new Date().toISOString(), state: 'failed', detail: 'dashboard stopped during delivery; it may have arrived — check the thread before retrying' });
      store.saveSubmission(s);
    }
  }

  function dashboardUrl() {
    const s = store.session();
    return s.publicUrl || `http://${s.host === '0.0.0.0' ? '127.0.0.1' : s.host}:${s.port}/`;
  }

  async function deliver(sub) {
    if (!feat.notify) return sub;
    if (sending.has(sub.id)) return sub;
    sending.add(sub.id);
    try {
      sub.state = 'sending';
      store.saveSubmission(sub);
      const result = await bridge.deliver(messageFor(sub, { dashboardUrl: dashboardUrl() }));
      sub.state = result.state;
      sub.attempts.push({ at: new Date().toISOString(), ...result });
      store.saveSubmission(sub);
      store.event({ type: 'delivery', id: sub.id, state: result.state });
      return sub;
    } finally {
      sending.delete(sub.id);
    }
  }

  function view(sub) {
    const out = { ...sub };
    delete out.fingerprint;
    delete out.key;
    if (!feat.notify || sub.state === 'failed') out.copyText = messageFor(sub, { dashboardUrl: dashboardUrl() });
    return out;
  }

  function cookies(req) {
    const out = {};
    for (const part of (req.headers.cookie || '').split(';')) {
      const i = part.indexOf('=');
      if (i > 0) out[part.slice(0, i).trim()] = part.slice(i + 1).trim();
    }
    return out;
  }

  function send(res, status, body, headers = {}) {
    const isJson = typeof body !== 'string' && !Buffer.isBuffer(body);
    res.writeHead(status, {
      'Content-Type': isJson ? 'application/json; charset=utf-8' : 'text/plain; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      'Referrer-Policy': 'no-referrer',
      'X-Frame-Options': 'DENY',
      'Content-Security-Policy': "default-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
      ...headers,
    });
    res.end(isJson ? JSON.stringify(body) : body);
  }

  function readBody(req) {
    return new Promise((resolve, reject) => {
      let size = 0;
      const chunks = [];
      req.on('data', (c) => {
        size += c.length;
        if (size > MAX_BODY) { chunks.length = 0; reject(new InputError('request too large', 413)); return; }
        chunks.push(c);
      });
      req.on('end', () => {
        if (size > MAX_BODY) return;
        try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}')); }
        catch { reject(new InputError('body must be JSON')); }
      });
      req.on('error', reject);
    });
  }

  function state() {
    const s = store.session();
    return {
      session: { active: s.active, dashboardUrl: dashboardUrl(), features: feat },
      csrf,
      prs: store.prs().map((d) => {
        const rev = store.current(d);
        const cases = d.cases.map((c) => rev.results[c.id] || { status: 'pending' });
        const counts = {};
        for (const r of cases) counts[r.status] = (counts[r.status] || 0) + 1;
        return { number: d.number, title: d.title, url: d.url, sha: rev.sha, revisions: d.revisions.length, counts, total: d.cases.length };
      }),
    };
  }

  function prView(n) {
    const doc = store.pr(n);
    if (!doc) throw new InputError(`PR ${n} has no checklist`, 404);
    const rev = store.current(doc);
    return {
      number: doc.number, title: doc.title, url: doc.url, sha: rev.sha, retest: rev.retest,
      cases: doc.cases.map((c) => ({ ...c, result: rev.results[c.id] || { status: 'pending', note: '' } })),
      history: doc.revisions.slice(0, -1).map((r) => ({ sha: r.sha, at: r.at, results: r.results })),
      submissions: store.submissions({ pr: n }).map(view),
    };
  }

  async function route(req, res) {
    const url = new URL(req.url, 'http://x');
    const p = url.pathname;

    if (req.method === 'GET' && p === '/' && url.searchParams.has('k')) {
      if (!same(url.searchParams.get('k'), session.token)) return send(res, 401, 'Wrong key. Ask the agent for the dashboard link again.');
      const secure = req.headers['x-forwarded-proto'] === 'https' ? '; Secure' : '';
      return send(res, 302, 'ok', {
        'Set-Cookie': `${cookieName}=${session.token}; HttpOnly; SameSite=Strict; Path=/${secure}`,
        Location: '/',
      });
    }

    const authed = same(cookies(req)[cookieName], session.token);
    if (p === '/healthz' && req.method === 'GET') return send(res, 200, { ok: true });
    if (!authed) return send(res, 401, 'Open the dashboard with the link the agent gave you (it carries the key).');

    if (req.method === 'GET' && STATIC[p]) {
      const [file, type] = STATIC[p];
      return send(res, 200, fs.readFileSync(path.join(ASSETS, file)), { 'Content-Type': type });
    }

    if (req.method === 'GET') {
      if (p === '/api/state') return send(res, 200, state());
      let m = /^\/api\/prs\/(\d+)$/.exec(p);
      if (m) return send(res, 200, prView(Number(m[1])));
      m = /^\/api\/submissions\/([^/]+)\/text$/.exec(p);
      if (m) {
        const sub = store.submission(m[1]);
        if (!sub) throw new InputError('no such submission', 404);
        return send(res, 200, messageFor(sub, { dashboardUrl: dashboardUrl() }), {
          'Content-Disposition': `attachment; filename="${sub.id}.txt"`,
        });
      }
      return send(res, 404, { error: 'not found' });
    }

    if (req.method !== 'POST') return send(res, 405, { error: 'method not allowed' });
    if (!same(req.headers['x-prt-csrf'], csrf)) return send(res, 403, { error: 'missing or wrong CSRF token; reload the page' });
    if (!String(req.headers['content-type'] || '').startsWith('application/json')) return send(res, 415, { error: 'JSON only' });
    const body = await readBody(req);

    if (p === '/api/result') {
      const r = store.setResult({ pr: body.pr, sha: body.sha, caseId: body.caseId, status: body.status, note: body.note });
      return send(res, 200, { result: r });
    }
    if (p === '/api/submit') {
      const { submission, duplicate } = store.createSubmission(body);
      const out = duplicate ? submission : await deliver(submission);
      return send(res, duplicate ? 200 : 201, { submission: view(out), duplicate });
    }
    const m = /^\/api\/submissions\/([^/]+)\/retry$/.exec(p);
    if (m) {
      const sub = store.submission(m[1]);
      if (!sub) throw new InputError('no such submission', 404);
      if (sub.state !== 'failed') return send(res, 409, { error: `submission is ${sub.state}; only a failed one can be retried`, submission: view(sub) });
      const out = await deliver(sub);
      return send(res, 200, { submission: view(out) });
    }
    return send(res, 404, { error: 'not found' });
  }

  const server = http.createServer((req, res) => {
    route(req, res).catch((e) => {
      if (e instanceof InputError) send(res, e.status, { error: e.message });
      else { console.error(e); send(res, 500, { error: 'internal error' }); }
    });
  });
  server.headersTimeout = 10_000;
  server.requestTimeout = 60_000;
  return { server, store, csrf, cookieName, features: feat };
}


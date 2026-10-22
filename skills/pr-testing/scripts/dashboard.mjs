#!/usr/bin/env node
// dashboard.mjs — the pr-testing checklist: a store the agent writes, a page the user ticks.
//
//   dashboard.mjs init     --dir D [--notify none|bb:<thread>] [--host 127.0.0.1] [--port N]
//   dashboard.mjs serve    --dir D                       run the server (foreground; keep it running)
//   dashboard.mjs url      --dir D [--public <URL>]      the link to open (carries the key)
//   dashboard.mjs cases    --dir D --pr N --sha S --file cases.json [--title T] [--url U]
//   dashboard.mjs revision --dir D --pr N --sha S [--retest all|ID,ID] [--file cases.json]
//   dashboard.mjs active   --dir D --pr N --sha S [--app-url U]
//   dashboard.mjs results  --dir D --pr N [--json]
//   dashboard.mjs inbox    --dir D [--all] [--json]   submissions not yet acknowledged
//   dashboard.mjs ack      --dir D <submission id>
//
// Node 18+ built-ins only. Exit 1 with one line on stderr when input is wrong.
import fs from 'node:fs';
import net from 'node:net';
import { parseArgs } from 'node:util';
import { Store, InputError } from './lib/store.mjs';
import { parseTarget, messageFor } from './lib/bridge.mjs';
import { createServer } from './lib/server.mjs';

const FIRST_PORT = 55480;

function die(msg) { process.stderr.write(`${msg}\n`); process.exit(1); }

function freePort(host, from) {
  return new Promise((resolve, reject) => {
    const tryPort = (p) => {
      if (p > from + 200) return reject(new Error(`no free port from ${from}`));
      const s = net.createServer();
      s.once('error', () => tryPort(p + 1));
      s.listen(p, host, () => s.close(() => resolve(p)));
    };
    tryPort(from);
  });
}

function link(s, base) {
  const root = (base || `http://${s.host === '0.0.0.0' ? '127.0.0.1' : s.host}:${s.port}/`).replace(/\/?$/, '/');
  return `${root}?k=${s.token}`;
}

function readCases(file) {
  if (!file) return undefined;
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); }
  catch (e) { die(`cannot read cases from ${file}: ${e.message}`); }
}

const [cmd, ...rest] = process.argv.slice(2);
const { values: o, positionals } = (() => {
  try {
    return parseArgs({
      args: rest, allowPositionals: true, options: {
        dir: { type: 'string' }, notify: { type: 'string' }, host: { type: 'string' }, port: { type: 'string' },
        public: { type: 'string' }, pr: { type: 'string' }, sha: { type: 'string' }, file: { type: 'string' },
        title: { type: 'string' }, url: { type: 'string' }, retest: { type: 'string' }, 'app-url': { type: 'string' },
        json: { type: 'boolean' }, all: { type: 'boolean' },
      },
    });
  } catch (e) { die(e.message); }
})();

if (!cmd || cmd === 'help' || cmd === '-h' || cmd === '--help') {
  process.stdout.write(fs.readFileSync(new URL(import.meta.url), 'utf8').split('\n').slice(1, 15).map((l) => l.replace(/^\/\/ ?/, '')).join('\n') + '\n');
  process.exit(0);
}
if (!o.dir) die(`${cmd}: --dir is required`);

try {
  const store = new Store(o.dir);
  switch (cmd) {
    case 'init': {
      if (o.notify) parseTarget(o.notify);
      const host = o.host || '127.0.0.1';
      if (!['127.0.0.1', '0.0.0.0', '::1', 'localhost'].includes(host)) die('init: --host must be 127.0.0.1, ::1, localhost, or 0.0.0.0');
      let s = store.ensureSession({ host });
      const patch = {};
      if (o.notify) patch.notify = o.notify;
      if (o.host) patch.host = host;
      if (o.port) patch.port = Number(o.port);
      else if (!s.port) patch.port = await freePort(o.host || s.host, FIRST_PORT);
      s = store.updateSession(patch);
      console.log(`dashboard ${o.dir}\nport ${s.port} · host ${s.host} · notify ${s.notify}\nopen ${link(s)}`);
      break;
    }
    case 'serve': {
      const s = store.session();
      if (!s?.port) die('serve: run init first');
      const { server } = createServer({ dir: o.dir });
      server.once('error', (e) => die(`serve: cannot listen on ${s.host}:${s.port}: ${e.code || e.message} (the address must stay stable; free the port, do not pick another)`));
      server.listen(s.port, s.host, () => console.log(`pr-testing dashboard on http://${s.host}:${s.port}/ · notify ${s.notify}`));
      const stop = () => server.close(() => process.exit(0));
      process.on('SIGTERM', stop);
      process.on('SIGINT', stop);
      break;
    }
    case 'url': {
      let s = store.session();
      if (!s) die('url: run init first');
      if (o.public) {
        if (!/^https?:\/\/[^\s?#]+$/.test(o.public)) die('url: --public must be an http(s) URL');
        s = store.updateSession({ publicUrl: o.public });
      }
      console.log(link(s));
      if (s.publicUrl) console.log(link(s, s.publicUrl));
      break;
    }
    case 'cases': {
      const doc = store.setCases({ pr: o.pr, sha: o.sha, cases: readCases(o.file), title: o.title, url: o.url });
      console.log(`PR #${doc.number} @ ${o.sha}: ${doc.cases.length} cases`);
      break;
    }
    case 'revision': {
      const doc = store.addRevision({ pr: o.pr, sha: o.sha, retest: o.retest || 'all', cases: readCases(o.file) });
      const rev = store.current(doc);
      const retest = Object.values(rev.results).filter((r) => r.status === 'needs-retest').length;
      console.log(`PR #${doc.number} @ ${rev.sha}: revision ${doc.revisions.length}, ${retest} need retest`);
      break;
    }
    case 'active': {
      const s = store.setActive({ pr: o.pr, sha: o.sha, appUrl: o['app-url'] });
      console.log(`active PR #${s.active.pr} @ ${s.active.sha}${s.active.appUrl ? ` · app ${s.active.appUrl}` : ''}`);
      break;
    }
    case 'results': {
      const doc = store.pr(o.pr);
      if (!doc) die(`results: PR ${o.pr} has no checklist`);
      const rev = store.current(doc);
      const rows = doc.cases.map((c) => ({ id: c.id, title: c.title, ...rev.results[c.id] }));
      if (o.json) console.log(JSON.stringify({ pr: doc.number, sha: rev.sha, cases: rows }, null, 2));
      else {
        console.log(`PR #${doc.number} @ ${rev.sha}`);
        for (const r of rows) console.log(`${r.status.padEnd(12)} ${r.id}  ${r.title}${r.testedSha && r.testedSha !== rev.sha ? `  (tested at ${r.testedSha.slice(0, 12)})` : ''}${r.note ? `\n             note: ${r.note.replace(/\n/g, ' ')}` : ''}`);
      }
      break;
    }
    case 'inbox': {
      const subs = store.submissions().filter((s) => o.all || !s.ackedAt);
      if (o.json) console.log(JSON.stringify(subs, null, 2));
      else if (!subs.length) console.log('inbox empty');
      else for (const s of subs) console.log(`--- ${s.state}${s.ackedAt ? ' · acked' : ''}\n${messageFor(s)}\n`);
      break;
    }
    case 'ack': {
      const id = positionals[0];
      if (!id) die('ack <submission id>');
      store.ack(id);
      console.log(`acked ${id}`);
      break;
    }
    default: die(`unknown command: ${cmd} (dashboard.mjs help)`);
  }
} catch (e) {
  if (e instanceof InputError || e.message?.startsWith('invalid')) die(`${cmd}: ${e.message}`);
  throw e;
}

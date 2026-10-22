#!/usr/bin/env node
// guard.mjs — refuse targets that are not this session's disposable ones.
//
//   guard.mjs db <url> --record <services.json>
//       before every migrate, reset, or seed: the URL must be loopback and on a port the record lists
//   guard.mjs env <file>... --record <services.json> [--allow KEY,KEY]
//       before every app start: every URL value must be loopback; data-store URLs must be on a
//       recorded port. --allow names the keys the user enabled as real integrations for this PR.
//
// Prints KEY host:port verdicts, never values. Exit 1 on any violation.
import fs from 'node:fs';
import { parseArgs } from 'node:util';
import { fileURLToPath } from 'node:url';

const LOOPBACK = new Set(['127.0.0.1', 'localhost', '::1', '[::1]']);
const DATA_SCHEMES = new Set(['postgres', 'postgresql', 'mysql', 'mariadb', 'mongodb', 'mongodb+srv', 'redis', 'rediss', 'amqp', 'amqps', 'sqlserver', 'jdbc:postgresql', 'jdbc:mysql']);

function die(msg) { process.stderr.write(`${msg}\n`); process.exit(1); }

function recordPorts(file) {
  if (!file) die('--record <services.json> is required');
  let rec;
  try { rec = JSON.parse(fs.readFileSync(file, 'utf8')); } catch (e) { die(`cannot read record ${file}: ${e.message}`); }
  if (rec?.version !== 1 || !Array.isArray(rec.services)) die(`record ${file} is not a version 1 service record`);
  return new Set(rec.services.flatMap((s) => (Array.isArray(s.ports) ? s.ports : [])));
}

// Returns { scheme, host, port } for anything URL-shaped, else null.
export function target(value) {
  const v = String(value).trim();
  const m = /^([a-z][a-z0-9+.:-]*):\/\/(?:[^@/?#]*@)?(\[[^\]]+\]|[^:/?#,]+)(?::(\d+))?/i.exec(v);
  if (!m) return null;
  const scheme = m[1].toLowerCase();
  const defaults = { http: 80, https: 443, postgres: 5432, postgresql: 5432, mysql: 3306, mariadb: 3306, mongodb: 27017, redis: 6379, rediss: 6379, amqp: 5672, amqps: 5671 };
  return { scheme, host: m[2].toLowerCase(), port: m[3] ? Number(m[3]) : defaults[scheme] ?? null };
}

export function checkUrl(value, ports, { data } = {}) {
  const t = target(value);
  if (!t) return { ok: true, skip: true };
  if (!LOOPBACK.has(t.host)) return { ok: false, t, why: 'not loopback' };
  if ((data ?? DATA_SCHEMES.has(t.scheme)) && !ports.has(t.port)) return { ok: false, t, why: 'port not in this session\'s service record' };
  return { ok: true, t };
}

export function parseEnv(text) {
  const out = [];
  for (const line of text.split('\n')) {
    const m = /^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/.exec(line);
    if (!m) continue;
    let v = m[2].trim();
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1);
    out.push([m[1], v]);
  }
  return out;
}

const isMain = process.argv[1] && fs.realpathSync(process.argv[1]) === fs.realpathSync(fileURLToPath(import.meta.url));
if (isMain) {
  const [cmd, ...rest] = process.argv.slice(2);
  let parsed;
  try {
    parsed = parseArgs({ args: rest, allowPositionals: true, options: { record: { type: 'string' }, allow: { type: 'string' } } });
  } catch (e) { die(e.message); }
  const { values: o, positionals } = parsed;
  if (cmd === 'db') {
    if (!positionals[0]) die('db <url> --record <services.json>');
    const r = checkUrl(positionals[0], recordPorts(o.record), { data: true });
    if (r.skip) die('db: not a URL');
    const where = `${r.t.host}:${r.t.port}`;
    if (!r.ok) die(`REFUSED ${where}: ${r.why}`);
    console.log(`ok ${where}`);
  } else if (cmd === 'env') {
    if (!positionals.length) die('env <file>... --record <services.json> [--allow KEY,KEY]');
    const ports = recordPorts(o.record);
    const allow = new Set((o.allow || '').split(',').map((s) => s.trim()).filter(Boolean));
    let bad = 0;
    for (const file of positionals) {
      let text;
      try { text = fs.readFileSync(file, 'utf8'); } catch (e) { die(`cannot read ${file}: ${e.message}`); }
      for (const [key, value] of parseEnv(text)) {
        const r = checkUrl(value, ports);
        if (r.skip) continue;
        const where = `${r.t.scheme}://${r.t.host}${r.t.port ? `:${r.t.port}` : ''}`;
        if (r.ok) console.log(`ok       ${key} ${where}`);
        else if (allow.has(key) && r.why === 'not loopback') console.log(`real     ${key} ${where} (enabled by the user)`);
        else { bad++; console.log(`REFUSED  ${key} ${where}: ${r.why}`); }
      }
    }
    if (bad) die(`${bad} target(s) refused; point them at this session's services or fakes, or ask the user to enable them`);
  } else {
    die('guard.mjs db <url> --record <services.json> | env <file>... --record <services.json> [--allow KEY,KEY]');
  }
}

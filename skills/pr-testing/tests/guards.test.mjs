// node --test skills/pr-testing/tests/*.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { checkUrl, parseEnv } from '../scripts/guard.mjs';

const DIR = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../scripts');
const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'prt-g-'));

function record(dir) {
  const file = path.join(dir, 'services.json');
  fs.writeFileSync(file, JSON.stringify({ version: 1, services: [{ name: 'postgres', ports: [55400] }, { name: 'mail', ports: [55401, 55402] }] }));
  return file;
}

test('db guard: only loopback on a recorded port', () => {
  const ports = new Set([55400]);
  assert.equal(checkUrl('postgres://postgres@127.0.0.1:55400/app', ports, { data: true }).ok, true);
  assert.equal(checkUrl('postgres://postgres@127.0.0.1:5432/app', ports, { data: true }).ok, false, "developer's own Postgres");
  assert.equal(checkUrl('postgres://u:p@db.prod.example.com:55400/app', ports, { data: true }).ok, false);
  assert.equal(checkUrl('postgres://localhost/app', ports, { data: true }).ok, false, 'default port is not recorded');
  const rec = record(tmp());
  const r = spawnSync(process.execPath, [path.join(DIR, 'guard.mjs'), 'db', 'postgres://u:secretpw@10.0.0.9:5432/x', '--record', rec], { encoding: 'utf8' });
  assert.equal(r.status, 1);
  assert.match(r.stderr, /REFUSED 10\.0\.0\.9:5432/);
  assert.doesNotMatch(r.stderr + r.stdout, /secretpw/, 'never prints credentials');
});

test('env guard: refuses real endpoints unless the user enabled that key', () => {
  const d = tmp();
  const rec = record(d);
  const env = path.join(d, 'runtime.env');
  fs.writeFileSync(env, [
    'DATABASE_URL=postgres://postgres@127.0.0.1:55400/app',
    'SMTP_URL="smtp://127.0.0.1:55401"',
    'STRIPE_API_BASE=https://api.stripe.com',
    'FEATURE_X=1',
    'export REDIS_URL=redis://127.0.0.1:6379/0',
  ].join('\n'));
  assert.equal(parseEnv(fs.readFileSync(env, 'utf8')).length, 5);
  let r = spawnSync(process.execPath, [path.join(DIR, 'guard.mjs'), 'env', env, '--record', rec], { encoding: 'utf8' });
  assert.equal(r.status, 1);
  assert.match(r.stdout, /REFUSED  STRIPE_API_BASE/);
  assert.match(r.stdout, /REFUSED  REDIS_URL .*port not in/);
  fs.writeFileSync(env, 'DATABASE_URL=postgres://postgres@127.0.0.1:55400/app\nSTRIPE_API_BASE=https://api.stripe.com\n');
  r = spawnSync(process.execPath, [path.join(DIR, 'guard.mjs'), 'env', env, '--record', rec, '--allow', 'STRIPE_API_BASE'], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /real {5}STRIPE_API_BASE/);
});

test('clean-env: inherited credentials are dropped, files and --set apply in order', () => {
  const d = tmp();
  const a = path.join(d, 'a.env');
  fs.writeFileSync(a, 'APP_MODE=test\nDATABASE_URL=postgres://127.0.0.1:55400/app\n');
  const out = execFileSync(path.join(DIR, 'clean-env.sh'), ['--env', a, '--set', 'APP_MODE=override', '--', '/usr/bin/env'], {
    encoding: 'utf8',
    env: { ...process.env, OPENAI_API_KEY: 'sk-real', AWS_SECRET_ACCESS_KEY: 'real', DATABASE_URL: 'postgres://prod/db' },
  });
  assert.doesNotMatch(out, /OPENAI_API_KEY|AWS_SECRET_ACCESS_KEY|postgres:\/\/prod/);
  assert.match(out, /^APP_MODE=override$/m);
  assert.match(out, /^DATABASE_URL=postgres:\/\/127\.0\.0\.1:55400\/app$/m);
  assert.match(out, /^PATH=/m);
});

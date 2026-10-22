// The harness layer must not claim features a harness lacks.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { spawnSync, execSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const SH = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../scripts/harness.sh');
const run = (h, ...args) => {
  const env = { PATH: process.env.PATH, HOME: '/tmp/prt-home' };
  if (h === 'bb') Object.assign(env, { BB_THREAD_ID: 'thr_test1234', BB_THREAD_STORAGE: '/tmp/prt-storage' });
  if (h === 'claude-code') env.CLAUDECODE = '1';
  if (h === 'codex') env.PR_TESTING_HARNESS = 'codex';
  return spawnSync('sh', [SH, ...args], { encoding: 'utf8', env });
};

test('no harness: nothing pretends to notify, spawn, or share', () => {
  assert.match(run('none', 'features').stdout, /notify=no\nimplementer=none\nprocess=detached\nshare=local/);
  assert.equal(run('none', 'notify-target').stdout.trim(), 'none');
  const s = run('none', 'spawn-implementer', '--brief', SH, '--title', 't');
  assert.equal(s.status, 1);
  assert.match(s.stderr, /no workers here/);
  assert.equal(run('none', 'share', '4000').stdout.trim(), 'local http://127.0.0.1:4000/');
  assert.equal(run('none', 'storage').stdout.trim(), '/tmp/prt-home/.agents/pr-testing/default');
});

test('Claude Code and Codex: no notify bridge; implementer printed as a tool call', () => {
  for (const h of ['claude-code', 'codex']) {
    assert.match(run(h, 'features').stdout, /notify=no/);
    assert.equal(run(h, 'notify-target').stdout.trim(), 'none');
  }
  assert.match(run('claude-code', 'spawn-implementer', '--brief', SH, '--title', 't').stdout, /isolation: "worktree"/);
  assert.match(run('codex', 'spawn-implementer', '--brief', SH, '--title', 't').stdout, /create its own git worktree/);
  assert.equal(run('codex', 'invoke').stdout.trim(), '$pr-testing');
});

test('bb: notify target is this thread; storage is thread storage', () => {
  assert.equal(run('bb', 'notify-target').stdout.trim(), 'bb:thr_test1234');
  assert.equal(run('bb', 'storage').stdout.trim(), '/tmp/prt-storage');
  assert.match(run('bb', 'features').stdout, /notify=yes\nimplementer=thread-worktree\nprocess=terminal/);
});

test('bad input exits 1 with usage', () => {
  assert.equal(run('none', 'share', 'x; rm -rf /').status, 1);
  assert.equal(run('none', 'run', '--title', 't').status, 1);
  assert.equal(run('none', 'stop-run', 'abc').status, 1);
  assert.equal(run('none', 'bogus').status, 1);
});

test('outside bb, stop-run stops the started process and its children', async () => {
  const d = fs.mkdtempSync(path.join(os.tmpdir(), 'prt-h-'));
  const r = run('none', 'run', '--title', 't', '--log', path.join(d, 'x.log'), '--cwd', d, '--', 'sh', '-c', 'sleep 300 & sleep 301; wait');
  assert.equal(r.status, 0, r.stderr);
  const pid = /handle (\d+)/.exec(r.stdout)[1];
  await new Promise((res) => setTimeout(res, 300));
  const alive = () => execSync('ps -eo command', { encoding: 'utf8' }).split('\n').filter((l) => /^sleep 30[01]$/.test(l.trim())).length;
  assert.equal(alive(), 2);
  assert.match(run('none', 'stop-run', pid).stdout, /stopped/);
  await new Promise((res) => setTimeout(res, 300));
  assert.equal(alive(), 0, 'no orphaned children');
});

#!/usr/bin/env node
// clean-env.mjs — run a command with none of the caller's environment except the basics,
// so real-provider credentials in the agent's shell never reach the app under test.
//
//   clean-env.mjs [--env FILE]... [--set KEY=VALUE]... -- CMD [ARG]...
//
// Kept from the caller: PATH HOME USER LOGNAME TMPDIR LANG LC_ALL TERM.
// Each --env file is read as dotenv, literally (no $ expansion, no command execution), with the
// same parser guard.mjs checks, then each --set. Later wins. Values are never printed.
import fs from 'node:fs';
import { spawn } from 'node:child_process';
import { parseEnv } from './guard.mjs';

const KEEP = ['PATH', 'HOME', 'USER', 'LOGNAME', 'TMPDIR', 'LANG', 'LC_ALL', 'TERM'];

function die(msg) { process.stderr.write(`clean-env: ${msg}\n`); process.exit(1); }

const args = process.argv.slice(2);
const env = Object.fromEntries(KEEP.filter((k) => process.env[k] !== undefined).map((k) => [k, process.env[k]]));
env.SHELL = '/bin/sh';
let i = 0;
for (; i < args.length; i++) {
  const a = args[i];
  if (a === '--') { i++; break; }
  if (a === '--env') {
    const file = args[++i];
    let text;
    try { text = fs.readFileSync(file, 'utf8'); } catch { die(`no such env file: ${file}`); }
    for (const [k, v] of parseEnv(text)) env[k] = v;
  } else if (a === '--set') {
    const kv = args[++i] || '';
    const m = /^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/s.exec(kv);
    if (!m) die('--set needs KEY=VALUE');
    env[m[1]] = m[2];
  } else die(`unknown argument ${a} (clean-env.mjs [--env FILE]... [--set K=V]... -- CMD...)`);
}
const cmd = args.slice(i);
if (!cmd.length) die('no command');

const child = spawn(cmd[0], cmd.slice(1), { env, stdio: 'inherit', shell: false });
child.on('error', (e) => die(`cannot start ${cmd[0]}: ${e.message}`));
for (const sig of ['SIGTERM', 'SIGINT', 'SIGHUP']) process.on(sig, () => child.kill(sig));
child.on('exit', (code, sig) => process.exit(code ?? (sig ? 128 : 1)));

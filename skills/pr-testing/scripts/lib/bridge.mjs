// Delivery of saved submissions to the coordinating agent.
// The core never knows the harness: it hands a submission to the bridge chosen at startup.
//
//   none          save only; the dashboard offers copy/export and says no agent was woken
//   bb:<thread>   `bb thread tell <thread> --mode auto --json --message-file -`, no shell,
//                 message on stdin; the thread id is fixed when the server starts
import { execFile } from 'node:child_process';

const THREAD_RE = /^thr_[A-Za-z0-9_-]{4,64}$/;

const MEANING = {
  feedback: 'Send feedback — discussion only. Do not start fixes; reply and agree on next steps with the user.',
  'fix-request': 'Request fixes — the user authorizes one fresh implementer for the failed or blocked cases and notes below.',
  complete: 'Testing complete — notification only. This is not merge authorization.',
};

export function messageFor(sub, { dashboardUrl } = {}) {
  const lines = [
    `[pr-testing] ${sub.kind} · PR #${sub.pr} @ ${sub.sha.slice(0, 12)} · submission ${sub.id}`,
    MEANING[sub.kind],
    `PR: ${sub.title || ''}${sub.url ? ` (${sub.url})` : ''}`,
    `Tested SHA: ${sub.sha}`,
    `Totals: ${Object.entries(sub.summary).filter(([, v]) => v).map(([k, v]) => `${k} ${v}`).join(' · ') || 'none'}`,
  ];
  if (sub.message) lines.push('', 'Message from the user:', quote(sub.message));
  const noted = sub.cases.filter((c) => c.status !== 'pass' || c.note);
  if (noted.length) {
    lines.push('', 'Cases:');
    for (const c of noted) lines.push(`- ${c.id} [${c.status}] ${c.title}${c.note ? `\n${quote(c.note, '    ')}` : ''}`);
  }
  if (dashboardUrl) lines.push('', `Dashboard: ${dashboardUrl}`);
  lines.push('', `Acknowledge after acting: dashboard.mjs ack ${sub.id}`);
  return lines.join('\n');
}

function quote(s, pad = '') { return s.split('\n').map((l) => `${pad}> ${l}`).join('\n'); }

export function parseTarget(target = 'none') {
  if (target === 'none') return { kind: 'none' };
  const m = /^bb:(.+)$/.exec(target);
  if (m && THREAD_RE.test(m[1])) return { kind: 'bb', thread: m[1] };
  throw new Error(`invalid notify target: ${target} (none | bb:<thread id>)`);
}

export function features(target) {
  const t = parseTarget(target);
  return {
    notify: t.kind !== 'none',
    bridge: t.kind,
    // What the buttons do in this harness, shown verbatim in the UI.
    deliveryNote: t.kind === 'none'
      ? 'Saved here only — this setup cannot wake the agent. Copy the text into the chat.'
      : 'Sent straight to the agent thread.',
  };
}

// Returns { state: 'sent' | 'queued' | 'failed', detail }.
export function createBridge(target, { exec = execFile, bin = 'bb', timeoutMs = 30000 } = {}) {
  const t = parseTarget(target);
  if (t.kind === 'none') {
    return { kind: 'none', deliver: async () => ({ state: 'saved', detail: 'no bridge in this harness' }) };
  }
  return {
    kind: 'bb',
    deliver: (text) => new Promise((resolve) => {
      const child = exec(bin, ['thread', 'tell', t.thread, '--mode', 'auto', '--json', '--message-file', '-'],
        { shell: false, timeout: timeoutMs, maxBuffer: 1 << 20, windowsHide: true },
        (err, stdout) => {
          let out = null;
          try { out = JSON.parse(String(stdout || '').trim() || 'null'); } catch { /* not JSON */ }
          if (out && out.ok === true && (out.delivery === 'sent' || out.delivery === 'queued')) {
            const detail = out.delivery === 'queued'
              ? `queued in the thread${out.queuedMessage?.waitingOn ? ` (waiting on ${out.queuedMessage.waitingOn})` : ''}; delivers when it settles — do not resend`
              : 'delivered to the agent thread';
            resolve({ state: out.delivery, detail });
          } else {
            const reason = out?.error?.message || err?.message || 'unexpected reply from bb';
            resolve({ state: 'failed', detail: String(reason).slice(0, 300) });
          }
        });
      child.stdin?.on('error', () => {});
      child.stdin?.end(text);
    }),
  };
}

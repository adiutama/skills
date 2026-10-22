// Renders what the agent wrote; never invents checks. Plain DOM, no build step.
'use strict';

const LABELS = { pending: 'Pending', pass: 'Pass', fail: 'Fail', blocked: 'Blocked', 'needs-retest': 'Needs retest' };
const CHOICES = ['pending', 'pass', 'fail', 'blocked'];
const STATE_TEXT = {
  saved: 'Saved',
  sending: 'Sending…',
  sent: 'Sent to the agent',
  queued: 'Queued — the agent gets it when its current question is answered',
  failed: 'Not delivered',
};
const KIND_TEXT = { feedback: 'Feedback', 'fix-request': 'Fix request', complete: 'Testing complete' };

let csrf = '';
let features = { notify: false };
let current = null; // the PR view on screen
let busy = false;
const pendingKeys = {}; // kind+pr+sha → idempotency key, kept until the server answers

const $ = (id) => document.getElementById(id);

async function api(path, body) {
  const opts = body === undefined ? {} : {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-PRT-CSRF': csrf },
    body: JSON.stringify(body),
  };
  const res = await fetch(path, { credentials: 'same-origin', ...opts });
  let data = null;
  try { data = await res.json(); } catch { /* not JSON */ }
  if (res.status === 409) await refresh(true);
  if (!res.ok) throw Object.assign(new Error(data?.error || `HTTP ${res.status}`), { data, status: res.status });
  return data;
}

function short(sha) { return sha ? sha.slice(0, 12) : ''; }

function selectedPr(state) {
  const m = /pr=(\d+)/.exec(location.hash);
  if (m && state.prs.some((p) => p.number === Number(m[1]))) return Number(m[1]);
  if (state.session.active && state.prs.some((p) => p.number === state.session.active.pr)) return state.session.active.pr;
  return state.prs[0]?.number;
}

function renderRail(state, selected) {
  const list = $('pr-list');
  list.replaceChildren();
  $('rail-empty').hidden = state.prs.length > 0;
  for (const p of state.prs) {
    const li = document.createElement('li');
    const a = document.createElement('a');
    a.href = `#pr=${p.number}`;
    a.className = 'pr-item' + (p.number === selected ? ' is-selected' : '');
    if (p.number === selected) a.setAttribute('aria-current', 'page');
    const name = document.createElement('span');
    name.className = 'pr-name';
    name.textContent = `#${p.number} ${p.title || ''}`;
    a.append(name);
    if (state.session.active?.pr === p.number) {
      const live = document.createElement('span');
      live.className = 'pr-live';
      live.textContent = 'running now';
      a.append(live);
    }
    const bar = document.createElement('span');
    bar.className = 'bar';
    bar.setAttribute('aria-label', Object.entries(p.counts).map(([k, v]) => `${v} ${LABELS[k]}`).join(', '));
    for (const k of ['pass', 'fail', 'blocked', 'needs-retest', 'pending']) {
      if (!p.counts[k]) continue;
      const seg = document.createElement('i');
      seg.className = `seg s-${k}`;
      seg.style.flexGrow = p.counts[k];
      bar.append(seg);
    }
    a.append(bar);
    li.append(a);
    list.append(li);
  }
}

function renderTicket(pr, session) {
  $('ticket').hidden = false;
  $('pr-title').textContent = `#${pr.number} ${pr.title || ''}`;
  const link = $('pr-link');
  link.hidden = !pr.url;
  if (pr.url) { link.href = pr.url; link.textContent = 'Open on GitHub'; }
  $('pr-sha').textContent = short(pr.sha);
  $('pr-sha').title = pr.sha;
  const cell = $('app-cell');
  cell.replaceChildren();
  const active = session.active;
  if (active && active.pr === pr.number && active.sha === pr.sha && active.appUrl) {
    const a = document.createElement('a');
    a.href = active.appUrl; a.target = '_blank'; a.rel = 'noopener noreferrer';
    a.textContent = active.appUrl;
    cell.append(a);
  } else if (active && active.pr === pr.number) {
    cell.textContent = `Running ${short(active.sha)}, not this commit`;
  } else {
    cell.textContent = active ? `Not running — the app shows #${active.pr} now` : 'Not running';
  }
  const done = pr.cases.filter((c) => ['pass', 'fail', 'blocked'].includes(c.result.status)).length;
  $('progress').textContent = `${done} of ${pr.cases.length} checked`;
  const retest = pr.cases.filter((c) => c.result.status === 'needs-retest').length;
  const note = $('retest-note');
  note.hidden = !retest;
  note.textContent = retest ? `New commit. ${retest} check${retest > 1 ? 's' : ''} need${retest > 1 ? '' : 's'} a retest; earlier results are kept below each one.` : '';
}

function renderCase(c, pr) {
  const node = $('case-tpl').content.firstElementChild.cloneNode(true);
  node.dataset.status = c.result.status;
  node.querySelector('.case-id').textContent = c.id;
  node.querySelector('.case-title').textContent = c.title;
  const steps = node.querySelector('.steps');
  for (const s of c.steps) { const li = document.createElement('li'); li.textContent = s; steps.append(li); }
  node.querySelector('.expected span').textContent = c.expected;

  const prev = node.querySelector('.previous');
  if (c.result.previous) {
    prev.hidden = false;
    prev.textContent = `Before: ${LABELS[c.result.previous.status]} at ${short(c.result.previous.sha)}${c.result.previous.note ? ` — ${c.result.previous.note}` : ''}`;
  } else if (c.result.carried && c.result.testedSha && c.result.testedSha !== pr.sha) {
    prev.hidden = false;
    prev.textContent = `Result from ${short(c.result.testedSha)}; this check was not affected by the new commit.`;
  }

  const fs = node.querySelector('.verdict');
  if (c.result.status === 'needs-retest') {
    const tag = document.createElement('span');
    tag.className = 'retest-tag';
    tag.textContent = 'Needs retest';
    fs.append(tag);
  }
  const name = `v-${c.id}`;
  for (const k of CHOICES) {
    const label = document.createElement('label');
    label.className = `choice c-${k}`;
    const input = document.createElement('input');
    input.type = 'radio'; input.name = name; input.value = k;
    input.checked = c.result.status === k;
    input.addEventListener('change', () => save(node, pr, c.id, k));
    label.append(input, document.createTextNode(LABELS[k]));
    fs.append(label);
  }
  const note = node.querySelector('.note');
  note.value = c.result.note || '';
  note.addEventListener('change', () => {
    const checked = fs.querySelector('input:checked');
    save(node, pr, c.id, checked ? checked.value : 'pending');
  });
  return node;
}

async function save(node, pr, caseId, status) {
  const out = node.querySelector('.saved');
  out.textContent = 'Saving…';
  try {
    const { result } = await api('/api/result', { pr: pr.number, sha: pr.sha, caseId, status, note: node.querySelector('.note').value });
    node.dataset.status = result.status;
    const tag = node.querySelector('.retest-tag');
    if (tag) tag.remove();
    out.textContent = `Saved ${new Date(result.at).toLocaleTimeString()}`;
    refreshRail();
  } catch (e) {
    out.textContent = `Not saved: ${e.message}`;
  }
}

function renderSubs(pr) {
  const list = $('subs');
  list.replaceChildren();
  $('subs-wrap').hidden = !pr.submissions.length;
  for (const s of [...pr.submissions].reverse()) {
    const li = document.createElement('li');
    li.className = `sub st-${s.state}`;
    const head = document.createElement('p');
    head.textContent = `${KIND_TEXT[s.kind]} · ${new Date(s.createdAt).toLocaleString()} · ${short(s.sha)} — ${STATE_TEXT[s.state] || s.state}`;
    li.append(head);
    const last = s.attempts[s.attempts.length - 1];
    if (last?.detail && s.state !== 'saved') {
      const d = document.createElement('p'); d.className = 'muted'; d.textContent = last.detail; li.append(d);
    }
    if (s.state === 'failed' && features.notify) {
      const b = document.createElement('button');
      b.type = 'button'; b.className = 'btn btn-small'; b.textContent = 'Try sending again';
      b.addEventListener('click', async () => {
        b.disabled = true;
        try { await api(`/api/submissions/${s.id}/retry`, {}); } catch (e) { setStatus(`Not sent: ${e.message}`, 'bad'); }
        await refresh();
      });
      li.append(b);
    }
    if (s.copyText) li.append(copyButton(s.copyText));
    list.append(li);
  }
}

function copyButton(text) {
  const b = document.createElement('button');
  b.type = 'button'; b.className = 'btn btn-small'; b.textContent = 'Copy for chat';
  b.addEventListener('click', async () => {
    try { await navigator.clipboard.writeText(text); b.textContent = 'Copied'; }
    catch { window.prompt('Copy this text into the chat:', text); }
  });
  return b;
}

function setStatus(text, tone = '') {
  const el = $('status');
  el.textContent = text;
  el.dataset.tone = tone;
}

async function submit(kind) {
  if (!current || busy) return;
  const message = $('message').value.trim();
  if (kind === 'fix-request') {
    const failing = current.cases.filter((c) => ['fail', 'blocked'].includes(c.result.status)).length;
    const ok = window.confirm(`Ask the agent to start a fresh fix for ${failing} failed or blocked check${failing === 1 ? '' : 's'}${message ? ' and your note' : ''}?`);
    if (!ok) return;
  }
  const slot = `${kind}:${current.number}:${current.sha}:${message}`;
  pendingKeys[slot] ||= (crypto.randomUUID ? crypto.randomUUID() : String(Date.now()) + Math.random()).replace(/[^A-Za-z0-9_-]/g, '');
  busy = true;
  document.querySelectorAll('#actions button').forEach((b) => { b.disabled = true; });
  setStatus('Saving…');
  try {
    const { submission, duplicate } = await api('/api/submit', { kind, pr: current.number, sha: current.sha, message, key: pendingKeys[slot] });
    delete pendingKeys[slot];
    const word = STATE_TEXT[submission.state] || submission.state;
    const tone = submission.state === 'failed' ? 'bad' : submission.state === 'saved' && features.notify ? '' : 'good';
    setStatus(duplicate ? `Already sent earlier — ${word}.` : `${KIND_TEXT[kind]}: ${word}.${!features.notify ? ' Copy it into the chat below.' : ''}`, tone);
    if (!duplicate) $('message').value = '';
  } catch (e) {
    if (e.status) delete pendingKeys[slot];
    setStatus(e.status ? `Not saved: ${e.message}` : 'No answer from the dashboard. Press again — it will not send twice.', 'bad');
  } finally {
    busy = false;
    document.querySelectorAll('#actions button').forEach((b) => { b.disabled = false; });
    await refresh();
  }
}

let lastSig = '';
async function refresh(force = false) {
  const state = await api('/api/state');
  csrf = state.csrf;
  features = state.session.features;
  $('delivery-note').textContent = features.deliveryNote;
  const n = selectedPr(state);
  renderRail(state, n);
  if (!n) { $('empty').hidden = false; $('ticket').hidden = true; $('actions').hidden = true; $('cases').replaceChildren(); return; }
  const pr = await api(`/api/prs/${n}`);
  // Redraw checks only when the PR, its commit, or its case list changes, so ticking never steals focus.
  const sig = JSON.stringify([pr.number, pr.sha, pr.cases.map((c) => [c.id, c.title, c.steps, c.expected])]);
  const editing = document.activeElement && document.activeElement.classList.contains('note');
  current = pr;
  renderTicket(pr, state.session);
  renderSubs(pr);
  $('empty').hidden = true;
  $('actions').hidden = false;
  if (force || (sig !== lastSig && !editing)) {
    lastSig = sig;
    $('cases').replaceChildren(...pr.cases.map((c) => renderCase(c, pr)));
  }
}

async function refreshRail() {
  try { await refresh(); } catch { /* next poll retries */ }
}

document.querySelectorAll('#actions button').forEach((b) => b.addEventListener('click', () => submit(b.dataset.kind)));
$('actions').addEventListener('submit', (e) => e.preventDefault());
window.addEventListener('hashchange', () => { refresh(true).catch((e) => setStatus(e.message, 'bad')); });
refresh(true).catch((e) => setStatus(e.message, 'bad'));
setInterval(refreshRail, 5000);

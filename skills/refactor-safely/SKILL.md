---
name: refactor-safely
description: Beauty-first, safety-first refactor—reversible passes, behavior preserved. Clarity up; drift down.
disable-model-invocation: true
metadata:
  argument-hint: "[file-path|folder-path|symbol-name]"
allowed-tools: Read Write Edit rg Glob Bash
---

Invoked as `/refactor-safely [file-path|folder-path|symbol-name]`.

*Structure is meaning made visible—edit like a poem, **verify** like a proof.*

**Beauty-first**, **safety-first**, **reversible**: behavior unchanged unless asked; clarity up; performance neutral; security raised when cheap; no whole-module rewrites for local wins.

## Step 1 — Scope

Target from arg or context. Ambiguous → one ask; stop.

## Step 2 — Baseline

Read first. Lock behavior contracts (I/O, side effects, errors, edges). Tests exist → smallest relevant run before edits.

## Step 3 — Passes

[references/checklist.md](references/checklist.md) in small coherent slices—structure, naming, simplification, safeguards. Public APIs stable unless told otherwise.

## Step 4 — Verify

Re-run checks; add lightweight characterization tests if none. No silent drift.

## Step 5 — Report

1. **Intent** — one line improved.
2. **Changes** — 3–7 bullets (structure / readability / safety).
3. **Behavior guarantee** — how preserved.
4. **Validation** — what ran or couldn't.
5. **Residual risk** — if any.

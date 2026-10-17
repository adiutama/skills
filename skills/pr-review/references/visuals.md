# Visuals

Five visuals, one per reviewer question. Each has a **text form**, written into the report and readable anywhere; your **render** may draw it richer in chat from the same data. Keep only what answers the question: the files, calls, states, and boundaries that matter.

## Width and paths

Keep every line within ~100 characters so nothing wraps. In maps and trigger paths, shorten paths to their shortest unique form (drop shared prefixes such as `packages/` or `apps/`, and extensions when unambiguous). Trigger paths keep the line number on the short path (`ap/index:439`). The blast radius root may carry `path:line`; its leaves carry a short reason, never `path:line`. Exact full paths belong to findings.

## Change map — where do I start?

Files in the order a reviewer should read them (core change → its callers → glue → tests → the rest), with size, risk, and pinned findings. Group trivial files on one line.

```text
Reading order              +/-       risk  pins
① api/payments.ts          +42 −8    ●●●   C1 retry can double-charge
② lib/retry.ts             +30       ●●○   W1 no jitter
③ db/migrations/014.sql    +12       ●●●   one-way door
④ tests/payments.test.ts   +55       ○○○
   + 6 files: docs, types — skim
```

Risk: `●●●` high (money, data, security, contracts, irreversible) · `●●○` medium (logic, shared code) · `●○○` low · `○○○` tests, docs.

## Behavior diff — what actually changed?

Before → after of the *behavior*, never a copy of the code diff. Pick the shape that matches the change; usually one, rarely two. Calls, component trees, and file layouts use the same `diff` style on a tree.

Control flow or logic — pseudocode diff:

```diff
 on(charge)
-  call provider
+  call provider with retry(3)
+  on timeout: retry          ← C1: no idempotency key
   record payment
```

Data or contract — shape diff:

```diff
 Payment {
   id, amount
+  retry_count: int        (migration 014, not nullable)
 }
```

Rules or branching — decision table:

```diff
 extracted bank details    vendor account         → payee
+absent                    default or only one    → fallback
+exception                 —                      → needs_review (unclear_read)
+agreed                    known, active          → matched
+agreed                    new, holder kana ok    → add account → added    ← W1
```

Interaction between parts — numbered sequence:

```text
1. UI → API      POST /charge
2. API → Stripe  charge (retry ×3 on timeout)   ← C1
3. API → DB      insert payment
```

Show a whole block instead only when most of it is new.

## Blast radius map — what else does it touch?

A tree, read top to bottom. The root is the changed unit (★). Each branch is a kind of impact; each leaf is one specific dependent with its status, a one-line reason, and its pin.

```text
charge() ★  api/payments.ts:42
├─ called by
│  ├─ CheckoutService.pay       ✅ handles the new timeout error
│  └─ RefundWorker.retry        ⚠️ not checked
├─ data / contracts
│  └─ payments.retry_count      ✅ migration 014 · one-way door
├─ integrations
│  ├─ Stripe webhook            ❌ sees a second charge on retry  C1
│  └─ ledger nightly job        ✅ reads amount only
└─ sibling paths
   └─ refund()                  ✅ same pattern, already idempotent
not touched: wiring · operations
```

Branches, in this order, only when they have leaves — each asks one question:

| Branch | Question |
|---|---|
| called by / calls | Who calls the changed code, and what does it call? |
| wiring | Did adapters, middleware, registration, mappings change symmetrically? |
| data / contracts | Did an API, schema, event, config, or compatibility promise change? |
| sibling paths | Was one implementation changed while a sibling was missed? |
| integrations | What jobs, caches, webhooks, services, or deploy order depend on it? |
| operations | Can it be observed, deployed, rolled back, and migrated safely? |

Status as defined in the Judge step; every ⚠️ also goes under Coverage, every ❌ is pinned. Rings with no leaves go on the last line as `not touched:`. Several changed units → one root each, most important first.

## Trigger path — how is it reached?

A call stack from a real entry point (route, job, event, CLI command) down to the changed line, one frame per line with `path:line`. It is the proof that a finding is reachable.

```text
POST /checkout                 api/routes.ts:31
└─ CheckoutService.pay         services/checkout.ts:88
   └─ charge()  ★              api/payments.ts:42   ← C1 retry without idempotency key
      └─ stripe.charges.create
```

Skip frames that only pass arguments through; mark a skip with `…`. Several entry points → show the one the finding needs, then `also reached from: <entry>, <entry>`.

## Pins

A finding ID (`C1`, `W2`, …) placed on the change map row, blast radius leaf, or trigger path frame it affects, with its title in a few words. Every kept finding is pinned at least once; the Findings section has the details.

---

Behavior diff shapes adapted from Dex Horthy's [`show-me`](https://github.com/humanlayer/skills/blob/main/plugins/show-me/skills/show-me/SKILL.md) via Matt Pocock's [`pr`](https://github.com/mattpocock/skills/tree/main/skills/engineering/pr) skill.

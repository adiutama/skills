# Address-until-clear workflow

Default mode after fetch. Fetch-only stops before triage (`--fetch-only`).

## Round loop

```text
fetch → present → triage → address → refresh → continue?
```

| Phase | Action |
|-------|--------|
| **fetch** | `start-session.sh` → `findings.json`, update `meta.md` |
| **present** | Classify IDs; write `report.md` per `output.md` |
| **triage** | User picks IDs (`all`, subset, or `none`). Update `tracker.md` → Selected + Progress rows |
| **address** | Fix only selected **pending** items; minimal scope per finding |
| **refresh** | Re-run `start-session.sh` (same PR). Reconcile tracker: drop resolved IDs, mark stale |
| **continue** | Pending selected → address. New unresolved → ask triage. `total_count == 0` → done |

## Triage prompts

After present, ask once:

```text
Which findings should we address this round?
- IDs (e.g. C1, W2)
- all
- none (stop)
```

Record choice in `tracker.md` under **Selected this workflow** and add Progress rows with `pending`.

## Address rules

- One coherent pass per round; group by file when sensible.
- Do not start address until user confirms selection.
- After edits: summarize per ID what changed.
- Do not mark **addressed** until user confirms or refresh shows item gone.

## Refresh reconciliation

Compare fresh `findings.json` IDs to tracker:

| Tracker ID | Still in fetch? | Action |
|------------|-----------------|--------|
| pending | no | → **stale** (likely resolved on GitHub) |
| pending | yes | keep **pending** |
| addressed | no | keep **addressed** |
| addressed | yes | back to **pending** (fix insufficient) |

Append a **Rounds** row: round number, selected IDs, addressed this round, remaining pending.

## Exit

Stop when:

1. `total_count == 0` — print merge-ready message, or
2. User says done / none — print remaining IDs and session path for `resume`.

## Resume

Triggers: `resume`, `/address-pr-feedback resume`, `resume <pr-number>`.

```bash
bash <SKILL_DIR>/scripts/resolve-session.sh [pr-number]
```

1. No session → stop.
2. Show PR title, path, pending IDs from `tracker.md`, fresh counts.
3. **Wait for confirm** — continue triage, address pending, or refresh-only.
4. Never auto-start address without confirmation.

Legacy sessions may live under `.../fetch-outstanding-pr-feedback/pr-<N>/`. Migrate or use full path to resume.

## Fetch-only (verify / loop-until)

`--fetch-only` or `--list`: run through **present** only. Exit code semantics via counts in JSON:

- `total_count == 0` → merge-ready
- else → list findings, no triage

Used by `/loop-until` exit: `/address-pr-feedback` empty (`--fetch-only`).

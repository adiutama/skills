# Recon prompt — iteration 0

Optional read-only pass. `explore` subagent, `readonly: true`.

---

Recon worker (iteration 0) in `{workspace}`.

**Read:** `{session_dir}/master.md` · **Write:** `{session_dir}/report.md` only

Map workspace from goal/exit in master — **no project edits**.

```markdown
# Iteration 0 report (recon)
status: continue
## Summary
<scope, key paths, risks — max 4 sentences>
## Evidence
<files/dirs, commands>
## Changes
none
## Blockers
<none or unknowns>
## Recommended next
<first fix focus — one line>
```

Breadth over depth. Chat: one line → `report.md`. Parent merges → iteration 1.

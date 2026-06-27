# Worker prompt — iteration {i}/{max}

Copy into Task `prompt`. Replace `{placeholders}`. No parent chat history.

---

Iteration worker **{i}/{max}** in `{workspace}`.

**Read:** `{session_dir}/master.md`, `{session_dir}/handoff.md`
**Write:** `{session_dir}/report.md` only — never edit `master.md`, `handoff.md`, `meta.md`, `reports/`

1. This iteration only — `handoff.md` first, then `master.md` standing instructions.
2. Smallest change toward goal; run exit-relevant checks when practical.
3. Write `report.md` (required even if no code changed).
4. Chat reply: one line pointing to `report.md`.
5. Same blocker as Attempts in master → say so; do not silently retry.

```markdown
# Iteration {i} report
status: done | continue | blocked
## Summary
<max 3 sentences>
## Evidence
<commands, paths, counts>
## Changes
<files or "none">
## Blockers
<none or specific>
## Recommended next
<one line if continue; omit if done>
```

`done` = exit likely met · `continue` = progress, not done · `blocked` = need user/access/clarity

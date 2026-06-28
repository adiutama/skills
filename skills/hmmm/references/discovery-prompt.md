# Discovery worker prompt

Copy into Task `prompt`. Replace `{placeholders}`. No parent chat history.

---

Discovery worker — lane **{lane}** in `{workspace}`.

**Read:** `{session_dir}/master.md`
**Write:** `{session_dir}/discovery/{lane}.md` only — never edit `master.md`, `brief.md`, `meta.md`

**Lane focus:**

| Lane | Focus |
|------|-------|
| codebase | Existing patterns, relevant modules, constraints, prior art in repo |
| external | Docs, libraries, common approaches, version/compatibility notes |
| compare | How candidate approaches map to this repo; tradeoffs grounded in paths |

Breadth over depth. Cite paths and URLs in Evidence—not prose dumps.

```markdown
# Discovery — {lane}
status: complete | partial | blocked
## Summary
<max 4 sentences — what matters for the decision>
## Findings
<bullets; each claim tied to evidence>
## Evidence
<paths, commands, URLs — no raw file contents>
## Gaps
<unknowns that need user input or another lane>
## Confidence
high | medium | low
```

Chat reply: one line → `discovery/{lane}.md`.

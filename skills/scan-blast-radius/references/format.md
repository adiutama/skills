# Output format

## Verdict

| Verdict | Meaning |
|---------|---------|
| **safe to commit** | No critical/warning findings; notes acknowledged or none |
| **address first** | Fix or verify warnings before commit |
| **known risk** | User explicitly accepts remaining warnings |

Do not commit from this skill. User commits only when verdict allows.

## Chat summary (print after saving)

```text
Blast radius — <branch> (pass <NN>)
Change: fix | feature | rewire · Intent: <one line>
N critical · N warning · N note
Verdict: <safe to commit | address first | known risk — user confirmed>
Saved: ~/.agents/artifacts/<owner>/<repo>/<slug>/scan-blast-radius/<NN>.md
Next: user decides — commit, widen review, or fix findings first
```

## Session file skeleton

Use `assets/template.md`. Fill all sections; empty findings → ring table all `checked` or `n/a` with brief notes.

## Finding block

```markdown
### I1 — <short title>

| Field | Value |
|-------|-------|
| Severity | critical / warning / note |
| Ring | direct / glue / contract / parallel / integration / operational |
| Surface | `path` or module/system name |
| Concern | one line |

**Why it might break:** 2–3 sentences.

**Suggested check:** concrete command, file read, or test to run.
```

Rules:
- Surface may be outside the diff — that is expected for blast radius.
- Every warning+ must have a suggested check.
- Do not duplicate review-diff style nits (style/clarity) unless they indicate a wiring mistake.

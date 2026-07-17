# Code-change guide

Generate `HTML_PATH` before the first learner question, then regenerate it whenever the code model materially changes, the PR revision changes, or the session closes. Use `<SKILL_DIR>/assets/study.html`; keep CSS and JavaScript inline.

The page teaches the code change. Organize it by the system and execution path—not by conversation order, commits, or diff order. The learner should understand the broad change before asking questions.

## Reading order

1. **Change at a glance** — claimed goal, observable effect, scope, pinned SHA, last-checked time, and important unknowns in plain language.
2. **Before / after** — the smallest table or diagram that makes the behavior delta obvious.
3. **Main path** — entry point → changed components → state or output, with an ASCII/SVG diagram and expandable code trail.
4. **Files and roles** — every touched file grouped by responsibility; say what role it plays and why this PR touches it. Do not list filenames without meaning.
5. **System context** — callers, consumers, dependencies, ownership, and boundaries needed to understand implications.
6. **Contracts and proof** — invariants, API/schema/config changes, tests, and what each test demonstrates or leaves unproven.
7. **Concepts** — compact glossary and analogy only where it lowers cognitive load.
8. **Revision timeline** — observed SHAs and which learning stayed valid, changed, resolved, needs recheck, or became superseded.
9. **Unknowns and review leads** — separate author questions from hypotheses worth checking later.
10. **Session appendix** — learner annotations, corrected misconceptions, Q&A, and teach-back. Keep this collapsed by default.

## Rules

- Synthesize repeated questions into the relevant code section; do not make the page read like chat history.
- Lead with behavior and flow. Keep commit metadata and chronological notes secondary.
- Cite each technical claim with a diff location or `path:line` and checked SHA.
- Use small excerpts; never paste the full diff.
- Use the visual chooser in `<SKILL_DIR>/references/explanations.md` and avoid decorative diagrams.
- Keep detailed code trails collapsible so the first screen stays approachable.
- Browser interactions do not return automatically. An attached annotated screenshot is explicit input about the learner's model and must be checked against code.

Interaction requirements: section navigation, collapsible code trails and appendix, compact/expanded view, provenance filters, print styles, no network requests, no framework, no build step.

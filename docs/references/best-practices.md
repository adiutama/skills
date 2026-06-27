# Skill best practices

## Design principles

- Optimize for execution clarity first; voice and leading words serve compactness without losing control.
- Keep commands explicit, deterministic, and easy to run.
- Prefer **distilled** instructions—lean and alive—not hollow cuts or cold spec voice.
- Treat proven patterns in existing skills as valid defaults.

## Naming

- Use `verb-object[-qualifier]` in kebab-case.
- Keep directory name and `name:` in frontmatter identical.
- Prefer command-like names (for example: `/review-pr`, `/submit-pr-review`).

## SKILL.md authoring

- Start with a clear invocation contract.
- Define required arguments and fail-fast behavior ("ask once and stop").
- Prefer `## Step N — Title` for procedural workflows.
- Use protocol sections (`Goal`, `Protocol`, `Rules`) for always-on behavior skills.

## Building new skills

Treat every new skill as **standalone**. Preconfigured modularity is not available—no routers, chains, or skill-to-skill handoffs in prose.

**Voice and leading words are required**, not a follow-up polish pass—see [Voice and compression](#voice-and-compression).

### Self-contained by default

- Put the full workflow in `SKILL.md`; branch detail in this skill's `references/`; repeatable logic in this skill's `scripts/`.
- Link runtime paths as `<SKILL_DIR>/references/...` or `skills/<skill-name>/...`—never another skill's tree.
- If two skills would share behavior, **duplicate the needed slice** into each skill's package. Extract to repo `docs/` only for author drafting—not as a runtime dependency between skills.

### Duplicate, don't reference

When a new skill needs a concept another skill already defines (output schema, gate, checklist, format):

1. Copy the minimum needed into `skills/<this-skill>/references/` or `assets/`.
2. Trim to what **this** skill uses—no cargo-culting the whole file.
3. Note the source in a one-line comment at the top of the copy if helpful for future merges (*"Adapted from review-pr format"*).
4. Do **not** link runtime instructions to the other skill's path.

Modularity may arrive later; until then, **fork in place**. Prefer slight duplication over fragile coupling.

### Do not

- Say "run `/other-skill` next" or "when X, use the Y skill."
- Assume another skill's description is loaded or that the agent will chain skills autonomously.
- Split one workflow across skills that only work together.
- Reference another skill's `references/` or `scripts/` at runtime—copy instead.

### Do

- Finish in one invocation: inputs → steps → deterministic output.
- State tools, confirmations, and artifact paths inside the skill.
- Prefer `disable-model-invocation: true` unless auto-discovery is a deliberate product choice.
- **Duplicate shared concepts** into this package when needed; dedupe only when modularity exists.

### Independence check

Before shipping a new skill, ask: *If this is the only skill loaded, can the agent complete the job with only this package?* No → fold missing material in or narrow scope.

## Workflow quality

- Separate execution workflow from output formatting rules.
- Model multi-pass behavior explicitly when relevant (for example pass 01 vs pass 02+).
- Make output deterministic: IDs, fields, counts, and summary format.
- Define dedup/status semantics explicitly when needed (for example `❌ / ✅ / ✅ dup`).
- Call out parallelizable context loading where useful.

## Safety and scope

- Keep non-negotiable constraints explicit.
- State when to confirm, when to stop, and what must never be done.
- Keep tool/dependency assumptions explicit in frontmatter when relevant.

## Voice and compression

**Goal:** beautiful, powerful, lean—raise signal, not delete soul.

### Voice

- Open with one or two lines that set intent when it helps trust or boundaries—not decoration.
- Keep gates, confirmations, and never-dos in readable prose.
- Cut filler, duplicated rules, and **ornament** (pretty lines that change nothing).
- If cutting a sentence changes behavior, it stays—even when poetic.

### Leading words

- Name 2–4 concepts the skill thinks with; use words the model already understands deeply.
- Front-load them in the **description** for reliable invocation.
- **Collapse triads:** three sentences for one idea → one leading word (_tight_, _oblivion_, _red_).
- Do not repeat the *meaning* in different words—that is **duplication**. Repeat the *token* on purpose—that is a leading word.

### What to extract

- Repeatable walks (glob trees, file discovery, formatting) → `scripts/`.
- Long conditional detail only some paths need → `references/` behind clear pointers.
- Prose keeps *when*, *what returns*, and *on failure*.

### Quality bar

Before finalizing, ask:

1. Still know what to do?
2. Still know what must never happen?
3. Still sound like someone who trusts you?

All yes and shorter → **distilled**. Any no → **hollow**. A promise broke in a later pass → **oblivion** (revert to the last good draft).

Reference: `skills/refine-skill/SKILL.md`, `skills/refine-skill/references/voice.md`.

## Token efficiency

- Remove repeated prose; collapse meaning into leading words where it anchors behavior.
- Prefer precise verbs and stable domain terms.
- Keep reference files focused by purpose (`checklist.md`, `format.md`, `output.md`).

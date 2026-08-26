# Voice and structure

*Poetry marks the boundary. Plain English moves the work.*

| Term | Meaning |
|------|---------|
| **Distilled** | Shorter; behavior, constraints, clarity, and voice survive |
| **Hollow** | Shorter, but meaning or voice is weaker |
| **Oblivion** | A revision broke a promise; restore the last valid version |

## The test

Check three levels:

1. **At a glance:** Is the workflow visible?
2. **On reading:** Is the prose human and easy to understand?
3. **In execution:** Are actions, safety rules, and stop conditions precise?

All yes and shorter → **distilled**. Any no → **hollow**. A broken promise → **oblivion**.

## Poetry and precision

A poetic boundary may guide judgment. The instruction beneath it must remain literal.

```markdown
## Step 3 — Verify the result

*Green means the evidence agrees—not that the work merely ended.*

Run `<verification command>`.

If the command fails, record the failure and continue working.

**Done when:** the command succeeds and every exit condition is satisfied.
```

## Quotations

Keep a quotation only when it is short, relevant, understandable, and verified. Record its author and source. Never place a requirement only inside the quotation.

If the exact wording or source is uncertain, write an original boundary line instead.

## Redundant safety

**Before** — one gate, three times:

```markdown
Before making any changes to production files, you should always make sure to ask the user for confirmation first. Do not proceed without getting explicit approval from the user. It is important that you never overwrite files unless the user has clearly said it is okay.
```

- **Hollow:** Ask before overwriting.
- **Distilled:** Never overwrite without explicit confirmation.

## Workflow repetition

**Before** — two steps, one action:

```markdown
## Step 1 — Gather context

First, gather all relevant context. Read the diff and understand which files were modified.

## Step 2 — Read the diff

Read the git diff carefully to see what changed in each file.
```

- **Hollow:** `1. Read diff.`
- **Distilled:**

```markdown
## Step 1 — Gather context

Read the diff. Record which files changed and why.

**Done when:** every changed file has a known purpose.

## Step 2 — Review behavior

Review each hunk for behavior, not only syntax.
```

## Voice stripped

**Before:** *Work as an editor of meaning, not a minimizer of characters. Leave a trace of the human—concise, deliberate; not telegraphic unless they asked.*

- **Hollow:** Edit for meaning. Be concise.
- **Distilled:** Edit meaning, not character count. Stay concise and human; use telegraphic language only when requested.

## Repeatable logic

**Before** — prose walks the tree every time:

```markdown
When the user provides a folder path, recursively search that directory for markdown files, text files, and prompt files. Walk all subdirectories. Exclude anything under scripts/, binary files, lockfiles, and files ending in .optimized.md. Collect the paths, sort them, and if there is more than one file, show the list and ask whether to optimize all files or only selected ones.
```

- **Hollow:** `Glob **/*.md; ask user.`
- **Distilled:**

```markdown
Run `bash <SKILL_DIR>/scripts/discover-targets.sh "<FOLDER>"`.

If the command returns one candidate, refine it.

If the command returns multiple candidates, list them and ask whether to refine all or selected files.
```

The script owns the file walk. Prose owns the decision.

## Oblivion

**Before:** Write a temporary file. Ask before overwriting the original.

**Broken revision:** Write the result over the original when ready.

**Oblivion:** The confirmation promise broke. Discard the revision and restore the last valid version.

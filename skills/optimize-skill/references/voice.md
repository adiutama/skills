# Voice

**Distilled** = lean and alive. **Hollow** = short but dead. **Oblivion** = looked lean, broke a promise.

**The test** — still know what to do, what must never happen, and sound like someone who trusts you? All yes and shorter → **distilled**. Any no → **hollow**. Promise broke later → **oblivion**.

## Redundant safety

**Before** — same gate, three times:

```markdown
Before making any changes to production files, you should always make sure to ask the user for confirmation first. Do not proceed without getting explicit approval from the user. It is important that you never overwrite files unless the user has clearly said it is okay.
```

- **Hollow:** Ask before overwriting.
- **Distilled:** Never overwrite without explicit confirmation.

## Workflow echo

**Before** — two steps, one action:

```markdown
## Step 1 — Gather context
First, you need to gather all of the relevant context about the change. Read the diff and understand what files were modified.

## Step 2 — Read the diff
Once you have gathered context, read through the git diff carefully to see exactly what changed in each file.
```

- **Hollow:** `1. Read diff.`
- **Distilled:**

```markdown
## Step 1 — Gather context
Read the diff; note which files changed and why.

## Step 2 — Review
Walk each hunk for behavior, not just syntax.
```

## Voice stripped

**Before:** *Work as an editor of meaning, not a minimizer of characters. Leave a trace of the human—concise, deliberate; not telegraphic unless they asked.*

- **Hollow:** Edit for meaning. Be concise.
- **Distilled:** Edit for meaning, not character count. Concise and deliberate—telegraphic only if they asked.

## Repeatable logic → script

**Before** — prose walks the tree every time:

```markdown
When the user provides a folder path, recursively search that directory for markdown files, text files, and prompt files. Walk all subdirectories. Exclude anything under scripts/, binary files, lockfiles, and files ending in .optimized.md. Collect the paths, sort them, and if there is more than one file, show the list and ask whether to optimize all files or only selected ones.
```

- **Hollow:** `Glob **/*.md; ask user.`
- **Distilled:**

```markdown
bash <SKILL_DIR>/scripts/discover-targets.sh "<FOLDER>" → candidates.
One: distill it. Many: list; ask all or selected.
```

Prose keeps the decision; the script keeps the walk.

## Oblivion

**Before:** temp file + ask before overwrite; never overwrite without confirmation.

**Pass two:** `Write optimized output; overwrite when ready.`

- **Oblivion:** Broke confirmation. Discard pass two; return to pass one.

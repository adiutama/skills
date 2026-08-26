---
name: refine-skill
description: Refine skill docs and prompts—remove needless words, move repeated work to scripts, preserve behavior and voice. Use for paths or text to tighten or distill.
disable-model-invocation: true
metadata:
  argument-hint: "[folder-path|file-path|plain-text]"
allowed-tools: Read Write Glob rg Bash
---

Invoked as `/refine-skill [folder-path|file-path|plain-text]`.

# Refine skill

> “Omit needless words.”
> — William Strunk Jr., [*The Elements of Style*, Rule 13](https://www.gutenberg.org/files/37134/37134-h/37134-h.htm)

*Leave less on the page. Leave everything that matters.*

Refine meaning, not character count: prose holds judgment; literal steps hold action; scripts hold mechanics.

| Term | Meaning |
|------|---------|
| **Distilled** | Shorter; behavior, constraints, clarity, and voice survive |
| **Hollow** | Shorter, but meaning or voice is weaker |
| **Oblivion** | A revision broke a promise; discard it and restore the last valid version |

Paired examples: [voice.md](references/voice.md).

## Step 1 — Resolve the input

| Input | Action |
|-------|--------|
| Plain text | Refine it; return the result in chat |
| File | Read and refine it |
| Folder | Run `bash <SKILL_DIR>/scripts/discover-targets.sh "<FOLDER>"` |

For a folder, refine the only candidate. If there are multiple candidates, list them and ask whether to refine all or selected files.

**Done when:** the run has plain text or an exact set of files.

## Step 2 — Protect the promises

*Do not cut what the instruction cannot live without.*

Record each target's promises:

- required behavior;
- what must never happen;
- gates, confirmations, and completion criteria;
- necessary voice and judgment.

Do not edit the original file yet.

**Done when:** every behavior and boundary that must survive is explicit.

## Step 3 — Refine the draft

Pass by pass:

1. **Structure** — One block, one job; headings reveal the workflow.
2. **Execution** — Actions, conditions, failures, and stops use plain English.
3. **Voice** — Keep poetic boundaries that guide judgment. Cut ornament.
4. **Terms** — Use one term for one meaning. Define uncommon terms that control behavior.
5. **Repetition** — Keep the sharpest source; remove repeated meaning.
6. **Mechanics** — Move stable repetition to `scripts/`. In prose, state when to run the script, what it returns, and what to do on failure.

Do not move judgment, branches, gates, or safety rules into scripts.

**Done when:** the draft is shorter, its workflow is visible, and every executable instruction is literal.

## Step 4 — Read it back

Check three levels:

1. **At a glance:** Is the workflow visible?
2. **On reading:** Is the prose human and easy to understand?
3. **In execution:** Are actions, safety rules, and stop conditions precise?

Choose one verdict:

| Verdict | Condition |
|---------|-----------|
| **Continue** | Promises hold; repetition or unclear structure remains |
| **Complete** | Promises hold; another pass would make the draft hollow |
| **Oblivion** | A promise broke; restore the last valid version |

## Step 5 — Produce the result

Return:

1. Refined text.
2. Scripts and invocation, when applicable.
3. Three to six changes.
4. Verdict with a one-line reason.
5. `No semantic drift detected` or a specific risk.

Write back by input type:

- Plain text → return the revision in chat.
- File/folder → write `<target>.optimized.md`; compare it with the original; ask before overwrite.
- Scripts → ask before creating or replacing under `scripts/`.
- Multiple files → one temporary path each; do not dump full bodies into chat.

Never overwrite an original without explicit confirmation.

**Done when:** the result follows the output contract and every original remains recoverable.

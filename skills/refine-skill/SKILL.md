---
name: refine-skill
description: Refine skill docs and prompts—prose lean, logic in scripts. Continue, complete, or oblivion when promises break. Use for paths or text to tighten or distill.
disable-model-invocation: true
metadata:
  argument-hint: "[folder-path|file-path|plain-text]"
allowed-tools: Read Write Glob rg Bash
---

Invoked as `/refine-skill [folder-path|file-path|plain-text]`.

# Refine Skill

*Between human and machine, the finest instructions need little—not from stinginess, but from understanding already shared.*

Some documents grow heavy—the same caution twice, rules dressed as paragraphs, a voice buried under scaffolding. Distill, don't silence: leave what still sings when the ornament falls away.

A skill can be a poem; a guardrail, one well-chosen line; a workflow, a letter to someone you trust. **Beautiful, powerful, lean**—because nothing redundant survived the cut.

**Save tokens by raising signal, not by deleting soul.** If cutting a sentence changes behavior, it stays. Read for intent—tone, boundaries, where the author paused because this *mattered*. Pairs and oblivion: [voice.md](references/voice.md).

| Keep | Let go |
|------|--------|
| Constraints, gates, confirmations, judgment in prose | Filler, duplicated rules, spec voice (unless wanted) |
| Terms that anchor meaning | Synonyms that drift nuance |
| Steps that change outcomes | Rephrased steps; repeatable sequences narrated every time |

## Input

1. **Plain text or file** — read if path; distill; return.
2. **Folder** — `bash <SKILL_DIR>/scripts/discover-targets.sh "<FOLDER>"` → candidates. One: distill it. Many: list; ask all or selected.

## Craft & journey

Edit for meaning, not character count. **Continuous work**—pass by pass until the next cut would break a promise.

1. **Listen** — What must happen? What must never happen?
2. **Find the spine** — The lines everything else supports.
3. **Cut the echo** — Same rule twice? Keep the sharper one.
4. **Leave a trace of the human** — Concise, deliberate; telegraphic only if they asked.
5. **Extract what repeats mechanically** — Stable logic → `scripts/`; prose keeps when, what returns, on failure. Not judgment, branching, or gates that must stay readable.
6. **Read it back** — Capabilities, constraints, clarity, voice—still intact? Leaner, not hollow. Then choose:

| Verdict | When |
|---------|------|
| **Continue** | Leaner; promises hold; echo remains |
| **Complete** | Promises hold; another pass would hollow |
| **Oblivion** | A promise broke—discard draft; return to the last version that sang |

Oblivion is not failure. It is refusing to ship a corpse dressed as poetry.

## Where you land

**Complete** — irreducible prose, repetition in scripts, trust at first read. **Oblivion** — the courage to undo a pretty mistake. The journey does not end at the shortest draft; it ends when what remains cannot shrink without breaking a promise.

## Output

1. **Refined text** — full rewrite (per target).
2. **Scripts** (if any) — path, what left prose, how to invoke.
3. **What changed** — 3–6 bullets.
4. **Journey** — `Continue` \| `Complete` \| `Oblivion` — one line why.
5. **Risk** — `No semantic drift detected` or honest caveat.

## Write-back

- Plain text → reply in chat.
- File/folder → `<target>.optimized.md` first; ask before overwriting originals.
- Scripts → ask before creating or replacing under `scripts/`.
- Multiple files → per-file temp paths; don't dump full bodies in chat when files were written.
- Never overwrite without explicit confirmation.

---

*Leave less on the page.*
*Leave everything that matters.*

# Harnesses

## Detect

Read the environment with one shell call (`echo "$BB_THREAD_ID|$CLAUDECODE"`), then check top to bottom; the first match is your harness.

| Harness | Signal |
|---|---|
| bb | `BB_THREAD_ID` is set |
| Claude Code | `CLAUDECODE=1` |
| Codex | you are Codex (your system prompt or tool list says so) |
| none | no match |

bb runs Claude Code or Codex inside it; the bb column names both where they differ.

## Glossary

Each term means what your harness's column says, everywhere in this skill and its references.

| Term | Meaning | bb | Claude Code | Codex | none |
|---|---|---|---|---|---|
| storage | per-conversation directory for the report, worktree, and probes | `$BB_THREAD_STORAGE` | `~/.agents/pr-review/<session>`, where `<session>` is `$CLAUDE_CODE_SESSION_ID`, else a random ID made at the first pass | `~/.agents/pr-review/<random ID made at the first pass>` | as Codex |
| invoke | the command that calls this skill | `/pr-review` under Claude Code · `$pr-review` under Codex | `/pr-review` | `$pr-review` (or pick it from `/skills`) | the skill's name |
| AI name | your name in the authorship line | Claude under Claude Code · Codex under Codex | Claude | Codex | AI |
| render | how visuals appear in chat (the report file is always text) | rich: see below | text forms in fenced blocks | text forms in fenced blocks | text forms in fenced blocks |

## Rich render (bb)

Same data as the text forms; draw, don't invent. If the `inline-vis` skill is available, follow it; otherwise:

- **Change map** → the text form; colour adds nothing worth its cost.
- **Blast radius map** → a fenced block with language `inline-vis` whose body is a small HTML fragment (inline CSS, no script needed, no file). Keep the indented tree and add colour and badges; never rearrange it into a radial graph. Draw it only when it has a ❌ leaf; otherwise it stays text.
  - No background, border, or padding on the outermost element; fluid width.
  - Colours only from theme variables: `--foreground`, `--muted-foreground`, `--border`, `--card`, `--brand` (the ★ node), `--diff-added` / `--diff-removed` (+/−), `--destructive` + `--destructive-foreground` (critical pins, high risk), `--warning` / `--warning-text` (warnings, ⚠️), `--success` (✅), `--destructive-text` (❌).
  - Fonts: `--font-sans`, `--font-mono` for paths.
- **Behavior diff** → keep the text form; a sequence or flow may use a `mermaid` block instead.
- **Trigger path** → always the text form.

## Setup

Keep this skill explicit-only (it must not load on its own):

| Harness | Setting |
|---|---|
| Claude Code | `disable-model-invocation: true` in the `SKILL.md` frontmatter |
| Codex | `policy.allow_implicit_invocation: false` in `agents/openai.yaml` |

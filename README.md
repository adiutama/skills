# AI Skills

Reusable AI agent skills following the [agentskills.io](https://agentskills.io/) open standard.

## Skills

| Skill | Version | Description |
|---|---|---|
| [dreaming](skills/dreaming/SKILL.md) | 2.0.0 | Consolidate thread history into durable bb memory: Haiku scanners read new messages nightly, an Opus judge writes memory through an undo journal, and a weekly deep sleep audits and organizes the store. bb only. |
| [evidence](skills/evidence/SKILL.md) | 2.0.0 | Capture screenshots and HTTP requests with responses as proof of work — redacted, stamped with commit, stored outside the repo — and pack them into a paste-ready PR Evidence block. Manual only. |
| [orchestration](skills/orchestration/SKILL.md) | 2.0.0 | Deprecated: merged into `workflow`. |
| [pr-review](skills/pr-review/SKILL.md) | 2.0.0 | Review a GitHub PR in an isolated worktree as one visual report (change map, behavior diff, blast radius, pinned findings); submit only on request. |
| [pr-testing](skills/pr-testing/SKILL.md) | 2.0.0 | Test open PRs by hand, one at a time, in one disposable test checkout with fake integrations and synthetic data; a per-PR checklist dashboard whose buttons reach the agent, fresh implementers for agreed fixes, merge only on your say-so. Manual only. |
| [project-kickoff](skills/project-kickoff/SKILL.md) | 2.0.0 | Start a new project from your setup: docs-as-blueprint AGENTS.md, append-only ADRs, specs with numbered rules traced to tests by a check script, TypeScript + Biome + Vitest. Loads on its own when you ask for a new project. |
| [specialist](skills/specialist/SKILL.md) | 2.0.1 | Deprecated: merged into `workflow`. |
| [throwaway-services](skills/throwaway-services/SKILL.md) | 2.0.0 | A disposable environment for manual verification: start new local services, emulators, and the app for a worktree, seed them for the case you want to check, get the link to open first, and keep it all running until you stop it. Manual only. |
| [workflow](skills/workflow/SKILL.md) | 2.3.0 | Classify work, pick the model and effort, decide whether to delegate, and do or coordinate it: one coordinator, workers with role cards, a Reviewer that convenes a council of other models (other families preferred) to verify, a runtime script for spawn, tell, read, and storage. |

## Setup

1. **Install.** Run `./install.sh` from the repo, and again after each release; running sessions keep the version they loaded. It copies each skill (deprecated ones only when named) into the skills directory of your runtime: bb `~/.bb/skills` when `~/.bb` exists, else Claude Code `~/.claude/skills` and Codex `~/.codex/skills`; `--runtime bb|claude|codex` picks. `./install.sh --uninstall <skill>` removes one, and `./install.sh --help` has the rest. Each installed folder is updated in place to an exact copy of the source, so files a release removed go too; the global instructions file is replaced in one step, so it is never left half written. Running two installs at once is unsupported, and an interrupted install is repaired by running it again. The installer guards against mistakes (bad names, broken markers, losing your own text, installing over the source, a re-run after an interruption), not against a filesystem deliberately arranged against it, such as permissions that block removing a link or folders planted mid-run.
2. **Global instructions come with it.** A skill whose rules must hold before it's loaded ships `init.md` (workflow does: load it on every task). `install.sh` writes that text inline into your global instructions (bb `~/.bb/AGENTS.md`, Claude Code `~/.claude/CLAUDE.md`, Codex `~/.codex/AGENTS.md`) as a block it owns, replaced on update and removed on uninstall. Your own text outside the markers is kept byte for byte: the only bytes the installer adds are the blank line before a block it appends (just a newline when your file didn't end with one), and uninstalling takes back exactly those, whatever the order. It tells its own blank lines from yours by where the blocks sit, so blocks you move or respace by hand may come back with a blank line more or less. Before changing anything it checks the whole file and every skill it was given, and stops with nothing changed on a name that isn't a folder name, a broken, nested or duplicate block of any skill (named or not), or an uninstall that would delete the source (a skills directory linked to this repo):

   ```markdown
   <!-- skill:workflow 2.3.0 -->
   ## Workflow

   At the start of every task, and after context compaction, load the `workflow` skill …
   <!-- /skill:workflow -->
   ```

   The text goes inline because agents follow what's in their prompt but skip a pointer to a file on small tasks.

   **Upgrading from a manual setup.** Before `install.sh`, this README asked you to paste a Workflow section into your global instructions yourself. The installer never touches text outside its markers, so delete that section by hand; left beside the block, its rule to always show `Classification:` still applies. It reads:

   ```markdown
   ## Workflow

   At the start of a top-level task, load the `workflow` skill if it is not already loaded in the current context.

   A worker whose prompt starts with `Role:` loads only the skills its brief names.

   Reuse loaded skills on follow-ups. Reload after context compaction, relevant instruction changes, or when required details are unavailable.

   Start a new substantive task or scope change with `Classification:` before any tool call other than loading skills. Briefed workers follow their brief instead. Routine replies and completion notifications do not require a fresh classification.
   ```

   Keep anything else you wrote yourself.

3. **Spawn guard hook (optional).** It blocks a command that runs `bb thread spawn` or `bb thread create` (help flags excepted) and points at `runtime.sh spawn` instead, unless the command goes through `runtime.sh` or carries `WORKFLOW_SPAWN=1`, which `runtime.sh spawn` sets on its own call. It fails open, so it's a reminder, not a security boundary.

   On a new machine, run `sh <skill folder>/scripts/runtime.sh install-guards`. It's safe to run twice, backs up each file it edits, and skips agents that aren't installed. It copies the guard scripts to `~/.local/share/workflow-guard/` (`WORKFLOW_GUARD_DIR` overrides), so moving or updating the skill never breaks a guard; run it again after an update to refresh them. It needs `jq`, and `python3` for Codex trust.

   [`spawn-check.sh`](skills/workflow/scripts/spawn-check.sh) holds the check (command in, exit 2 to block), and each agent has a thin adapter:

   | Agent | Adapter | Registered in |
   |---|---|---|
   | Claude Code | `scripts/spawn-guard.sh` (hook JSON on stdin, exit 2 blocks) | `~/.claude/settings.json`, a `PreToolUse` hook on `Bash` |
   | Codex | the same `spawn-guard.sh` | `~/.codex/hooks.json`, with `"async": false`; Codex runs a hook only once it's trusted in `config.toml`. For another Codex home, such as bb's, run with `CODEX_DIR=$CODEX_HOME` |
   | opencode | `scripts/opencode-spawn-guard.ts`, a plugin that throws before a `shell` call | `~/.config/opencode/plugins/workflow-spawn-guard.ts` |

## Structure

```
install.sh            # install, update, uninstall (./install.sh --help)
test-install.sh       # its checks
skills/
└── <skill-name>/
    ├── SKILL.md      # frontmatter includes metadata.version
    ├── init.md       # optional: always-on rules, written into global instructions
    └── ...           # optional supporting files
```

## Versioning

Each skill is versioned independently with semver (`metadata.version` in `SKILL.md`) and released as a git tag `<skill-name>@<version>`. See [AGENTS.md](AGENTS.md) for the bump rules.

The pre-rewrite skills are archived on the `legacy` branch.

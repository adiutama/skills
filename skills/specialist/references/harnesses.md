# Harnesses

## Detect

Read the environment with one shell call (`echo "$BB_THREAD_ID|$CLAUDECODE"`), then check top to bottom; the first match is your harness.

| Harness | Signal |
|---|---|
| bb | `BB_THREAD_ID` is set |
| Claude Code | `CLAUDECODE=1` |
| Codex | you are Codex (your system prompt or tool list says so) |
| none | no match |

bb runs Claude Code or Codex inside it; the bb column names both where they differ, and the tier table uses the hosted agent's column.

## Glossary

Each term means what your harness's column says, everywhere in this skill and its role cards.

| Term | Meaning | bb | Claude Code | Codex | none |
|---|---|---|---|---|---|
| storage | your directory for artifacts, details, handoff note | the brief's `Storage:` path, else `$BB_THREAD_STORAGE` | the brief's `Storage:` path, else `~/.agents/specialist/<task>/` | the brief's `Storage:` path, else `~/.agents/specialist/<task>/` | the brief's `Storage:` path, else `~/.agents/specialist/<task>/` |
| link | how a brief names your parent | `@thread:<id>` | agent ID; the main session is `main` | agent ID; the main session is `main` | `main` |
| context reading | a token count you can see | `bb thread context --self` | context-zone hook line, if installed | unknown | unknown |

## Tiers

A tier names a model; effort comes from your role card or brief, never from the tier.

| Tier | Claude | Codex | other |
|---|---|---|---|
| fast | Haiku 5.5 | `gpt-6-luna` | smallest, cheapest model |
| balanced | Sonnet 5.5 | `gpt-6.1-sol` | mid model |
| deep | Opus 5.5 | `gpt-6.1-sol` | strongest everyday model |
| consultant | Fable 5.1 | `gpt-6-astra` | top model, if any; else deep |

| Effort | Claude | Codex |
|---|---|---|
| levels | low · medium · high · xhigh · max | low · medium · high · xhigh · max · ultra |

A model missing from your plan → the parent picks the nearest available and says so in `Running on`; that counts as FIT.
Harness `none`, or a vendor not listed → use the `other` column. An effort level your harness lacks → the nearest one it has, noted the same way.

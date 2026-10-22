---
name: orchestration
description: "Deprecated: merged into the `workflow` skill. Do not use; load `workflow` instead."
metadata:
  version: "2.0.0"
  related: "workflow"
---

This skill is deprecated. Its content, together with `specialist`, is now the `workflow` skill: load `workflow` and follow it. A brief that says "Load the `orchestration` skill" means `workflow`.

`scripts/context-zone.sh` is kept only so existing Claude Code hook and status-line settings that point at it keep working; `workflow` no longer uses context zones.

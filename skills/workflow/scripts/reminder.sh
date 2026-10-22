#!/bin/sh
# Claude Code UserPromptSubmit hook: reminders for the workflow skill, by role.
cat <<'MSG'
Before acting on this message:
1. New substantive task or scope change? -> begin with Classification: before non-skill tools; briefed workers follow their brief instead.
2. Coordinator -> apply the coordinating rules; reuse suitable workers; one layer only. Worker -> follow the brief; no workers of your own beyond one helper.
3. Hands-on work -> use the applicable role card.
4. Coordinator: step done and ledger current -> compact. Worker: job bigger than briefed -> keep handoff.md current; never stop mid-work.
5. Reuse loaded skills. After compaction, relevant instruction changes, or missing details -> reload only the skills required for your role or brief.
6. Coordinator: routine completion without a milestone -> update state only if needed, then end without status polling. Handle failures, blockers and decisions.
MSG

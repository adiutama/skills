#!/bin/sh
# Claude Code UserPromptSubmit hook: keeps the orchestration and specialist rules next to the latest message.
cat <<'MSG'
Before acting on this message:
1. New task or scope change? -> show the classification block (radius · stakes · tier/effort).
2. Delegate if: cheaper tier can do it · 3+ independent slices · >5 files to read · needs review. "Faster myself" is not a reason.
3. Hands-on work -> state the role card in use.
4. Check context zone (🟢 <150K · 🟡 150-250K update ledger · 🔴 >250K specialist: finish, then report; Manager/Lead: ledger + compact at the next break).
5. Skill details fuzzy or context compacted -> reload orchestration/specialist.
MSG

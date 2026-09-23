---
name: draft-standup
description: Turn rough conversation notes and fresh repository activity into a daily standup. Use when the user wants an evidence-grounded update and a clarification pause before the draft.
disable-model-invocation: true
metadata:
  argument-hint: "[rough notes or previous standup]"
---

Invoked as `/draft-standup [rough notes or previous standup]`. Notes may also be scattered through the current conversation. The skill works in any chat client and with any repository host.

*Activity is a clue; the user's account is the claim.*

## Step 1 — Find the checkpoint

Read the visible current conversation and invocation notes. Use the most recent standup and its time as the start of the reporting period. Do not search other chat threads by default or claim to remember messages outside the visible context.

Resolve the repository from the current workspace or a user-provided path or link. If the repository is missing or ambiguous, ask for it and stop; every run must attempt a repository scan.

If the last standup or its time is unavailable, inspect recent activity as **provisional** and ask for the previous report or cutoff time at the pause. Rescan from the confirmed cutoff before drafting. Do not silently use “yesterday” as the cutoff.

## Step 2 — Scan the repository

Every run, inspect available local repository activity since the checkpoint: commits across relevant branches, changes in progress, and work associated with active pull requests. Use the repository's available hosting access to inspect pull requests updated in the period, including ones the user did not author. Read new comments, review threads, review decisions, and state changes; include relevant issue discussion and CI results. Check enough of each activity timeline to avoid treating a truncated first page as complete.

Use available read-only tools rather than assuming a particular CLI, API, host, or chat client. If repository hosting cannot be accessed, state that pull request comments and other remote activity were not checked. Ask for links or pasted context where that gap could affect the update. Do not post, comment, or modify the repository.

Keep source references for candidate facts. Distinguish discussion, work in progress, commits, reviews, merges, and releases. Do not attribute another person's activity to the user or turn an unresolved comment into a blocker without asking.

## Step 3 — Show findings and pause

Give a brief intake summary with the reporting period, sources checked, any coverage gaps, and the activity most likely to matter. Link or identify the supporting conversation notes, commits, pull requests, or issues where possible.

Ask focused questions about which activity represents the user's progress, what is complete, what comes next, whether anything is blocking them, and what happened outside the visible sources. Ask for the checkpoint if still uncertain. **End the turn here and wait for the user's reply, even when the evidence looks clear. Do not draft the standup in this turn.**

## Step 4 — Draft after clarification

Use the user's reply to resolve the candidates. If a material claim remains unclear, ask a short follow-up before drafting. Otherwise fill [assets/standup-template.md](assets/standup-template.md). Keep its date line, headings, order, and bullet style for a consistent paste-ready message; change the format only when the user explicitly asks. Fill `{{date}}` as `YYYY-MM-DD` in the user's local timezone when known. Add or remove bullets as needed, but keep all three sections. Label work in progress as such. Include only claims supported by the user's account or observed evidence, and make uncertainty visible rather than filling gaps. Write `None` in a section only when the user confirms there is nothing to report there.

Keep source links and scan limitations outside the paste-ready message unless the user wants them in it. Include the covered period and draft time outside the message so a later run can find its checkpoint. Revise the draft when the user corrects it; do not publish it without an explicit request.

---
name: optimize-skill
description: Optimize prompts or skill docs for token efficiency while preserving intent, constraints, and capability. Use when user provides a folder path, file path, or plain text and asks to tighten wording.
disable-model-invocation: true
metadata:
  argument-hint: "[folder-path|file-path|plain-text]"
allowed-tools: Read Write Glob rg
---

# Optimize Skill

Invoked as `/optimize-skill [folder-path|file-path|plain-text]`.

## Goal
Return a shorter, sharper version with equal or better control quality. Keep meaning, constraints, and behavior intact.

## Input modes
1. **Plain text**: optimize provided text directly.
2. **File path**: read file, optimize content.
3. **Folder path**: default target is `SKILL.md` in that folder. If missing, ask user to choose target file(s).

## Optimization rules
- Preserve intent, constraints, safety gates, and required confirmations.
- Remove redundancy, filler, and repeated restatements.
- Prefer precise verbs and explicit boundaries.
- Keep important nouns/terms stable unless change improves clarity.
- Do not introduce new workflow steps unless they fix ambiguity.
- Keep user voice: concise, deliberate, not caveman unless requested.

## Required checks
Before finalizing, verify:
1. Same capability coverage as source (or stronger).
2. No dropped hard constraints.
3. Fewer tokens/lines than source.
4. Instructions remain executable and unambiguous.

## Output format
1. **Optimized version** (full rewritten text).
2. **What changed** (3-6 bullets, high signal only).
3. **Risk check** (one line: `No semantic drift detected` or explicit caveat).

## Write-back behavior
- If input is plain text: return optimized text in chat.
- If input is a file/folder path: show optimized result first, then ask before writing.
- Never overwrite files without explicit confirmation.

# Closing thread reply

Post after execute (and push, if code changed). Always close the loop — including **skip**.

## Tone

Short, colleague, on-call voice. State outcome, not process narration.

## Templates

**Fixed (code):**

```text
Fixed — <one line what changed>. <commit or PR link if available>. Should be resolved; let me know if it persists.
```

**Fixed (runbook / ops):**

```text
Done — <what was run/changed>. Monitoring for the next ~N min; ping if still broken.
```

**Skipped:**

```text
Checked — <brief reason>. <next step: ticket link, escalate, expected behavior, etc.>
```

**Need-info (paused):**

```text
Need a bit more — <specific question>. Will pick up once we have <X>.
```

## How to post

Same thread target as ack — post via Slack MCP per [slack-mcp.md](slack-mcp.md). Manual paste only if user chose that fallback.

Mark timeline **reply** → done. Update `meta.md` status to `closed`.

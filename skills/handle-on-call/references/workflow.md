# On-call workflow

Default: full loop from pasted Slack alert through thread close.

## Round loop

```text
paste → session → slack-mcp → ack → triage → confirm → execute → push? → reply → closed
```

| Phase | Action |
|-------|--------|
| **session** | `start-session.sh` with pasted text (include Slack permalink when possible) |
| **slack-mcp** | Resolve Slack MCP; ask user to enable if missing — [slack-mcp.md](slack-mcp.md) |
| **ack** | `:eyes:` + "Looking into this" via MCP thread reply |
| **triage** | Read alert, investigate repo/logs/runbooks; write `report.md` per `output.md` |
| **confirm** | User picks fix \| skip \| need-info |
| **execute** | Minimal fix or document skip reason |
| **push** | Commit + push code fixes per `push.md` |
| **reply** | Closing thread message via MCP per `reply.md` |

## Execute rules

- **fix** — minimal scope; code and/or documented runbook steps in tracker
- **skip** — still write skip reason; still reply to thread
- **need-info** — reply with question; status stays open; `resume` later

## Slack access

| Condition | Action |
|-----------|--------|
| Slack MCP enabled | Post ack + reply via MCP |
| Slack MCP missing | Ask user to connect it; stop until ready or manual paste chosen |
| No permalink (`has_thread: false`) | Ask for link or manual paste |

## Resume

`resume` or `resume <incident-id>` → `resolve-session.sh` → show status + timeline → confirm before continuing.

Continue from first incomplete timeline step. Re-check Slack MCP if ack/reply still pending.

## Exit

**Closed** when timeline **reply** is done and `meta.md` status is `closed`.

Need-info pauses — not closed until resolved or explicitly abandoned (user says done).

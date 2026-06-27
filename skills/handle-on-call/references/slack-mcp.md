# Slack via MCP

Post ack and closing replies through the agent's **Slack MCP** — no bot token or custom scripts in this skill.

## Resolve before ack

1. Check enabled MCP servers for one named like `slack` (folder under the agent's `mcps/` descriptors).
2. **Not present** → ask the user once to enable/connect Slack MCP for this agent, then stop. Do not ack or reply until MCP is available or the user explicitly chooses **manual paste** (draft-only).
3. **Present** → list the server's tools; read each relevant descriptor (`post`, `send`, `reply`, `message`, etc.) before calling.
4. Pick the tool that posts a **thread reply** given `channel` + `thread_ts` from session JSON. Schemas differ by MCP — map fields from the descriptor, do not guess.

## Posting

Use session fields from `start-session.sh`:

| Field | Use |
|-------|-----|
| `channel` | Channel ID (e.g. `C0123456789`) |
| `thread_ts` | Parent message timestamp for thread reply |
| `slack_url` | Human reference only |

**Ack** and **reply** both go to the same thread (`thread_ts`).

If permalink was not pasted (`has_thread: false`) → MCP cannot target the thread. Ask user to paste the Slack link or post manually.

## After post

- Confirm success from MCP response.
- Mark tracker step **done**.
- On MCP error → report once; ask retry or manual paste.

## Manual paste fallback

Only when user declines MCP setup mid-run:

- Show exact message text.
- User posts in Slack.
- Mark step **done** after user confirms paste.

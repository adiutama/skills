// opencode plugin: blocks a raw `bb thread spawn|create` in the shell (bash) tool.
// Installed by `harness.sh install-guards`, which replaces __SPAWN_CHECK__ with the path of spawn-check.sh.
// Fails open: any error, or a missing check script, allows the command.
import { spawnSync } from "node:child_process"

const check = "__SPAWN_CHECK__"

export default {
  id: "workflow-spawn-guard",
  async setup(ctx: any) {
    await ctx.tool.hook("execute.before", (event: any) => {
      try {
        if (event?.tool !== "shell" && event?.tool !== "bash") return
        const command = event?.input?.command
        if (typeof command !== "string" || !command) return
        const r = spawnSync("sh", [check, command], { encoding: "utf8" })
        if (r.status === 2) throw new Error(r.stderr.trim() || "Blocked: raw bb thread spawn/create")
      } catch (e: any) {
        if (e?.message?.startsWith("Blocked")) throw e
      }
    })
  },
}

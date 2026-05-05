// PRIVACY POLICY: Only query durations recorded. No SQL text shipped.
import { registerDiscovery } from "../discovery"
import { sanitizeTech } from "../sanitizer"

let discovered = false

export function attachKnex(knex: any): void {
  if (!knex?.on) return

  knex.on("query", () => {
    if (!discovered) {
      const tech = sanitizeTech(knex.client?.config?.client)
      if (tech) {
        discovered = true
        const conn = knex.client?.config?.connection || {}
        registerDiscovery(
          { type: "database", tech, source: "hook_subscription" },
          { host: conn.host, url: conn.connectionString || conn.url, dbName: conn.database },
        )
      }
    }
  })
}

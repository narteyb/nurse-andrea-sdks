// PRIVACY POLICY: Only query durations recorded. No SQL text shipped.
import { registerDiscovery } from "../discovery"
import { sanitizeTech } from "../sanitizer"

let discovered = false

export function attachPrisma(prisma: any): void {
  if (!prisma?.$on) return

  prisma.$on("query", (e: any) => {
    if (!discovered) {
      const tech = sanitizeTech(e.target?.split(".")?.[0] ?? "postgresql")
      if (tech) {
        discovered = true
        // Prisma's connection URL is in DATABASE_URL — Prisma doesn't
        // expose connection metadata on the client by default, so
        // fall back to that env var.
        registerDiscovery(
          { type: "database", tech, source: "hook_subscription" },
          { url: process.env.DATABASE_URL || null },
        )
      }
    }
  })
}

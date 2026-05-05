// PRIVACY POLICY: NurseAndrea SDKs never transmit raw env var values,
// connection strings, credentials, hostnames, ports, or API tokens.
// Only derived metadata (type, tech, provider, source, variable_name)
// leaves the host. This module enforces the allowlist.

const ALLOWED_TECHS = new Set([
  "postgresql", "mysql", "sqlite", "mongodb", "redis",
  "memcached", "bullmq", "agenda", "rabbitmq",
])

function normalizeTech(raw: string): string {
  const s = raw.toLowerCase().trim()
  if (s === "postgres" || s === "pg" || s === "postgresql") return "postgresql"
  if (s === "ioredis" || s === "node-redis" || s === "redis") return "redis"
  if (s === "mysql2" || s === "mysql") return "mysql"
  if (s === "sqlite3" || s === "better-sqlite3") return "sqlite"
  if (s === "amqp" || s === "amqps") return "rabbitmq"
  if (s === "mongodb" || s === "mongodb+srv") return "mongodb"
  return s
}

export function sanitizeTech(raw: string | null | undefined): string | null {
  if (!raw) return null
  const normalized = normalizeTech(raw)
  return ALLOWED_TECHS.has(normalized) ? normalized : null
}

export function techFromUrl(url: string): string | null {
  try {
    const scheme = new URL(url).protocol.replace(":", "")
    return sanitizeTech(scheme)
  } catch {
    return null
  }
}

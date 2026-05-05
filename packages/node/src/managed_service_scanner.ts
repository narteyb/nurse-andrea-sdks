// PRIVACY POLICY: Scans for presence of env vars by NAME only.
// Values are passed through techFromUrl() which strips credentials/hosts.
// Raw values are never stored or shipped.

import { techFromUrl } from "./sanitizer"

interface Discovery {
  type: string
  tech: string
  source: string
  variable_name: string
}

const DB_ENV_VARS    = ["DATABASE_URL", "DB_URL", "POSTGRES_URL", "MYSQL_URL", "MONGODB_URI"]
const CACHE_ENV_VARS = ["REDIS_URL", "REDIS_TLS_URL", "UPSTASH_REDIS_REST_URL"]
const QUEUE_ENV_VARS = ["RABBITMQ_URL", "AMQP_URL", "CLOUDAMQP_URL"]

export function scanManagedServices(): Discovery[] {
  const discoveries: Discovery[] = []
  const seen = new Set<string>()

  for (const varName of DB_ENV_VARS) {
    const val = process.env[varName]
    if (!val) continue
    const tech = techFromUrl(val)
    if (!tech) continue
    const key = `database:${tech}`
    if (seen.has(key)) continue
    seen.add(key)
    discoveries.push({ type: "database", tech, source: "env_detection", variable_name: varName })
  }

  for (const varName of CACHE_ENV_VARS) {
    if (!(varName in process.env) || !process.env[varName]) continue
    const key = "cache:redis"
    if (seen.has(key)) continue
    seen.add(key)
    discoveries.push({ type: "cache", tech: "redis", source: "env_detection", variable_name: varName })
  }

  for (const varName of QUEUE_ENV_VARS) {
    const val = process.env[varName]
    if (!val) continue
    const tech = techFromUrl(val)
    if (!tech) continue
    const key = `queue:${tech}`
    if (seen.has(key)) continue
    seen.add(key)
    discoveries.push({ type: "queue", tech, source: "env_detection", variable_name: varName })
  }

  return discoveries
}

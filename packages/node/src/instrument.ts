// PRIVACY POLICY: This file wires hook subscriptions and env scanning.
// No raw values leave the process. See sanitizer.ts for enforcement.

import { registerDiscovery } from "./discovery"
import { scanManagedServices } from "./managed_service_scanner"
import { detectPlatform } from "./platform_detector"

interface InstrumentOptions {
  prisma?: any
  knex?: any
  sequelize?: any
  redisClient?: any
  worker?: any
}

export function instrument(opts: InstrumentOptions = {}): void {
  // Platform detection
  const platform = detectPlatform()
  if (platform !== "unknown") {
    process.stdout.write(`[NurseAndrea] Platform: ${platform}\n`)
  }

  // Env-based managed service discovery
  const envDiscoveries = scanManagedServices()
  envDiscoveries.forEach(d => registerDiscovery(d))
  if (envDiscoveries.length > 0) {
    process.stdout.write(`[NurseAndrea] Discovered ${envDiscoveries.length} managed services\n`)
  }

  // Hook-based discovery for provided client instances
  if (opts.prisma) {
    try {
      const { attachPrisma } = require("./hooks/prisma")
      attachPrisma(opts.prisma)
    } catch (e) {
      process.stderr.write(`[NurseAndrea] Prisma hook failed: ${(e as Error).message}\n`)
    }
  }

  if (opts.knex) {
    try {
      const { attachKnex } = require("./hooks/knex")
      attachKnex(opts.knex)
    } catch (e) {
      process.stderr.write(`[NurseAndrea] Knex hook failed: ${(e as Error).message}\n`)
    }
  }

  if (opts.redisClient) {
    try {
      const { attachRedis } = require("./hooks/redis_hook")
      attachRedis(opts.redisClient)
    } catch (e) {
      process.stderr.write(`[NurseAndrea] Redis hook failed: ${(e as Error).message}\n`)
    }
  }

  if (opts.worker) {
    try {
      const { attachBullMQ } = require("./hooks/bullmq")
      attachBullMQ(opts.worker)
    } catch (e) {
      process.stderr.write(`[NurseAndrea] BullMQ hook failed: ${(e as Error).message}\n`)
    }
  }
}

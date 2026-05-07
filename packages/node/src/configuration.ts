import { ConfigurationError, MigrationError } from "./errors"
import { isValidSlug, SLUG_RULES_HUMAN } from "./slug-validator"
import {
  SUPPORTED_ENVIRONMENTS,
  detectEnvironment,
  type Environment,
} from "./environment-detector"
import { SDK_VERSION, SDK_LANGUAGE } from "./version"

export interface NurseAndreaConfig {
  orgToken: string
  workspaceSlug: string
  environment: Environment
  host: string
  serviceName: string
  enabled: boolean
  logLevel: "debug" | "info" | "warn" | "error"
  flushIntervalMs: number
  batchSize: number
}

const DEFAULT_HOST = "https://nurseandrea.io"
const LEGACY_FIELDS = ["apiKey", "token", "ingestToken"] as const

let _config: NurseAndreaConfig | null = null
let _bannerPrinted = false

function migrationMessage(field: string): string {
  return (
    `${field} is no longer supported in NurseAndrea SDK 1.0. ` +
    "Migrate to orgToken + workspaceSlug + environment. " +
    "See https://docs.nurseandrea.io/sdk/migration"
  )
}

export function configure(options: Partial<NurseAndreaConfig> & Record<string, unknown>): void {
  for (const legacy of LEGACY_FIELDS) {
    if (options[legacy] !== undefined) {
      throw new MigrationError(migrationMessage(legacy))
    }
  }

  const orgToken = options.orgToken ?? process.env.NURSE_ANDREA_ORG_TOKEN ?? ""
  const workspaceSlug = options.workspaceSlug ?? ""
  const environment = (options.environment ?? detectEnvironment()) as Environment
  const host = options.host ?? process.env.NURSE_ANDREA_HOST ?? DEFAULT_HOST

  if (!orgToken) {
    throw new ConfigurationError("orgToken is required")
  }
  if (!workspaceSlug) {
    throw new ConfigurationError("workspaceSlug is required")
  }
  if (!environment) {
    throw new ConfigurationError("environment is required")
  }
  if (!(SUPPORTED_ENVIRONMENTS as readonly string[]).includes(environment)) {
    throw new ConfigurationError(
      `environment must be one of ${SUPPORTED_ENVIRONMENTS.join(", ")} (got ${JSON.stringify(environment)})`
    )
  }
  if (!isValidSlug(workspaceSlug)) {
    throw new ConfigurationError(
      `workspaceSlug ${JSON.stringify(workspaceSlug)} is invalid. ${SLUG_RULES_HUMAN}`
    )
  }

  _config = {
    orgToken,
    workspaceSlug,
    environment,
    host,
    serviceName:     options.serviceName ?? process.env.NURSE_ANDREA_SERVICE_NAME ?? detectServiceName(),
    enabled:         options.enabled ?? process.env.NODE_ENV !== "test",
    logLevel:        options.logLevel ?? "warn",
    flushIntervalMs: options.flushIntervalMs ?? 5000,
    batchSize:       options.batchSize ?? 100,
  }

  // Defer require to break circular import (client.ts imports from this file).
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { client } = require("./client") as typeof import("./client")
  client.start()

  const { startTraceExporter } = require("./tracing/exporter") as typeof import("./tracing/exporter")
  startTraceExporter()

  if (!_bannerPrinted) {
    _bannerPrinted = true
    process.stdout.write(
      `[NurseAndrea] Shipping to ${_config.host} as ${_config.serviceName} ` +
      `(${SDK_LANGUAGE} sdk v${SDK_VERSION}, workspace=${_config.workspaceSlug}/${_config.environment})\n`
    )

    const stop = () => client.stop()
    process.on("beforeExit", stop)
    process.on("SIGTERM", stop)
  }
}

export function getConfig(): NurseAndreaConfig {
  if (!_config) {
    throw new ConfigurationError(
      "NurseAndrea is not configured. Call configure({ orgToken, workspaceSlug, environment }) at startup."
    )
  }
  return _config
}

export function isEnabled(): boolean {
  return !!_config && _config.enabled && !!_config.orgToken
}

export function ingestUrl(): string {
  return `${getConfig().host.replace(/\/$/, "")}/api/v1/ingest`
}

export function metricsUrl(): string {
  return `${getConfig().host.replace(/\/$/, "")}/api/v1/metrics`
}

export function _resetForTests(): void {
  _config = null
  _bannerPrinted = false
}

function detectServiceName(): string {
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const pkg = require(process.cwd() + "/package.json")
    return pkg.name ?? "node-app"
  } catch {
    return "node-app"
  }
}

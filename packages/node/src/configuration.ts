export interface NurseAndreaConfig {
  token: string
  host: string
  serviceName: string
  enabled: boolean
  logLevel: "debug" | "info" | "warn" | "error"
  flushIntervalMs: number
  batchSize: number
}

const DEFAULT_HOST = "https://nurseandrea.io"
const SDK_VERSION  = "0.2.1"

let _config: NurseAndreaConfig | null = null
let _bannerPrinted = false

export function configure(options: Partial<NurseAndreaConfig>): void {
  _config = {
    token:           options.token           ?? process.env.NURSE_ANDREA_INGEST_TOKEN ?? process.env.NURSE_ANDREA_TOKEN ?? "",
    host:            options.host            ?? process.env.NURSE_ANDREA_HOST  ?? DEFAULT_HOST,
    serviceName:     options.serviceName     ?? process.env.NURSE_ANDREA_SERVICE_NAME ?? detectServiceName(),
    enabled:         options.enabled         ?? process.env.NODE_ENV !== "test",
    logLevel:        options.logLevel        ?? "warn",
    flushIntervalMs: options.flushIntervalMs ?? 5000,
    batchSize:       options.batchSize       ?? 100,
  }

  if (!_config.token) {
    process.stderr.write("[NurseAndrea] No token configured. Set NURSE_ANDREA_INGEST_TOKEN or pass token to configure(). Monitoring disabled.\n")
    _config.enabled = false
    return
  }

  // Defer require to break the circular import (client.ts imports from this file).
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { client } = require("./client") as typeof import("./client")
  client.start()

  const { startTraceExporter } = require("./tracing/exporter") as typeof import("./tracing/exporter")
  startTraceExporter()

  if (!_bannerPrinted) {
    _bannerPrinted = true
    process.stdout.write(
      `[NurseAndrea] Shipping to ${_config.host} as ${_config.serviceName} (node sdk v${SDK_VERSION})\n`
    )

    const stop = () => client.stop()
    process.on("beforeExit", stop)
    process.on("SIGTERM", stop)
  }
}

export function getConfig(): NurseAndreaConfig {
  if (!_config) {
    configure({})
  }
  return _config!
}

export function isEnabled(): boolean {
  return getConfig().enabled && !!getConfig().token
}

export function ingestUrl(): string {
  return `${getConfig().host.replace(/\/$/, "")}/api/v1/ingest`
}

export function metricsUrl(): string {
  return `${getConfig().host.replace(/\/$/, "")}/api/v1/metrics`
}

function detectServiceName(): string {
  try {
    const pkg = require(process.cwd() + "/package.json")
    return pkg.name ?? "node-app"
  } catch {
    return "node-app"
  }
}

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

let _config: NurseAndreaConfig | null = null

export function configure(options: Partial<NurseAndreaConfig>): void {
  _config = {
    token:           options.token           ?? process.env.NURSE_ANDREA_TOKEN ?? "",
    host:            options.host            ?? process.env.NURSE_ANDREA_HOST  ?? DEFAULT_HOST,
    serviceName:     options.serviceName     ?? process.env.NURSE_ANDREA_SERVICE_NAME ?? detectServiceName(),
    enabled:         options.enabled         ?? process.env.NODE_ENV !== "test",
    logLevel:        options.logLevel        ?? "warn",
    flushIntervalMs: options.flushIntervalMs ?? 5000,
    batchSize:       options.batchSize       ?? 100,
  }

  if (!_config.token) {
    console.warn("[NurseAndrea] No token configured. Set NURSE_ANDREA_TOKEN or pass token to configure(). Monitoring disabled.")
    _config.enabled = false
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

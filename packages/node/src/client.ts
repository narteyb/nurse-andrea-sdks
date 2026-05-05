import { getConfig, ingestUrl, metricsUrl, isEnabled } from "./configuration"
import { flushDiscoveries } from "./discovery"
import { detectPlatform } from "./platform_detector"

export interface LogEntry {
  level: "debug" | "info" | "warn" | "error"
  message: string
  timestamp: string
  service: string
  metadata?: Record<string, unknown>
}

export interface MetricEntry {
  name: string
  value: number
  unit: string
  timestamp: string
  tags: Record<string, string>
}

class NurseAndreaClient {
  private logQueue: LogEntry[] = []
  private metricQueue: MetricEntry[] = []
  private timer: ReturnType<typeof setInterval> | null = null

  start(): void {
    if (this.timer) return // idempotent — already running
    if (!isEnabled()) return
    const config = getConfig()
    this.timer = setInterval(() => {
      this.collectProcessMemory()
      this.flush()
    }, config.flushIntervalMs)
    if (this.timer.unref) this.timer.unref()
  }

  stop(): void {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
    this.flush()
  }

  private collectProcessMemory(): void {
    try {
      const rss = process.memoryUsage().rss
      this.enqueueMetric({ name: "process.memory.rss", value: rss, unit: "bytes" })
    } catch { /* memory reporting must never crash the host app */ }
  }

  enqueueLog(entry: Omit<LogEntry, "service" | "timestamp">): void {
    if (!isEnabled()) return
    this.logQueue.push({
      ...entry,
      service: getConfig().serviceName,
      timestamp: new Date().toISOString(),
    })
    if (this.logQueue.length >= getConfig().batchSize) this.flush()
  }

  enqueueMetric(
    entry: Omit<MetricEntry, "timestamp" | "tags"> & {
      tags?: Record<string, string>
    }
  ): void {
    if (!isEnabled()) return
    this.metricQueue.push({
      ...entry,
      tags: { service: getConfig().serviceName, ...(entry.tags ?? {}) },
      timestamp: new Date().toISOString(),
    })
    if (this.metricQueue.length >= getConfig().batchSize) this.flush()
  }

  private async flush(): Promise<void> {
    if (!isEnabled()) return

    const logs = this.logQueue.splice(0)
    const metrics = this.metricQueue.splice(0)
    const config = getConfig()

    const headers = {
      "Content-Type": "application/json",
      Authorization: `Bearer ${config.token}`,
    }

    try {
      if (logs.length > 0) {
        const res = await fetch(ingestUrl(), {
          method: "POST",
          headers,
          body: JSON.stringify({ logs }),
        })
        if (!res.ok) {
          process.stderr.write(`[NurseAndrea] POST ${ingestUrl()} → ${res.status}\n`)
        }
      }

      if (metrics.length > 0) {
        const payload: Record<string, unknown> = {
          metrics,
          platform: detectPlatform(),
        }
        const componentDiscoveries = flushDiscoveries()
        if (componentDiscoveries.length > 0) {
          payload.component_discoveries = componentDiscoveries
        }
        const res = await fetch(metricsUrl(), {
          method: "POST",
          headers,
          body: JSON.stringify(payload),
        })
        if (!res.ok) {
          process.stderr.write(`[NurseAndrea] POST ${metricsUrl()} → ${res.status}\n`)
        }
      }
    } catch (err) {
      process.stderr.write(`[NurseAndrea] Flush failed: ${(err as Error).message}\n`)
      this.logQueue.unshift(...logs)
      this.metricQueue.unshift(...metrics)
    }
  }
}

export const client = new NurseAndreaClient()

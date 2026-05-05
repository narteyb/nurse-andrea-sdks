// PRIVACY POLICY: Same guarantees as scanManagedServices — only
// derived metadata leaves the process. See sanitizer.ts.
//
// Periodically re-runs the env-based scan so dependencies added
// after boot (env reloads, attached services) eventually surface
// as discoveries on the workspace dashboard.
//
// Contract:
//   * Non-blocking — setInterval, never on the request path.
//   * Bounded — single timer; calling start twice is a no-op.
//   * Fail-safe — any error inside a tick is swallowed.
//   * unref'd — does NOT keep the process alive.
//   * Stoppable — stopContinuousScanner clears the timer.

import { registerDiscovery, ConnectionMetadata } from "./discovery"
import { scanManagedServices } from "./managed_service_scanner"

const DEFAULT_INTERVAL_MS = 5 * 60 * 1000

let timer: ReturnType<typeof setInterval> | null = null

export interface ContinuousScannerOptions {
  intervalMs?: number
  disable?:    boolean
}

export function startContinuousScanner(opts: ContinuousScannerOptions = {}): void {
  if (timer) return  // already running, no-op
  if (opts.disable) return

  const intervalMs = opts.intervalMs ?? DEFAULT_INTERVAL_MS
  timer = setInterval(rescanSafely, intervalMs)
  // Critical: unref so a long-lived scanner doesn't prevent process exit
  if (timer && typeof (timer as any).unref === "function") {
    (timer as any).unref()
  }
}

export function stopContinuousScanner(): void {
  if (timer) {
    clearInterval(timer)
    timer = null
  }
}

export function isContinuousScannerRunning(): boolean {
  return timer !== null
}

// Public so tests can drive a tick deterministically.
export function rescanSafely(): void {
  try {
    const discoveries = scanManagedServices()
    if (discoveries.length === 0) return

    discoveries.forEach(d => {
      const metadata: ConnectionMetadata = {
        url:  (d as any).url ?? null,
        host: (d as any).host ?? null,
      }
      registerDiscovery(d, metadata)
    })
  } catch (err) {
    process.stderr.write(`[NurseAndrea] continuous scanner error: ${(err as Error).message}\n`)
  }
}

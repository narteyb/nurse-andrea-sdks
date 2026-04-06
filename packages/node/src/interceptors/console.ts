import { client } from "../client"
import { isEnabled } from "../configuration"

const LEVEL_MAP: Record<string, "debug" | "info" | "warn" | "error"> = {
  log: "info",
  info: "info",
  warn: "warn",
  error: "error",
  debug: "debug",
}

export function interceptConsole(): () => void {
  if (!isEnabled()) return () => {}

  const originals: Record<string, (...args: unknown[]) => void> = {}

  for (const method of ["log", "info", "warn", "error", "debug"] as const) {
    originals[method] = console[method].bind(console)
    console[method] = (...args: unknown[]) => {
      originals[method](...args)

      const message = args
        .map((a) => (typeof a === "string" ? a : JSON.stringify(a)))
        .join(" ")

      client.enqueueLog({
        level: LEVEL_MAP[method] ?? "info",
        message,
      })
    }
  }

  return () => {
    for (const method of Object.keys(originals)) {
      ;(console as unknown as Record<string, unknown>)[method] = originals[method]
    }
  }
}

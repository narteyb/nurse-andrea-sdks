import { client } from "../client"
import { isEnabled } from "../configuration"

const PINO_LEVEL_MAP: Record<number, "debug" | "info" | "warn" | "error"> = {
  10: "debug",
  20: "debug",
  30: "info",
  40: "warn",
  50: "error",
  60: "error",
}

export function nurseAndreaPinoStream() {
  const { Writable } = require("stream")

  return new Writable({
    write(chunk: Buffer, _encoding: string, callback: () => void) {
      if (isEnabled()) {
        try {
          const entry = JSON.parse(chunk.toString())
          client.enqueueLog({
            level: PINO_LEVEL_MAP[entry.level] ?? "info",
            message: entry.msg ?? chunk.toString(),
            metadata: entry,
          })
        } catch {
          client.enqueueLog({ level: "info", message: chunk.toString() })
        }
      }
      callback()
    },
  })
}

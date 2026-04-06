import { client } from "../client"
import { isEnabled } from "../configuration"

export function nurseAndreaWinstonTransport() {
  const { Writable } = require("stream")

  const writable = new Writable({
    write(chunk: Buffer, _encoding: string, callback: () => void) {
      if (isEnabled()) {
        try {
          const entry = JSON.parse(chunk.toString())
          client.enqueueLog({
            level: entry.level ?? "info",
            message: entry.message ?? chunk.toString(),
            metadata: entry,
          })
        } catch {
          client.enqueueLog({ level: "info", message: chunk.toString() })
        }
      }
      callback()
    },
  })

  // Return a winston-compatible transport
  const Transport = require("winston-transport")
  class NurseAndreaTransport extends Transport {
    log(info: Record<string, unknown>, callback: () => void) {
      if (isEnabled()) {
        client.enqueueLog({
          level: (info.level as "info") ?? "info",
          message: (info.message as string) ?? JSON.stringify(info),
          metadata: info,
        })
      }
      callback()
    }
  }

  return new NurseAndreaTransport()
}

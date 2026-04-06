export { configure, getConfig, isEnabled } from "./configuration"
export { client } from "./client"
export { nurseAndreaExpress } from "./middleware/express"
export { nurseAndreaFastify } from "./middleware/fastify"
export { NurseAndreaMiddleware } from "./middleware/nestjs"
export { interceptConsole } from "./interceptors/console"
export { nurseAndreaWinstonTransport } from "./interceptors/winston"
export { nurseAndreaPinoStream } from "./interceptors/pino"

// Auto-start the client flush loop when the SDK is imported
import { client } from "./client"
client.start()

// Flush on process exit
process.on("beforeExit", () => client.stop())
process.on("SIGTERM", () => client.stop())

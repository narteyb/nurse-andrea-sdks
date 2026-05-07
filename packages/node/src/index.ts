export { configure, getConfig, isEnabled } from "./configuration"
export { client } from "./client"
export { ConfigurationError, MigrationError, NurseAndreaError } from "./errors"
export { isValidSlug, SLUG_RULES_HUMAN } from "./slug-validator"
export {
  detectEnvironment,
  SUPPORTED_ENVIRONMENTS,
  type Environment,
} from "./environment-detector"
export { SDK_VERSION, SDK_LANGUAGE } from "./version"
export { nurseAndreaExpress } from "./middleware/express"
export { nurseAndreaFastify } from "./middleware/fastify"
export { NurseAndreaMiddleware } from "./middleware/nestjs"
export { interceptConsole } from "./interceptors/console"
export { nurseAndreaWinstonTransport } from "./interceptors/winston"
export { nurseAndreaPinoStream } from "./interceptors/pino"
export { instrument } from "./instrument"
export { sanitizeTech, techFromUrl } from "./sanitizer"
export { detectPlatform } from "./platform_detector"
export { registerDiscovery, discoveries, flushDiscoveries } from "./discovery"
export { deploy } from "./deploy"

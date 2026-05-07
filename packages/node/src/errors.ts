export class NurseAndreaError extends Error {
  constructor(message: string) {
    super(message)
    this.name = this.constructor.name
  }
}

export class ConfigurationError extends NurseAndreaError {}

export class MigrationError extends ConfigurationError {}

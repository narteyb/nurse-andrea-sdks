class NurseAndreaError(Exception):
    pass


class ConfigurationError(NurseAndreaError, ValueError):
    pass


class MigrationError(ConfigurationError):
    pass

module NurseAndrea
  class Error < StandardError; end

  class ConfigurationError < Error; end

  class MigrationError < ConfigurationError; end
end

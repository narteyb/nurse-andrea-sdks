module NurseAndrea
  # Sprint A D6 (GAP-10) — per-failure-mode boot messages. Lives
  # outside the Railtie so the message map can be tested without
  # booting Rails. The Railtie calls .message_for(config) from its
  # warn-and-disable branches; the unit specs target this module
  # directly.
  #
  # Pre-Sprint-A the Railtie emitted a single generic warn
  # ("Configuration incomplete at logger wrap time — monitoring
  # disabled. Ensure NurseAndrea.configure is called in
  # config/initializers/nurse_andrea.rb with a valid token.")
  # regardless of which field was missing. Operators had to grep
  # the codebase to know what to fix. The per-cause messages below
  # name the exact failure mode and the env var or setter to update.
  module BootDiagnostics
    GUIDANCE = {
      missing_org_token:
        "[NurseAndrea] org_token is not set — monitoring disabled. " \
        "Set NURSE_ANDREA_ORG_TOKEN in your environment.",
      missing_workspace_slug:
        "[NurseAndrea] workspace_slug is not set — monitoring disabled. " \
        "Set c.workspace_slug in config/initializers/nurse_andrea.rb.",
      missing_environment:
        "[NurseAndrea] environment is not set — monitoring disabled. " \
        "Set c.environment in config/initializers/nurse_andrea.rb " \
        "(production / staging / development).",
      invalid_environment:
        "[NurseAndrea] environment is invalid — monitoring disabled. " \
        "Must be one of: production, staging, development.",
      invalid_workspace_slug:
        "[NurseAndrea] workspace_slug is invalid — monitoring disabled. " \
        "Slug must be lowercase letters, numbers, and hyphens; " \
        "start with a letter; 1-64 characters.",
      missing_host:
        "[NurseAndrea] host is not set — monitoring disabled. " \
        "Set NURSE_ANDREA_HOST or leave the default (https://nurseandrea.io)."
    }.freeze

    DISABLED =
      "[NurseAndrea] monitoring is disabled (c.enabled = false).".freeze

    def self.message_for(config)
      return DISABLED unless config.enabled?
      GUIDANCE[config.validation_diagnostic]
    end
  end
end

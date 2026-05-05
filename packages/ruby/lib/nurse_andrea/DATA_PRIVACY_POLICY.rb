# ============================================================
# NURSEANDREA DATA PRIVACY POLICY — INVIOLABLE
# ============================================================
#
# This SDK reads environment variables (DATABASE_URL, REDIS_URL,
# etc.) and framework instrumentation hooks to detect secondary
# components. It NEVER transmits:
#
#   - Raw environment variable values
#   - Connection strings or URLs
#   - Credentials (usernames, passwords, API tokens)
#   - Hostnames, IP addresses, or ports
#   - Database names or paths
#
# Only derived metadata is transmitted to NurseAndrea servers:
#
#   - type          (e.g. "database", "cache", "queue")
#   - tech          (e.g. "postgresql", "redis")
#   - provider      (e.g. "railway", "neon", "upstash")
#   - source        (e.g. "env_detection", "hook_subscription")
#   - variable_name (e.g. "DATABASE_URL" — the name, not the value)
#
# The Sanitizer module enforces this policy. All discovery records
# pass through the Sanitizer before transmission. Any field not on
# the allowlist is stripped.
#
# This policy is a commitment to our customers. Violating it is
# a shipping-blocking defect.
# ============================================================

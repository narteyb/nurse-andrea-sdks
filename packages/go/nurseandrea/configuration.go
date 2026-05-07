package nurseandrea

import (
	"fmt"
	"os"
	"strings"
	"sync"
)

const defaultHost = "https://nurseandrea.io"

// Config holds all SDK configuration.
//
// In 1.0 the auth contract changed from a single workspace token to:
//
//	OrgToken      — your org's ingest token
//	WorkspaceSlug — which workspace within the org receives ingest
//	Environment   — production | staging | development
//
// Legacy fields (APIKey, Token, IngestToken) remain on this struct only so
// Validate() can detect old usage and return a MigrationError pointing at
// the new contract. Setting any of them is a hard configuration error.
type Config struct {
	OrgToken      string
	WorkspaceSlug string
	Environment   string
	Host          string
	ServiceName   string
	Enabled       *bool
	FlushIntervalMs int
	BatchSize       int

	// Migration trip-wires. Setting any of these returns a MigrationError
	// from Validate / Configure. Do not use.
	APIKey      string `json:"-"`
	Token       string `json:"-"`
	IngestToken string `json:"-"`
}

var (
	globalConfig Config
	configured   bool
	configMu     sync.RWMutex
)

// Configure sets the global SDK configuration. Returns an error if validation
// fails (legacy fields, missing required, unsupported environment, invalid slug).
// Returning an error rather than panicking lets callers integrate this into
// their existing startup error-handling flow.
func Configure(cfg Config) error {
	if err := validateLegacyFields(cfg); err != nil {
		return err
	}

	configMu.Lock()
	defer configMu.Unlock()

	if cfg.OrgToken == "" {
		cfg.OrgToken = os.Getenv("NURSE_ANDREA_ORG_TOKEN")
	}
	if cfg.Host == "" {
		cfg.Host = os.Getenv("NURSE_ANDREA_HOST")
	}
	if cfg.Host == "" {
		cfg.Host = defaultHost
	}
	cfg.Host = strings.TrimRight(cfg.Host, "/")

	if cfg.Environment == "" {
		cfg.Environment = DetectEnvironment()
	}

	if cfg.ServiceName == "" {
		cfg.ServiceName = firstNonEmpty(
			os.Getenv("NURSE_ANDREA_SERVICE_NAME"),
			os.Getenv("RAILWAY_SERVICE_NAME"),
			"go-app",
		)
	}
	if cfg.FlushIntervalMs == 0 {
		cfg.FlushIntervalMs = 5000
	}
	if cfg.BatchSize == 0 {
		cfg.BatchSize = 100
	}
	if cfg.Enabled == nil {
		enabled := true
		cfg.Enabled = &enabled
	}

	if err := validateRequired(cfg); err != nil {
		return err
	}

	globalConfig = cfg
	configured = true

	bannerHost := cfg.Host
	bannerService := cfg.ServiceName
	bannerSlug := cfg.WorkspaceSlug
	bannerEnv := cfg.Environment

	// Trigger lazy client init + tracing exporter, print startup banner.
	go func() {
		GetClient()
		tracingStart()
		if !bannerPrinted {
			bannerPrinted = true
			fmt.Fprintf(os.Stdout,
				"[NurseAndrea] Shipping to %s as %s (%s sdk v%s, workspace=%s/%s)\n",
				bannerHost, bannerService, SDKLanguage, Version, bannerSlug, bannerEnv)
		}
	}()

	return nil
}

func validateLegacyFields(cfg Config) error {
	if cfg.APIKey != "" {
		return newMigrationError("APIKey")
	}
	if cfg.Token != "" {
		return newMigrationError("Token")
	}
	if cfg.IngestToken != "" {
		return newMigrationError("IngestToken")
	}
	return nil
}

func validateRequired(cfg Config) error {
	if cfg.OrgToken == "" {
		return &ConfigurationError{Message: "OrgToken is required"}
	}
	if cfg.WorkspaceSlug == "" {
		return &ConfigurationError{Message: "WorkspaceSlug is required"}
	}
	if cfg.Environment == "" {
		return &ConfigurationError{Message: "Environment is required"}
	}
	if !isSupportedEnvironment(cfg.Environment) {
		return &ConfigurationError{
			Message: fmt.Sprintf("Environment must be one of %v (got %q)",
				SupportedEnvironments, cfg.Environment),
		}
	}
	if !IsValidSlug(cfg.WorkspaceSlug) {
		return &ConfigurationError{
			Message: fmt.Sprintf("WorkspaceSlug %q is invalid. %s",
				cfg.WorkspaceSlug, SlugRulesHuman),
		}
	}
	return nil
}

var bannerPrinted bool

// tracingStartFunc is set by the tracing package to avoid circular imports.
var tracingStartFunc func()

// SetTracingStartFunc is called by the tracing package's init() to register itself.
func SetTracingStartFunc(fn func()) {
	tracingStartFunc = fn
}

func tracingStart() {
	if tracingStartFunc != nil {
		tracingStartFunc()
	}
}

// GetConfig returns the current configuration. Panics if Configure has not
// been called — there are no sensible defaults for OrgToken/WorkspaceSlug.
func GetConfig() Config {
	configMu.RLock()
	defer configMu.RUnlock()
	if !configured {
		panic("nurseandrea: Configure() has not been called. Set OrgToken + WorkspaceSlug + Environment at startup.")
	}
	return globalConfig
}

// IsEnabled returns true if the SDK is active.
func IsEnabled() bool {
	cfg := GetConfig()
	return cfg.Enabled != nil && *cfg.Enabled && cfg.OrgToken != ""
}

// IngestURL returns the full ingest endpoint URL.
func IngestURL() string {
	return GetConfig().Host + "/api/v1/ingest"
}

// MetricsURL returns the full metrics endpoint URL.
func MetricsURL() string {
	return GetConfig().Host + "/api/v1/metrics"
}

// DeployURL returns the full deploy event endpoint URL.
func DeployURL() string {
	return GetConfig().Host + "/api/v1/deploy"
}

// BoolPtr is a helper to create a *bool for Config.Enabled.
func BoolPtr(b bool) *bool {
	return &b
}

// resetForTests is exposed for tests that need to clear configured state.
func resetForTests() {
	configMu.Lock()
	defer configMu.Unlock()
	globalConfig = Config{}
	configured = false
	bannerPrinted = false
	resetEnvWarningForTests()
}

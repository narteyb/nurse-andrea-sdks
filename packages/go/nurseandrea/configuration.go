package nurseandrea

import (
	"fmt"
	"os"
	"strings"
	"sync"
)

const defaultHost = "https://nurseandrea.io"

// Config holds all SDK configuration.
type Config struct {
	Token           string
	Host            string
	ServiceName     string
	Enabled         *bool // nil = auto (enabled if token present)
	FlushIntervalMs int
	BatchSize       int
}

var (
	globalConfig Config
	configured   bool
	configMu     sync.RWMutex
)

// Configure sets the global SDK configuration.
// Call once at application startup before using any middleware or interceptors.
func Configure(cfg Config) {
	configMu.Lock()
	defer configMu.Unlock()

	if cfg.Token == "" {
		cfg.Token = os.Getenv("NURSE_ANDREA_TOKEN")
	}
	if cfg.Host == "" {
		cfg.Host = os.Getenv("NURSE_ANDREA_HOST")
	}
	if cfg.Host == "" {
		cfg.Host = defaultHost
	}
	cfg.Host = strings.TrimRight(cfg.Host, "/")

	if cfg.ServiceName == "" {
		cfg.ServiceName = os.Getenv("NURSE_ANDREA_SERVICE_NAME")
	}
	if cfg.ServiceName == "" {
		cfg.ServiceName = os.Getenv("RAILWAY_SERVICE_NAME")
	}
	if cfg.ServiceName == "" {
		cfg.ServiceName = "go-app"
	}
	if cfg.FlushIntervalMs == 0 {
		cfg.FlushIntervalMs = 5000
	}
	if cfg.BatchSize == 0 {
		cfg.BatchSize = 100
	}

	// Enabled defaults to true when token is present
	if cfg.Enabled == nil {
		enabled := cfg.Token != ""
		cfg.Enabled = &enabled
	}

	if cfg.Token == "" {
		fmt.Fprintln(os.Stderr,
			"[NurseAndrea] No token configured. Set NURSE_ANDREA_TOKEN. Monitoring disabled.")
	}

	globalConfig = cfg
	configured = true
}

// GetConfig returns the current configuration.
func GetConfig() Config {
	configMu.RLock()
	if configured {
		c := globalConfig
		configMu.RUnlock()
		return c
	}
	configMu.RUnlock()

	// Auto-configure from env
	Configure(Config{})

	configMu.RLock()
	defer configMu.RUnlock()
	return globalConfig
}

// IsEnabled returns true if the SDK is active.
func IsEnabled() bool {
	cfg := GetConfig()
	return cfg.Enabled != nil && *cfg.Enabled && cfg.Token != ""
}

// IngestURL returns the full ingest endpoint URL.
func IngestURL() string {
	return GetConfig().Host + "/api/v1/ingest"
}

// MetricsURL returns the full metrics endpoint URL.
func MetricsURL() string {
	return GetConfig().Host + "/api/v1/metrics"
}

// BoolPtr is a helper to create a *bool for Config.Enabled.
func BoolPtr(b bool) *bool {
	return &b
}

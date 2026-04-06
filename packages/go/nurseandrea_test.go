package nurseandrea_test

import (
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea"
	namw "github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea/middleware"
)

func resetConfig() {
	// Re-configure to reset global state between tests
	os.Unsetenv("NURSE_ANDREA_TOKEN")
	os.Unsetenv("NURSE_ANDREA_HOST")
	os.Unsetenv("NURSE_ANDREA_SERVICE_NAME")
	os.Unsetenv("RAILWAY_SERVICE_NAME")
}

func TestConfigureDefaultsToProductionHost(t *testing.T) {
	resetConfig()
	nurseandrea.Configure(nurseandrea.Config{Token: "test-token"})
	cfg := nurseandrea.GetConfig()
	if cfg.Host != "https://nurseandrea.io" {
		t.Errorf("expected production host, got %s", cfg.Host)
	}
}

func TestConfigureReadsEnvVars(t *testing.T) {
	resetConfig()
	os.Setenv("NURSE_ANDREA_TOKEN", "env-token")
	os.Setenv("NURSE_ANDREA_HOST", "http://localhost:4500")
	defer os.Unsetenv("NURSE_ANDREA_TOKEN")
	defer os.Unsetenv("NURSE_ANDREA_HOST")

	nurseandrea.Configure(nurseandrea.Config{})
	cfg := nurseandrea.GetConfig()
	if cfg.Token != "env-token" {
		t.Errorf("expected env-token, got %s", cfg.Token)
	}
	if cfg.Host != "http://localhost:4500" {
		t.Errorf("expected localhost, got %s", cfg.Host)
	}
}

func TestIngestURLDerivedFromHost(t *testing.T) {
	resetConfig()
	nurseandrea.Configure(nurseandrea.Config{
		Token: "test",
		Host:  "http://localhost:4500",
	})
	expected := "http://localhost:4500/api/v1/ingest"
	if nurseandrea.IngestURL() != expected {
		t.Errorf("expected %s, got %s", expected, nurseandrea.IngestURL())
	}
}

func TestTrailingSlashStripped(t *testing.T) {
	resetConfig()
	nurseandrea.Configure(nurseandrea.Config{
		Token: "test",
		Host:  "https://staging.nurseandrea.io/",
	})
	expected := "https://staging.nurseandrea.io/api/v1/metrics"
	if nurseandrea.MetricsURL() != expected {
		t.Errorf("expected %s, got %s", expected, nurseandrea.MetricsURL())
	}
}

func TestServiceNamePriority(t *testing.T) {
	resetConfig()
	os.Setenv("NURSE_ANDREA_SERVICE_NAME", "explicit-name")
	os.Setenv("RAILWAY_SERVICE_NAME", "railway-name")
	defer os.Unsetenv("NURSE_ANDREA_SERVICE_NAME")
	defer os.Unsetenv("RAILWAY_SERVICE_NAME")

	nurseandrea.Configure(nurseandrea.Config{Token: "test"})
	cfg := nurseandrea.GetConfig()
	// NURSE_ANDREA_SERVICE_NAME takes priority over RAILWAY_SERVICE_NAME
	if cfg.ServiceName != "explicit-name" {
		t.Errorf("expected NURSE_ANDREA_SERVICE_NAME priority, got %s", cfg.ServiceName)
	}
}

func TestRailwayServiceNameFallback(t *testing.T) {
	resetConfig()
	os.Setenv("RAILWAY_SERVICE_NAME", "my-go-worker")
	defer os.Unsetenv("RAILWAY_SERVICE_NAME")

	nurseandrea.Configure(nurseandrea.Config{Token: "test"})
	cfg := nurseandrea.GetConfig()
	if cfg.ServiceName != "my-go-worker" {
		t.Errorf("expected RAILWAY_SERVICE_NAME fallback, got %s", cfg.ServiceName)
	}
}

func TestDefaultServiceName(t *testing.T) {
	resetConfig()
	nurseandrea.Configure(nurseandrea.Config{Token: "test"})
	cfg := nurseandrea.GetConfig()
	if cfg.ServiceName != "go-app" {
		t.Errorf("expected go-app default, got %s", cfg.ServiceName)
	}
}

func TestDisabledWhenNoToken(t *testing.T) {
	resetConfig()
	nurseandrea.Configure(nurseandrea.Config{})
	if nurseandrea.IsEnabled() {
		t.Error("expected disabled when no token")
	}
}

func TestEnabledWhenTokenPresent(t *testing.T) {
	resetConfig()
	nurseandrea.Configure(nurseandrea.Config{Token: "test-token"})
	if !nurseandrea.IsEnabled() {
		t.Error("expected enabled when token is present")
	}
}

func TestExplicitlyDisabled(t *testing.T) {
	resetConfig()
	nurseandrea.Configure(nurseandrea.Config{
		Token:   "test-token",
		Enabled: nurseandrea.BoolPtr(false),
	})
	if nurseandrea.IsEnabled() {
		t.Error("expected disabled when explicitly set to false")
	}
}

func TestNetHTTPMiddlewarePassesThrough(t *testing.T) {
	resetConfig()
	nurseandrea.Configure(nurseandrea.Config{
		Token:   "test",
		Enabled: nurseandrea.BoolPtr(true),
	})

	handler := namw.NetHTTP(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/ping", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rec.Code)
	}
}

func TestNetHTTPMiddlewareDisabled(t *testing.T) {
	resetConfig()
	nurseandrea.Configure(nurseandrea.Config{
		Token:   "",
		Enabled: nurseandrea.BoolPtr(false),
	})

	called := false
	handler := namw.NetHTTP(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/ping", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if !called {
		t.Error("expected handler to be called even when SDK disabled")
	}
}

func TestNetHTTPMiddlewareCapturesStatusCode(t *testing.T) {
	resetConfig()
	nurseandrea.Configure(nurseandrea.Config{
		Token:   "test",
		Enabled: nurseandrea.BoolPtr(true),
	})

	handler := namw.NetHTTP(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))

	req := httptest.NewRequest(http.MethodGet, "/missing", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", rec.Code)
	}
}

func TestVersionConstant(t *testing.T) {
	if nurseandrea.Version == "" {
		t.Error("expected non-empty Version constant")
	}
	if nurseandrea.Version != "0.1.0" {
		t.Errorf("expected 0.1.0, got %s", nurseandrea.Version)
	}
}

func TestBatchSizeDefaults(t *testing.T) {
	resetConfig()
	nurseandrea.Configure(nurseandrea.Config{Token: "test"})
	cfg := nurseandrea.GetConfig()
	if cfg.BatchSize != 100 {
		t.Errorf("expected batch size 100, got %d", cfg.BatchSize)
	}
	if cfg.FlushIntervalMs != 5000 {
		t.Errorf("expected flush interval 5000, got %d", cfg.FlushIntervalMs)
	}
}

func TestMetricsURLDerivedFromHost(t *testing.T) {
	resetConfig()
	nurseandrea.Configure(nurseandrea.Config{
		Token: "test",
		Host:  "http://localhost:4500",
	})
	expected := "http://localhost:4500/api/v1/metrics"
	if nurseandrea.MetricsURL() != expected {
		t.Errorf("expected %s, got %s", expected, nurseandrea.MetricsURL())
	}
}

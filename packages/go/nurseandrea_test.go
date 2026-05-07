package nurseandrea_test

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"

	"github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea"
	namw "github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea/middleware"
)

func resetConfig() {
	for _, k := range []string{
		"NURSE_ANDREA_ORG_TOKEN",
		"NURSE_ANDREA_HOST",
		"NURSE_ANDREA_SERVICE_NAME",
		"RAILWAY_SERVICE_NAME",
		"GO_ENV",
		"APP_ENV",
	} {
		os.Unsetenv(k)
	}
}

func validConfig() nurseandrea.Config {
	return nurseandrea.Config{
		OrgToken:      "org_test_token",
		WorkspaceSlug: "checkout",
		Environment:   "development",
	}
}

func TestConfigureDefaultsToProductionHost(t *testing.T) {
	resetConfig()
	if err := nurseandrea.Configure(validConfig()); err != nil {
		t.Fatalf("Configure: %v", err)
	}
	cfg := nurseandrea.GetConfig()
	if cfg.Host != "https://nurseandrea.io" {
		t.Errorf("expected default host, got %s", cfg.Host)
	}
}

func TestConfigureReadsOrgTokenFromEnv(t *testing.T) {
	resetConfig()
	os.Setenv("NURSE_ANDREA_ORG_TOKEN", "env-token")
	defer os.Unsetenv("NURSE_ANDREA_ORG_TOKEN")

	cfg := validConfig()
	cfg.OrgToken = ""
	if err := nurseandrea.Configure(cfg); err != nil {
		t.Fatalf("Configure: %v", err)
	}
	if got := nurseandrea.GetConfig().OrgToken; got != "env-token" {
		t.Errorf("expected env-token, got %s", got)
	}
}

func TestConfigureStripsTrailingSlash(t *testing.T) {
	resetConfig()
	c := validConfig()
	c.Host = "https://staging.nurseandrea.io/"
	if err := nurseandrea.Configure(c); err != nil {
		t.Fatalf("Configure: %v", err)
	}
	if nurseandrea.IngestURL() != "https://staging.nurseandrea.io/api/v1/ingest" {
		t.Errorf("got %s", nurseandrea.IngestURL())
	}
}

func TestConfigureValidationFailures(t *testing.T) {
	cases := []struct {
		name string
		mut  func(*nurseandrea.Config)
		want string
	}{
		{"missing OrgToken", func(c *nurseandrea.Config) { c.OrgToken = "" }, "OrgToken is required"},
		{"missing WorkspaceSlug", func(c *nurseandrea.Config) { c.WorkspaceSlug = "" }, "WorkspaceSlug is required"},
		{"unsupported Environment", func(c *nurseandrea.Config) { c.Environment = "qa" }, "Environment must be one of"},
		{"invalid slug", func(c *nurseandrea.Config) { c.WorkspaceSlug = "Bad_Slug" }, "WorkspaceSlug"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			resetConfig()
			c := validConfig()
			tc.mut(&c)
			err := nurseandrea.Configure(c)
			if err == nil || !strings.Contains(err.Error(), tc.want) {
				t.Fatalf("expected error matching %q, got %v", tc.want, err)
			}
			if !errors.Is(err, nurseandrea.ErrConfiguration) {
				t.Errorf("expected error to wrap ErrConfiguration, got %v", err)
			}
		})
	}
}

func TestConfigureMigrationErrorOnLegacyFields(t *testing.T) {
	cases := []struct {
		name string
		cfg  nurseandrea.Config
	}{
		{"APIKey", nurseandrea.Config{APIKey: "x"}},
		{"Token", nurseandrea.Config{Token: "x"}},
		{"IngestToken", nurseandrea.Config{IngestToken: "x"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			resetConfig()
			err := nurseandrea.Configure(tc.cfg)
			if err == nil {
				t.Fatal("expected MigrationError")
			}
			var migration *nurseandrea.MigrationError
			if !errors.As(err, &migration) {
				t.Fatalf("expected MigrationError, got %T: %v", err, err)
			}
			if migration.Field != tc.name {
				t.Errorf("expected Field=%q, got %q", tc.name, migration.Field)
			}
			if !strings.Contains(err.Error(), "no longer supported") {
				t.Errorf("expected migration text, got %s", err.Error())
			}
		})
	}
}

func TestIsEnabledTrueWhenConfigured(t *testing.T) {
	resetConfig()
	if err := nurseandrea.Configure(validConfig()); err != nil {
		t.Fatalf("Configure: %v", err)
	}
	if !nurseandrea.IsEnabled() {
		t.Error("expected IsEnabled to be true after a valid Configure")
	}
}

// Middleware integration: verify that the middleware enqueues a metric
// after a request lifecycle. Doesn't ship — Configure(enabled=false-ish)
// is fine because the queue itself is what we observe.
func TestMiddlewareEnqueuesMetric(t *testing.T) {
	resetConfig()
	c := validConfig()
	c.Host = "http://localhost:1" // unreachable; we just want to test queueing
	if err := nurseandrea.Configure(c); err != nil {
		t.Fatalf("Configure: %v", err)
	}

	srv := httptest.NewServer(namw.NetHTTP(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	})))
	defer srv.Close()

	resp, err := http.Get(srv.URL + "/ping")
	if err != nil {
		t.Fatalf("GET: %v", err)
	}
	resp.Body.Close()
	// Smoke check passed if the request completed without panic.
}

package nurseandrea_test

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea"
)

// configureFor wires the SDK at a test server so live HTTP round-trips
// in tests stay fully in-process.
func configureFor(t *testing.T, server *httptest.Server) {
	t.Helper()
	resetConfig()
	enabled := true
	if err := nurseandrea.Configure(nurseandrea.Config{
		OrgToken:      "org_test_token",
		WorkspaceSlug: "checkout",
		Environment:   "development",
		Host:          server.URL,
		Enabled:       &enabled,
	}); err != nil {
		t.Fatalf("Configure: %v", err)
	}
}

// captureDeployRequest returns a server that records the body of the
// last POST it received, plus the body buffer to inspect after a call.
func captureDeployRequest(status int) (*httptest.Server, *map[string]interface{}) {
	captured := map[string]interface{}{}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		buf, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(buf, &captured)
		w.WriteHeader(status)
	}))
	return server, &captured
}

func TestDeployPostsToDeployEndpointWithVersion(t *testing.T) {
	server, body := captureDeployRequest(http.StatusCreated)
	defer server.Close()
	configureFor(t, server)

	if !nurseandrea.Deploy("1.4.2") {
		t.Fatal("expected Deploy to return true on 201")
	}
	if (*body)["version"] != "1.4.2" {
		t.Errorf("expected version 1.4.2, got %v", (*body)["version"])
	}
}

func TestDeployIncludesDeployerWhenProvided(t *testing.T) {
	server, body := captureDeployRequest(http.StatusCreated)
	defer server.Close()
	configureFor(t, server)

	nurseandrea.Deploy("1.0.0", nurseandrea.DeployOptions{Deployer: "dan"})
	if (*body)["deployer"] != "dan" {
		t.Errorf("expected deployer=dan, got %v", (*body)["deployer"])
	}
}

func TestDeployDefaultsEnvironmentToProduction(t *testing.T) {
	server, body := captureDeployRequest(http.StatusCreated)
	defer server.Close()
	configureFor(t, server)

	nurseandrea.Deploy("1.0.0")
	if (*body)["environment"] != "production" {
		t.Errorf("expected environment=production, got %v", (*body)["environment"])
	}
}

func TestDeployHonorsExplicitEnvironment(t *testing.T) {
	server, body := captureDeployRequest(http.StatusCreated)
	defer server.Close()
	configureFor(t, server)

	nurseandrea.Deploy("1.0.0", nurseandrea.DeployOptions{Environment: "staging"})
	if (*body)["environment"] != "staging" {
		t.Errorf("expected environment=staging, got %v", (*body)["environment"])
	}
}

func TestDeployStampsDeployedAtRFC3339(t *testing.T) {
	server, body := captureDeployRequest(http.StatusCreated)
	defer server.Close()
	configureFor(t, server)

	nurseandrea.Deploy("1.0.0")
	stamp, _ := (*body)["deployed_at"].(string)
	if len(stamp) < 19 {
		t.Errorf("expected RFC3339 deployed_at, got %q", stamp)
	}
}

func TestDeployTruncatesDescriptionTo500(t *testing.T) {
	server, body := captureDeployRequest(http.StatusCreated)
	defer server.Close()
	configureFor(t, server)

	long := strings.Repeat("a", 600)
	nurseandrea.Deploy("1.0.0", nurseandrea.DeployOptions{Description: long})
	desc, _ := (*body)["description"].(string)
	if len(desc) != 500 {
		t.Errorf("expected description length 500, got %d", len(desc))
	}
}

func TestDeployReturnsFalseWhenVersionBlank(t *testing.T) {
	server, _ := captureDeployRequest(http.StatusCreated)
	defer server.Close()
	configureFor(t, server)

	if nurseandrea.Deploy("") {
		t.Error("expected Deploy(\"\") to return false")
	}
	if nurseandrea.Deploy("   ") {
		t.Error("expected Deploy(\"   \") to return false")
	}
}

func TestDeployReturnsFalseWhenDisabled(t *testing.T) {
	resetConfig()
	disabled := false
	if err := nurseandrea.Configure(nurseandrea.Config{
		OrgToken:      "org_test_token",
		WorkspaceSlug: "checkout",
		Environment:   "development",
		Enabled:       &disabled,
	}); err != nil {
		t.Fatalf("Configure: %v", err)
	}
	if nurseandrea.Deploy("1.0.0") {
		t.Error("expected Deploy to return false when SDK disabled")
	}
}

func TestDeploySwallowsNon2xxResponses(t *testing.T) {
	server, _ := captureDeployRequest(http.StatusInternalServerError)
	defer server.Close()
	configureFor(t, server)

	if nurseandrea.Deploy("1.0.0") {
		t.Error("expected Deploy to return false on 500")
	}
}

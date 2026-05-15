package nurseandrea_test

// Sprint B D2 — cross-runtime parity test (Go leg).
//
// Asserts the three behavioral dimensions defined in
// docs/sdk/payload-format.md: header parity, payload structure
// parity, misconfiguration degradation parity. The other three
// runtimes have equivalent parity tests
// (ruby/spec/nurse_andrea/parity_spec.rb,
// node/tests/parity.test.ts, python/tests/test_parity.py) that
// assert the same shape. The .github/workflows/sdk-parity.yml
// matrix runs all four; the suite is only meaningful if every leg
// passes.

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"regexp"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea"
)

type captured struct {
	mu       sync.Mutex
	requests []*http.Request
	bodies   [][]byte
}

func (c *captured) record(r *http.Request) {
	c.mu.Lock()
	defer c.mu.Unlock()
	body, _ := io.ReadAll(r.Body)
	c.requests = append(c.requests, r)
	c.bodies = append(c.bodies, body)
}

func (c *captured) waitFor(t *testing.T, suffix string, timeout time.Duration) (*http.Request, []byte) {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		c.mu.Lock()
		for i, r := range c.requests {
			if strings.HasSuffix(r.URL.Path, suffix) {
				body := c.bodies[i]
				c.mu.Unlock()
				return r, body
			}
		}
		c.mu.Unlock()
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("no POST to %s within %s", suffix, timeout)
	return nil, nil
}

func parityHost(t *testing.T, c *captured) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		c.record(r)
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("{}"))
	}))
	t.Cleanup(srv.Close)
	return srv
}

func parityConfigure(t *testing.T, host string) {
	t.Helper()
	resetConfig()
	err := nurseandrea.Configure(nurseandrea.Config{
		OrgToken:      "org_parity_test_aaaaaaaaaaaaaaaaaaaa",
		WorkspaceSlug: "parity-test",
		Environment:   "development",
		Host:          host,
		Enabled:       nurseandrea.BoolPtr(true),
		BatchSize:     1,
	})
	if err != nil {
		t.Fatalf("Configure: %v", err)
	}
}

// ─── Header parity ─────────────────────────────────────────────

func TestParityHeadersIngest(t *testing.T) {
	c := &captured{}
	srv := parityHost(t, c)
	parityConfigure(t, srv.URL)

	nurseandrea.GetClient().EnqueueLog("info", "x", nil)
	req, _ := c.waitFor(t, "/api/v1/ingest", 2*time.Second)
	checkCanonicalHeaders(t, req, "go")
}

func TestParityHeadersMetrics(t *testing.T) {
	c := &captured{}
	srv := parityHost(t, c)
	parityConfigure(t, srv.URL)

	nurseandrea.GetClient().EnqueueMetric("process.memory.rss", 1.0, "bytes", nil)
	req, _ := c.waitFor(t, "/api/v1/metrics", 2*time.Second)
	checkCanonicalHeaders(t, req, "go")
}

func TestParityHeadersDeploy(t *testing.T) {
	c := &captured{}
	srv := parityHost(t, c)
	parityConfigure(t, srv.URL)

	nurseandrea.Deploy("1.0.0")
	req, _ := c.waitFor(t, "/api/v1/deploy", 2*time.Second)
	// Sprint B D2 added X-NurseAndrea-SDK to Go's deploy headers.
	checkCanonicalHeaders(t, req, "go")
}

func checkCanonicalHeaders(t *testing.T, r *http.Request, lang string) {
	t.Helper()
	if got := r.Header.Get("Content-Type"); got != "application/json" {
		t.Errorf("Content-Type: got %q want application/json", got)
	}
	if got := r.Header.Get("Authorization"); got != "Bearer org_parity_test_aaaaaaaaaaaaaaaaaaaa" {
		t.Errorf("Authorization: got %q", got)
	}
	if got := r.Header.Get("X-NurseAndrea-Workspace"); got != "parity-test" {
		t.Errorf("X-NurseAndrea-Workspace: got %q", got)
	}
	if got := r.Header.Get("X-NurseAndrea-Environment"); got != "development" {
		t.Errorf("X-NurseAndrea-Environment: got %q", got)
	}
	sdk := r.Header.Get("X-NurseAndrea-SDK")
	matched, _ := regexp.MatchString(`^`+lang+`/\d+\.\d+\.\d+$`, sdk)
	if !matched {
		t.Errorf("X-NurseAndrea-SDK: got %q, expected %s/<semver>", sdk, lang)
	}
}

// ─── Payload structure parity ─────────────────────────────────

func TestParityLogPayloadStructure(t *testing.T) {
	c := &captured{}
	srv := parityHost(t, c)
	parityConfigure(t, srv.URL)

	nurseandrea.GetClient().EnqueueLog("info", "parity", map[string]interface{}{"k": "v"})
	_, body := c.waitFor(t, "/api/v1/ingest", 2*time.Second)

	var parsed map[string]interface{}
	if err := json.Unmarshal(body, &parsed); err != nil {
		t.Fatalf("body not JSON: %v", err)
	}
	for _, key := range []string{"services", "sdk_version", "sdk_language", "logs"} {
		if _, ok := parsed[key]; !ok {
			t.Errorf("top-level missing %q", key)
		}
	}
	if parsed["sdk_language"] != "go" {
		t.Errorf("sdk_language: got %v want go", parsed["sdk_language"])
	}
	logs := parsed["logs"].([]interface{})
	entry := logs[0].(map[string]interface{})
	for _, key := range []string{"level", "message", "occurred_at", "source", "payload"} {
		if _, ok := entry[key]; !ok {
			t.Errorf("log entry missing %q (got keys: %v)", key, keys(entry))
		}
	}
}

func TestParityMetricPayloadStructure(t *testing.T) {
	c := &captured{}
	srv := parityHost(t, c)
	parityConfigure(t, srv.URL)

	nurseandrea.GetClient().EnqueueMetric("process.memory.rss", 1.0, "bytes", nil)
	_, body := c.waitFor(t, "/api/v1/metrics", 2*time.Second)

	var parsed map[string]interface{}
	if err := json.Unmarshal(body, &parsed); err != nil {
		t.Fatalf("body not JSON: %v", err)
	}
	for _, key := range []string{"sdk_version", "sdk_language", "metrics"} {
		if _, ok := parsed[key]; !ok {
			t.Errorf("top-level missing %q", key)
		}
	}
	if parsed["sdk_language"] != "go" {
		t.Errorf("sdk_language: got %v want go", parsed["sdk_language"])
	}
	metrics := parsed["metrics"].([]interface{})
	entry := metrics[0].(map[string]interface{})
	for _, key := range []string{"name", "value", "unit", "occurred_at", "tags"} {
		if _, ok := entry[key]; !ok {
			t.Errorf("metric entry missing %q (got keys: %v)", key, keys(entry))
		}
	}
}

func keys(m map[string]interface{}) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
}

// ─── Misconfig degradation parity ─────────────────────────────

func TestParityMisconfigReturnsError(t *testing.T) {
	// Go's idiom is "return error" rather than "raise" — Configure
	// signals misconfiguration via err != nil. The cross-runtime
	// parity contract (docs/sdk/payload-format.md §6) calls for "no
	// raise at SDK boot" — returning an error qualifies as not
	// raising. Callers are expected to inspect the error and either
	// log-and-continue or fail-fast at their discretion.
	resetConfig()
	err := nurseandrea.Configure(nurseandrea.Config{
		// No OrgToken.
		WorkspaceSlug: "parity-test",
		Environment:   "development",
	})
	if err == nil {
		t.Fatal("expected error for missing OrgToken")
	}
	if !strings.Contains(err.Error(), "OrgToken") {
		t.Errorf("error message does not name OrgToken: %v", err)
	}
}

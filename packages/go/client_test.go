package nurseandrea_test

import (
	"strings"
	"testing"

	"github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea"
)

func TestBuildHeadersEmitsNewAuthContract(t *testing.T) {
	resetConfig()
	if err := nurseandrea.Configure(validConfig()); err != nil {
		t.Fatalf("Configure: %v", err)
	}
	headers := nurseandrea.GetClient().BuildHeaders()
	if got := headers["Authorization"]; got != "Bearer org_test_token" {
		t.Errorf("Authorization: got %q", got)
	}
	if got := headers["X-NurseAndrea-Workspace"]; got != "checkout" {
		t.Errorf("X-NurseAndrea-Workspace: got %q", got)
	}
	if got := headers["X-NurseAndrea-Environment"]; got != "development" {
		t.Errorf("X-NurseAndrea-Environment: got %q", got)
	}
	if got := headers["X-NurseAndrea-SDK"]; got != "go/1.0.0" {
		t.Errorf("X-NurseAndrea-SDK: got %q", got)
	}
}

func TestRejectionCounterSilentFor4(t *testing.T) {
	resetConfig()
	if err := nurseandrea.Configure(validConfig()); err != nil {
		t.Fatalf("Configure: %v", err)
	}
	c := nurseandrea.GetClient()
	c.ResetRejectionState()

	output := captureStderr(t, func() {
		for i := 0; i < 4; i++ {
			c.HandleResponse(401, []byte(`{"error":"invalid_org_token"}`), "u")
		}
	})
	if strings.Contains(output, "Ingest rejected") {
		t.Errorf("expected silence, got %q", output)
	}
}

func TestRejectionCounterWarnsOnceAt5(t *testing.T) {
	resetConfig()
	if err := nurseandrea.Configure(validConfig()); err != nil {
		t.Fatalf("Configure: %v", err)
	}
	c := nurseandrea.GetClient()
	c.ResetRejectionState()

	output := captureStderr(t, func() {
		for i := 0; i < 8; i++ {
			c.HandleResponse(401, []byte(`{"error":"invalid_org_token"}`), "u")
		}
	})
	count := strings.Count(output, "Ingest rejected")
	if count != 1 {
		t.Errorf("expected 1 warning, got %d (output=%q)", count, output)
	}
	if !strings.Contains(output, "invalid_org_token") {
		t.Errorf("expected error code in warning, got %q", output)
	}
	if !strings.Contains(output, "Check NURSE_ANDREA_ORG_TOKEN") {
		t.Errorf("expected guidance text, got %q", output)
	}
}

func TestRejectionCounterResetsOnSuccess(t *testing.T) {
	resetConfig()
	if err := nurseandrea.Configure(validConfig()); err != nil {
		t.Fatalf("Configure: %v", err)
	}
	c := nurseandrea.GetClient()
	c.ResetRejectionState()

	output := captureStderr(t, func() {
		for i := 0; i < 4; i++ {
			c.HandleResponse(401, []byte(`{"error":"invalid_org_token"}`), "u")
		}
		c.HandleResponse(200, []byte(`{}`), "u")
		for i := 0; i < 4; i++ {
			c.HandleResponse(401, []byte(`{"error":"invalid_org_token"}`), "u")
		}
	})
	if strings.Contains(output, "Ingest rejected") {
		t.Errorf("expected reset to suppress warning, got %q", output)
	}
}

func TestRejectionCounterIgnores5xx(t *testing.T) {
	resetConfig()
	if err := nurseandrea.Configure(validConfig()); err != nil {
		t.Fatalf("Configure: %v", err)
	}
	c := nurseandrea.GetClient()
	c.ResetRejectionState()

	output := captureStderr(t, func() {
		for i := 0; i < 6; i++ {
			c.HandleResponse(503, []byte(``), "u")
		}
	})
	if strings.Contains(output, "Ingest rejected") {
		t.Errorf("expected 5xx to skip rejection counter, got %q", output)
	}
}

// Smoke test for the NurseAndrea Go SDK 1.0 against a running NA instance.
//
// Usage:
//
//	LOCAL_ORG_TOKEN=org_xxx \
//	  LOCAL_WORKSPACE_SLUG=somfo \
//	  go run integration_tests/smoke.go
//
// Optional:
//
//	LOCAL_NA_HOST (default: http://localhost:4500)
//
// Exits 0 on success, non-zero on failure.
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"runtime"
	"time"

	"github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea"
)

func main() {
	orgToken := os.Getenv("LOCAL_ORG_TOKEN")
	if orgToken == "" {
		fmt.Fprintln(os.Stderr, "LOCAL_ORG_TOKEN is required.")
		os.Exit(2)
	}
	host := envOr("LOCAL_NA_HOST", "http://localhost:4500")
	slug := envOr("LOCAL_WORKSPACE_SLUG", "smoke-test-go")

	fmt.Printf("[smoke] Configuring NurseAndrea SDK go %s\n", nurseandrea.Version)
	fmt.Printf("[smoke]   host:           %s\n", host)
	fmt.Printf("[smoke]   workspace_slug: %s\n", slug)
	fmt.Println("[smoke]   environment:    development")

	if err := nurseandrea.Configure(nurseandrea.Config{
		OrgToken:        orgToken,
		WorkspaceSlug:   slug,
		Environment:     "development",
		Host:            host,
		FlushIntervalMs: 60_000,
		BatchSize:       1,
	}); err != nil {
		fmt.Fprintf(os.Stderr, "[smoke] Configure error: %v\n", err)
		os.Exit(1)
	}

	headers := nurseandrea.GetClient().BuildHeaders()
	httpClient := &http.Client{Timeout: 10 * time.Second}

	fmt.Println("[smoke] Posting 5 ingest payloads via http with SDK headers...")
	success := 0
	for i := 0; i < 5; i++ {
		payload := map[string]interface{}{
			"services":     []string{"smoke-test-go"},
			"sdk_version":  nurseandrea.Version,
			"sdk_language": nurseandrea.SDKLanguage,
			"logs": []map[string]interface{}{
				{
					"level":       "info",
					"message":     fmt.Sprintf("smoke test #%d", i),
					"occurred_at": time.Now().UTC().Format(time.RFC3339),
					"source":      "smoke-test-go",
					"payload":     map[string]interface{}{"iteration": i, "go_version": runtime.Version()},
				},
			},
		}

		body, _ := json.Marshal(payload)
		req, _ := http.NewRequest("POST", host+"/api/v1/ingest", bytes.NewReader(body))
		for k, v := range headers {
			req.Header.Set(k, v)
		}
		resp, err := httpClient.Do(req)
		if err != nil {
			fmt.Printf("x(%v)", err)
			continue
		}
		resp.Body.Close()
		if resp.StatusCode >= 200 && resp.StatusCode < 300 {
			success++
			fmt.Print(".")
		} else {
			fmt.Printf("x(%d)", resp.StatusCode)
		}
	}
	fmt.Println()

	if success == 5 {
		fmt.Println("[smoke] OK — all 5 events accepted.")
		nurseandrea.Shutdown()
		os.Exit(0)
	}
	fmt.Fprintf(os.Stderr, "[smoke] FAIL — only %d/5 events accepted.\n", success)
	nurseandrea.Shutdown()
	os.Exit(1)
}

func envOr(name, fallback string) string {
	if v := os.Getenv(name); v != "" {
		return v
	}
	return fallback
}

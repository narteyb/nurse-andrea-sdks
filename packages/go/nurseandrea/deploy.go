package nurseandrea

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"
)

// DeployOptions are the optional fields accepted by Deploy.
type DeployOptions struct {
	Deployer    string
	Environment string
	Description string
}

const deployDescriptionLimit = 500

// Deploy ships a deploy event to the NurseAndrea backend so the
// dashboard can render it as a vertical marker on time-series charts
// and as a chip in the recent-deploys strip.
//
// Fire-and-forget: any failure (no token, network error, non-2xx) is
// logged to stderr and swallowed so the host application never crashes
// from a deploy notification.
//
// Usage:
//
//	nurseandrea.Deploy("1.4.2", nurseandrea.DeployOptions{Deployer: "dan"})
func Deploy(version string, opts ...DeployOptions) bool {
	if !IsEnabled() {
		return false
	}
	if strings.TrimSpace(version) == "" {
		return false
	}

	var o DeployOptions
	if len(opts) > 0 {
		o = opts[0]
	}
	if o.Environment == "" {
		o.Environment = "production"
	}
	if len(o.Description) > deployDescriptionLimit {
		o.Description = o.Description[:deployDescriptionLimit]
	}

	body := map[string]interface{}{
		"version":     version,
		"deployer":    nullable(o.Deployer),
		"environment": o.Environment,
		"description": nullable(o.Description),
		"deployed_at": time.Now().UTC().Format(time.RFC3339),
	}

	buf, err := json.Marshal(body)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[NurseAndrea] deploy() marshal error: %s\n", err)
		return false
	}

	req, err := http.NewRequest("POST", DeployURL(), bytes.NewReader(buf))
	if err != nil {
		fmt.Fprintf(os.Stderr, "[NurseAndrea] deploy() build error: %s\n", err)
		return false
	}
	cfg := GetConfig()
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+cfg.OrgToken)
	req.Header.Set("X-NurseAndrea-Workspace", cfg.WorkspaceSlug)
	req.Header.Set("X-NurseAndrea-Environment", cfg.Environment)

	resp, err := (&http.Client{Timeout: 10 * time.Second}).Do(req)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[NurseAndrea] deploy() error: %s\n", err)
		return false
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		fmt.Fprintf(os.Stderr, "[NurseAndrea] deploy() POST %s -> %d\n", DeployURL(), resp.StatusCode)
		return false
	}
	return true
}

// nullable returns nil for an empty string so the JSON payload encodes
// it as `null` rather than `""` — matches the Ruby/Node/Python shape.
func nullable(s string) interface{} {
	if s == "" {
		return nil
	}
	return s
}

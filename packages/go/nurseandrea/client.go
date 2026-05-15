package nurseandrea

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"runtime"
	"sync"
	"time"
)

const (
	rejectionWarningThreshold = 5
)

var rejectionStatuses = map[int]bool{401: true, 403: true, 422: true, 429: true}

// LogEntry represents a single log event to ship.
//
// Sprint B D2 — JSON tags aligned to the canonical wire spec
// (docs/sdk/payload-format.md §3.2). Pre-Sprint-B Go alone emitted
// `timestamp` / `service` / `metadata` while Ruby/Node/Python all
// emitted `occurred_at` / `source` / `payload`. The Go struct field
// names stay Go-idiomatic; only the JSON wire tags changed.
// Per-entry SDKVersion / SDKLanguage were also dropped — they ride
// on the top-level batch payload, not on each entry.
type LogEntry struct {
	Level     string                 `json:"level"`
	Message   string                 `json:"message"`
	Timestamp string                 `json:"occurred_at"`
	Service   string                 `json:"source"`
	Metadata  map[string]interface{} `json:"payload,omitempty"`
}

// MetricEntry represents a single metric data point.
//
// Sprint B D2 — `timestamp` JSON tag aligned to the canonical
// `occurred_at` wire key (Ruby + Python were already using it; Node
// + Go diverged). Per-entry SDKVersion / SDKLanguage dropped; they
// ride on the top-level metrics batch payload.
type MetricEntry struct {
	Name      string            `json:"name"`
	Value     float64           `json:"value"`
	Unit      string            `json:"unit"`
	Timestamp string            `json:"occurred_at"`
	Tags      map[string]string `json:"tags"`
}

// Client manages batching and flushing of telemetry data.
type Client struct {
	mu          sync.Mutex
	logQueue    []LogEntry
	metricQueue []MetricEntry
	stopCh      chan struct{}
	stopped     bool
	httpClient  *http.Client

	rejectionMu            sync.Mutex
	consecutiveRejections  int
	warnedForError         string
}

var (
	globalClient *Client
	clientOnce   sync.Once
)

// GetClient returns the global singleton client.
func GetClient() *Client {
	clientOnce.Do(func() {
		globalClient = &Client{
			stopCh:     make(chan struct{}),
			httpClient: &http.Client{Timeout: 10 * time.Second},
		}
		go globalClient.flushLoop()
	})
	return globalClient
}

// Stop flushes remaining data and shuts down the client.
func (c *Client) Stop() {
	c.mu.Lock()
	if c.stopped {
		c.mu.Unlock()
		return
	}
	c.stopped = true
	c.mu.Unlock()

	close(c.stopCh)
	c.flush()
}

// ResetRejectionState is exposed for tests that exercise the rejection counter.
func (c *Client) ResetRejectionState() {
	c.rejectionMu.Lock()
	defer c.rejectionMu.Unlock()
	c.consecutiveRejections = 0
	c.warnedForError = ""
}

// BuildHeaders returns the new 1.0 auth contract headers.
func (c *Client) BuildHeaders() map[string]string {
	cfg := GetConfig()
	return map[string]string{
		"Content-Type":              "application/json",
		"Authorization":             "Bearer " + cfg.OrgToken,
		"X-NurseAndrea-Workspace":   cfg.WorkspaceSlug,
		"X-NurseAndrea-Environment": cfg.Environment,
		"X-NurseAndrea-SDK":         SDKLanguage + "/" + Version,
	}
}

// HandleResponse interprets the HTTP status + body for rejection-counter
// bookkeeping. Exposed for tests.
func (c *Client) HandleResponse(statusCode int, body []byte, url string) {
	if statusCode >= 200 && statusCode < 300 {
		c.rejectionMu.Lock()
		c.consecutiveRejections = 0
		c.warnedForError = ""
		c.rejectionMu.Unlock()
		return
	}

	if !rejectionStatuses[statusCode] {
		fmt.Fprintf(os.Stderr, "[NurseAndrea] POST %s -> %d\n", url, statusCode)
		return
	}

	c.rejectionMu.Lock()
	defer c.rejectionMu.Unlock()
	c.consecutiveRejections++
	if c.consecutiveRejections < rejectionWarningThreshold {
		return
	}

	var parsed struct {
		Error   string `json:"error"`
		Message string `json:"message"`
	}
	_ = json.Unmarshal(body, &parsed)

	if c.warnedForError == parsed.Error {
		return
	}
	c.warnedForError = parsed.Error

	cfg := GetConfig()
	errorCode := parsed.Error
	if errorCode == "" {
		errorCode = "(unknown)"
	}
	details := ""
	if parsed.Message != "" {
		details = " Details: " + parsed.Message
	}
	fmt.Fprintf(os.Stderr,
		"[NurseAndrea] Ingest rejected (%d+ consecutive). Status: %d Error: %s. %s%s\n",
		rejectionWarningThreshold, statusCode, errorCode,
		guidanceFor(parsed.Error, cfg), details)
}

func guidanceFor(errorCode string, cfg Config) string {
	switch errorCode {
	case "invalid_org_token":
		return "Check NURSE_ANDREA_ORG_TOKEN."
	case "workspace_rejected":
		return "Restore the workspace in the dashboard or change WorkspaceSlug."
	case "workspace_limit_exceeded":
		return "Org has reached its workspace limit. Reject unused workspaces or upgrade plan."
	case "auto_create_disabled":
		return "Auto-create disabled. Create the workspace explicitly in the dashboard before ingesting."
	case "environment_not_accepted_by_this_install":
		return fmt.Sprintf("Environment %q not accepted by NurseAndrea at %s. Check NURSE_ANDREA_HOST.",
			cfg.Environment, cfg.Host)
	case "invalid_workspace_slug":
		return SlugRulesHuman
	case "similar_slug_exists":
		return "A similar slug already exists in this org. Did you mean an existing one?"
	case "creation_rate_limit_exceeded", "rate_limited":
		return "Workspace creation rate limit hit. Existing workspaces still ingesting normally."
	default:
		return ""
	}
}

func (c *Client) flushLoop() {
	cfg := GetConfig()
	ticker := time.NewTicker(time.Duration(cfg.FlushIntervalMs) * time.Millisecond)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			c.collectProcessMemory()
			c.flush()
		case <-c.stopCh:
			return
		}
	}
}

func (c *Client) collectProcessMemory() {
	defer func() { recover() }()
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	c.EnqueueMetric("process.memory.rss", float64(m.Sys), "bytes", nil)
}

// EnqueueLog adds a log entry to the outbound queue.
func (c *Client) EnqueueLog(level, message string, metadata map[string]interface{}) {
	if !IsEnabled() {
		return
	}
	cfg := GetConfig()
	entry := LogEntry{
		Level:     level,
		Message:   message,
		Timestamp: time.Now().UTC().Format(time.RFC3339Nano),
		Service:   cfg.ServiceName,
		Metadata:  metadata,
	}
	c.mu.Lock()
	c.logQueue = append(c.logQueue, entry)
	shouldFlush := len(c.logQueue) >= cfg.BatchSize
	c.mu.Unlock()
	if shouldFlush {
		go c.flush()
	}
}

// EnqueueMetric adds a metric data point to the outbound queue.
func (c *Client) EnqueueMetric(name string, value float64, unit string, tags map[string]string) {
	if !IsEnabled() {
		return
	}
	cfg := GetConfig()
	if tags == nil {
		tags = make(map[string]string)
	}
	tags["service"] = cfg.ServiceName
	entry := MetricEntry{
		Name:      name,
		Value:     value,
		Unit:      unit,
		Timestamp: time.Now().UTC().Format(time.RFC3339Nano),
		Tags:      tags,
	}
	c.mu.Lock()
	c.metricQueue = append(c.metricQueue, entry)
	shouldFlush := len(c.metricQueue) >= cfg.BatchSize
	c.mu.Unlock()
	if shouldFlush {
		go c.flush()
	}
}

func (c *Client) flush() {
	if !IsEnabled() {
		return
	}
	c.mu.Lock()
	logs := c.logQueue
	metrics := c.metricQueue
	c.logQueue = nil
	c.metricQueue = nil
	c.mu.Unlock()

	headers := c.BuildHeaders()

	if len(logs) > 0 {
		payload := map[string]interface{}{
			"services":     []string{GetConfig().ServiceName},
			"sdk_version":  Version,
			"sdk_language": SDKLanguage,
			"logs":         logs,
		}
		if err := c.post(IngestURL(), headers, payload); err != nil {
			c.mu.Lock()
			c.logQueue = append(logs, c.logQueue...)
			c.mu.Unlock()
		}
	}

	if len(metrics) > 0 {
		payload := map[string]interface{}{
			"sdk_version":  Version,
			"sdk_language": SDKLanguage,
			"metrics":      metrics,
		}
		if err := c.post(MetricsURL(), headers, payload); err != nil {
			c.mu.Lock()
			c.metricQueue = append(metrics, c.metricQueue...)
			c.mu.Unlock()
		}
	}
}

func (c *Client) post(url string, headers map[string]string, payload interface{}) error {
	body, err := json.Marshal(payload)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[NurseAndrea] marshal error: %v\n", err)
		return fmt.Errorf("nurseandrea: marshal error: %w", err)
	}
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		fmt.Fprintf(os.Stderr, "[NurseAndrea] request error: %v\n", err)
		return fmt.Errorf("nurseandrea: request error: %w", err)
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	resp, err := c.httpClient.Do(req)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[NurseAndrea] POST %s failed: %v\n", url, err)
		return fmt.Errorf("nurseandrea: http error: %w", err)
	}
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(resp.Body)
	c.HandleResponse(resp.StatusCode, respBody, url)
	return nil
}

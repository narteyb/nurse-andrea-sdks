package nurseandrea

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"
)

// LogEntry represents a single log event to ship.
type LogEntry struct {
	Level       string                 `json:"level"`
	Message     string                 `json:"message"`
	Timestamp   string                 `json:"timestamp"`
	Service     string                 `json:"service"`
	SDKVersion  string                 `json:"sdk_version"`
	SDKLanguage string                 `json:"sdk_language"`
	Metadata    map[string]interface{} `json:"metadata,omitempty"`
}

// MetricEntry represents a single metric data point.
type MetricEntry struct {
	Name        string            `json:"name"`
	Value       float64           `json:"value"`
	Unit        string            `json:"unit"`
	Timestamp   string            `json:"timestamp"`
	SDKVersion  string            `json:"sdk_version"`
	SDKLanguage string            `json:"sdk_language"`
	Tags        map[string]string `json:"tags"`
}

// Client manages batching and flushing of telemetry data.
type Client struct {
	mu          sync.Mutex
	logQueue    []LogEntry
	metricQueue []MetricEntry
	stopCh      chan struct{}
	stopped     bool
	httpClient  *http.Client
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

func (c *Client) flushLoop() {
	cfg := GetConfig()
	ticker := time.NewTicker(time.Duration(cfg.FlushIntervalMs) * time.Millisecond)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			c.flush()
		case <-c.stopCh:
			return
		}
	}
}

// EnqueueLog adds a log entry to the outbound queue.
func (c *Client) EnqueueLog(level, message string, metadata map[string]interface{}) {
	if !IsEnabled() {
		return
	}
	cfg := GetConfig()
	entry := LogEntry{
		Level:       level,
		Message:     message,
		Timestamp:   time.Now().UTC().Format(time.RFC3339Nano),
		Service:     cfg.ServiceName,
		SDKVersion:  Version,
		SDKLanguage: "go",
		Metadata:    metadata,
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
		Name:        name,
		Value:       value,
		Unit:        unit,
		Timestamp:   time.Now().UTC().Format(time.RFC3339Nano),
		SDKVersion:  Version,
		SDKLanguage: "go",
		Tags:        tags,
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

	cfg := GetConfig()
	headers := map[string]string{
		"Content-Type":  "application/json",
		"Authorization": "Bearer " + cfg.Token,
	}

	if len(logs) > 0 {
		payload := map[string]interface{}{"logs": logs}
		if err := c.post(IngestURL(), headers, payload); err != nil {
			c.mu.Lock()
			c.logQueue = append(logs, c.logQueue...)
			c.mu.Unlock()
		}
	}

	if len(metrics) > 0 {
		payload := map[string]interface{}{"metrics": metrics}
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
		return fmt.Errorf("nurseandrea: marshal error: %w", err)
	}
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("nurseandrea: request error: %w", err)
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("nurseandrea: http error: %w", err)
	}
	defer resp.Body.Close()
	return nil
}

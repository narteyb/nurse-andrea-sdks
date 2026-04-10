package tracing

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea"
)

const (
	batchSize     = 100
	flushInterval = 5 * time.Second
)

type OTLPSpan struct {
	TraceID            string          `json:"traceId"`
	SpanID             string          `json:"spanId"`
	ParentSpanID       string          `json:"parentSpanId"`
	Name               string          `json:"name"`
	Kind               int             `json:"kind"`
	StartTimeUnixNano  string          `json:"startTimeUnixNano"`
	EndTimeUnixNano    string          `json:"endTimeUnixNano"`
	Status             OTLPStatus      `json:"status"`
	Attributes         []OTLPAttribute `json:"attributes"`
	Events             []interface{}   `json:"events"`
}

type OTLPStatus struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

type OTLPAttribute struct {
	Key   string                 `json:"key"`
	Value map[string]interface{} `json:"value"`
}

var (
	mu      sync.Mutex
	queue   []OTLPSpan
	started bool
	stopCh  chan struct{}
)

func GenerateTraceID() string {
	b := make([]byte, 16)
	rand.Read(b)
	return hex.EncodeToString(b)
}

func GenerateSpanID() string {
	b := make([]byte, 8)
	rand.Read(b)
	return hex.EncodeToString(b)
}

func EnqueueSpan(span OTLPSpan) {
	if !nurseandrea.IsEnabled() {
		return
	}
	mu.Lock()
	queue = append(queue, span)
	shouldFlush := len(queue) >= batchSize
	mu.Unlock()
	if shouldFlush {
		go flush()
	}
}

func init() {
	nurseandrea.SetTracingStartFunc(Start)
}

func Start() {
	if started {
		return
	}
	started = true
	stopCh = make(chan struct{})
	go flushLoop()
}

func Stop() {
	if !started {
		return
	}
	close(stopCh)
	flush()
}

func flushLoop() {
	ticker := time.NewTicker(flushInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			flush()
		case <-stopCh:
			return
		}
	}
}

func flush() {
	mu.Lock()
	if len(queue) == 0 {
		mu.Unlock()
		return
	}
	spans := make([]OTLPSpan, len(queue))
	copy(spans, queue)
	queue = queue[:0]
	mu.Unlock()

	cfg := nurseandrea.GetConfig()
	payload := map[string]interface{}{
		"resourceSpans": []map[string]interface{}{{
			"resource": map[string]interface{}{
				"attributes": []map[string]interface{}{
					{"key": "service.name", "value": map[string]string{"stringValue": cfg.ServiceName}},
				},
			},
			"scopeSpans": []map[string]interface{}{
				{"spans": spans},
			},
		}},
	}

	body, err := json.Marshal(payload)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[NurseAndrea] Trace marshal error: %v\n", err)
		return
	}

	url := cfg.Host + "/api/v1/traces"
	req, err := http.NewRequest("POST", url, bytes.NewReader(body))
	if err != nil {
		fmt.Fprintf(os.Stderr, "[NurseAndrea] Trace request error: %v\n", err)
		return
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+cfg.Token)

	resp, err := (&http.Client{Timeout: 5 * time.Second}).Do(req)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[NurseAndrea] Trace export failed: %v\n", err)
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		fmt.Fprintf(os.Stderr, "[NurseAndrea] Trace export → %d\n", resp.StatusCode)
	}
}

// MakeServerSpan builds an OTLP span for an HTTP server request.
func MakeServerSpan(method, path string, statusCode int, startNs, endNs int64, serviceName string) OTLPSpan {
	code := 1
	msg := ""
	if statusCode >= 500 {
		code = 2
		msg = fmt.Sprintf("HTTP %d", statusCode)
	}
	return OTLPSpan{
		TraceID:           GenerateTraceID(),
		SpanID:            GenerateSpanID(),
		ParentSpanID:      "",
		Name:              fmt.Sprintf("%s %s", method, path),
		Kind:              2,
		StartTimeUnixNano: fmt.Sprintf("%d", startNs),
		EndTimeUnixNano:   fmt.Sprintf("%d", endNs),
		Status:            OTLPStatus{Code: code, Message: msg},
		Attributes: []OTLPAttribute{
			{Key: "http.method", Value: map[string]interface{}{"stringValue": method}},
			{Key: "http.url", Value: map[string]interface{}{"stringValue": path}},
			{Key: "http.status_code", Value: map[string]interface{}{"intValue": statusCode}},
		},
		Events: []interface{}{},
	}
}

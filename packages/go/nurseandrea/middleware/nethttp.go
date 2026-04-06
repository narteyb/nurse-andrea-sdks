package middleware

import (
	"fmt"
	"net/http"
	"time"

	"github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea"
)

// NetHTTP returns a standard library middleware that records HTTP metrics.
//
// Usage:
//
//	mux := http.NewServeMux()
//	mux.HandleFunc("/", handler)
//	http.ListenAndServe(":8080", middleware.NetHTTP(mux))
func NetHTTP(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !nurseandrea.IsEnabled() {
			next.ServeHTTP(w, r)
			return
		}

		startedAt := time.Now()
		rw := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}
		next.ServeHTTP(rw, r)
		durationMs := float64(time.Since(startedAt).Milliseconds())

		nurseandrea.GetClient().EnqueueMetric(
			"http.server.duration",
			durationMs,
			"ms",
			map[string]string{
				"http_method": r.Method,
				"http_path":   r.URL.Path,
				"http_status": fmt.Sprintf("%d", rw.statusCode),
			},
		)

		if rw.statusCode >= 400 {
			level := "warn"
			if rw.statusCode >= 500 {
				level = "error"
			}
			nurseandrea.GetClient().EnqueueLog(level,
				fmt.Sprintf("%s %s → %d (%.1fms)", r.Method, r.URL.Path, rw.statusCode, durationMs),
				map[string]interface{}{
					"http_method": r.Method,
					"http_path":   r.URL.Path,
					"http_status": rw.statusCode,
					"duration_ms": durationMs,
				},
			)
		}
	})
}

type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

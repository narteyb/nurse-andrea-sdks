package middleware

import (
	"fmt"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea"
	"github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea/tracing"
)

// Gin returns a Gin middleware that records HTTP metrics.
//
// Usage:
//
//	r := gin.Default()
//	r.Use(middleware.Gin())
func Gin() gin.HandlerFunc {
	return func(c *gin.Context) {
		if !nurseandrea.IsEnabled() {
			c.Next()
			return
		}

		startedAt := time.Now()
		startNs := startedAt.UnixNano()
		c.Next()
		endNs := time.Now().UnixNano()
		durationMs := float64(time.Since(startedAt).Milliseconds())

		// Use matched route pattern, not raw URL
		route := c.FullPath()
		if route == "" {
			route = c.Request.URL.Path
		}

		nurseandrea.GetClient().EnqueueMetric(
			"http.server.duration",
			durationMs,
			"ms",
			map[string]string{
				"http_method": c.Request.Method,
				"http_path":   route,
				"http_status": fmt.Sprintf("%d", c.Writer.Status()),
			},
		)

		if c.Writer.Status() >= 400 {
			level := "warn"
			if c.Writer.Status() >= 500 {
				level = "error"
			}
			nurseandrea.GetClient().EnqueueLog(level,
				fmt.Sprintf("%s %s → %d (%.1fms)",
					c.Request.Method, route, c.Writer.Status(), durationMs),
				map[string]interface{}{
					"http_method": c.Request.Method,
					"http_path":   route,
					"http_status": c.Writer.Status(),
					"duration_ms": durationMs,
				},
			)
		}

		tracing.EnqueueSpan(tracing.MakeServerSpan(c.Request.Method, route, c.Writer.Status(), startNs, endNs, nurseandrea.GetConfig().ServiceName))
	}
}

package middleware

import (
	"fmt"
	"time"

	"github.com/labstack/echo/v4"
	"github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea"
	"github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea/tracing"
)

// Echo returns an Echo middleware that records HTTP metrics.
//
// Usage:
//
//	e := echo.New()
//	e.Use(middleware.Echo())
func Echo() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			if !nurseandrea.IsEnabled() {
				return next(c)
			}

			startedAt := time.Now()
			startNs := startedAt.UnixNano()
			err := next(c)
			endNs := time.Now().UnixNano()
			durationMs := float64(time.Since(startedAt).Milliseconds())

			// Use matched route pattern
			route := c.Path()
			if route == "" {
				route = c.Request().URL.Path
			}

			status := c.Response().Status

			nurseandrea.GetClient().EnqueueMetric(
				"http.server.duration",
				durationMs,
				"ms",
				map[string]string{
					"http_method": c.Request().Method,
					"http_path":   route,
					"http_status": fmt.Sprintf("%d", status),
				},
			)

			if status >= 400 {
				level := "warn"
				if status >= 500 {
					level = "error"
				}
				nurseandrea.GetClient().EnqueueLog(level,
					fmt.Sprintf("%s %s → %d (%.1fms)",
						c.Request().Method, route, status, durationMs),
					map[string]interface{}{
						"http_method": c.Request().Method,
						"http_path":   route,
						"http_status": status,
						"duration_ms": durationMs,
					},
				)
			}

			tracing.EnqueueSpan(tracing.MakeServerSpan(c.Request().Method, route, status, startNs, endNs, nurseandrea.GetConfig().ServiceName))

			return err
		}
	}
}

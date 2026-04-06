package interceptors

import (
	"context"
	"log/slog"

	"github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea"
)

// SlogHandler wraps an existing slog.Handler and forwards records
// to NurseAndrea in addition to the original handler.
//
// Usage:
//
//	base := slog.NewJSONHandler(os.Stdout, nil)
//	logger := slog.New(interceptors.NewSlogHandler(base))
//	slog.SetDefault(logger)
type SlogHandler struct {
	wrapped slog.Handler
}

// NewSlogHandler creates a new SlogHandler wrapping the provided handler.
func NewSlogHandler(wrapped slog.Handler) *SlogHandler {
	return &SlogHandler{wrapped: wrapped}
}

// Enabled reports whether the handler handles records at the given level.
func (h *SlogHandler) Enabled(ctx context.Context, level slog.Level) bool {
	return h.wrapped.Enabled(ctx, level)
}

// Handle handles the Record, forwarding to both NurseAndrea and the wrapped handler.
func (h *SlogHandler) Handle(ctx context.Context, r slog.Record) error {
	if nurseandrea.IsEnabled() {
		level := slogLevelToString(r.Level)
		metadata := make(map[string]interface{})
		r.Attrs(func(a slog.Attr) bool {
			metadata[a.Key] = a.Value.Any()
			return true
		})
		nurseandrea.GetClient().EnqueueLog(level, r.Message, metadata)
	}
	return h.wrapped.Handle(ctx, r)
}

// WithAttrs returns a new SlogHandler with the given attributes.
func (h *SlogHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	return &SlogHandler{wrapped: h.wrapped.WithAttrs(attrs)}
}

// WithGroup returns a new SlogHandler with the given group name.
func (h *SlogHandler) WithGroup(name string) slog.Handler {
	return &SlogHandler{wrapped: h.wrapped.WithGroup(name)}
}

func slogLevelToString(level slog.Level) string {
	switch {
	case level >= slog.LevelError:
		return "error"
	case level >= slog.LevelWarn:
		return "warn"
	case level >= slog.LevelInfo:
		return "info"
	default:
		return "debug"
	}
}

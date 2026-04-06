package interceptors

import (
	"github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

// ZapCore wraps a zapcore.Core and forwards log entries to NurseAndrea.
//
// Usage:
//
//	base, _ := zap.NewProduction()
//	core := interceptors.NewZapCore(base.Core())
//	logger := zap.New(core)
type ZapCore struct {
	zapcore.Core
}

// Ensure ZapCore uses zap (suppress unused import lint).
var _ = zap.NewNop

// NewZapCore wraps an existing zapcore.Core.
func NewZapCore(core zapcore.Core) *ZapCore {
	return &ZapCore{Core: core}
}

// With adds structured context to the Core.
func (c *ZapCore) With(fields []zapcore.Field) zapcore.Core {
	return &ZapCore{Core: c.Core.With(fields)}
}

// Check determines whether the supplied Entry should be logged.
func (c *ZapCore) Check(entry zapcore.Entry, ce *zapcore.CheckedEntry) *zapcore.CheckedEntry {
	if c.Enabled(entry.Level) {
		ce = ce.AddCore(entry, c)
	}
	return ce
}

// Write serializes the Entry and any Fields, forwarding to both NurseAndrea and the wrapped core.
func (c *ZapCore) Write(entry zapcore.Entry, fields []zapcore.Field) error {
	if nurseandrea.IsEnabled() {
		metadata := make(map[string]interface{}, len(fields))
		for _, f := range fields {
			metadata[f.Key] = fieldValue(f)
		}
		nurseandrea.GetClient().EnqueueLog(
			zapLevelToString(entry.Level),
			entry.Message,
			metadata,
		)
	}
	return c.Core.Write(entry, fields)
}

func zapLevelToString(level zapcore.Level) string {
	switch level {
	case zapcore.ErrorLevel, zapcore.DPanicLevel, zapcore.PanicLevel, zapcore.FatalLevel:
		return "error"
	case zapcore.WarnLevel:
		return "warn"
	case zapcore.InfoLevel:
		return "info"
	default:
		return "debug"
	}
}

func fieldValue(f zapcore.Field) interface{} {
	switch f.Type {
	case zapcore.StringType:
		return f.String
	case zapcore.Int64Type, zapcore.Int32Type, zapcore.Int16Type, zapcore.Int8Type:
		return f.Integer
	case zapcore.Float64Type, zapcore.Float32Type:
		return f.Integer // stored as bits
	case zapcore.BoolType:
		return f.Integer == 1
	default:
		if f.Interface != nil {
			return f.Interface
		}
		return f.String
	}
}

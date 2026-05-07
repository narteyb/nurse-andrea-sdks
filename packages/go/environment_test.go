package nurseandrea_test

import (
	"bytes"
	"io"
	"os"
	"strings"
	"testing"

	"github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea"
)

func captureStderr(t *testing.T, fn func()) string {
	t.Helper()
	old := os.Stderr
	r, w, err := os.Pipe()
	if err != nil {
		t.Fatalf("pipe: %v", err)
	}
	os.Stderr = w

	done := make(chan struct{})
	var buf bytes.Buffer
	go func() {
		_, _ = io.Copy(&buf, r)
		close(done)
	}()

	fn()

	w.Close()
	os.Stderr = old
	<-done
	return buf.String()
}

func TestDetectEnvironmentDefault(t *testing.T) {
	resetConfig()
	if got := nurseandrea.DetectEnvironment(); got != "production" {
		t.Errorf("expected 'production' default, got %q", got)
	}
}

func TestDetectEnvironmentSupportedValues(t *testing.T) {
	for _, v := range []string{"production", "staging", "development"} {
		t.Run(v, func(t *testing.T) {
			resetConfig()
			os.Setenv("GO_ENV", v)
			defer os.Unsetenv("GO_ENV")
			if got := nurseandrea.DetectEnvironment(); got != v {
				t.Errorf("expected %q, got %q", v, got)
			}
		})
	}
}

func TestDetectEnvironmentFallsBackForUnsupported(t *testing.T) {
	resetConfig()
	os.Setenv("GO_ENV", "test")
	defer os.Unsetenv("GO_ENV")
	if got := nurseandrea.DetectEnvironment(); got != "production" {
		t.Errorf("expected 'production' fallback, got %q", got)
	}
}

func TestDetectEnvironmentWarnsOnceForUnsupported(t *testing.T) {
	resetConfig()
	nurseandrea.ResetEnvWarningForTests()
	os.Setenv("GO_ENV", "qa")
	defer os.Unsetenv("GO_ENV")

	output := captureStderr(t, func() {
		_ = nurseandrea.DetectEnvironment()
		_ = nurseandrea.DetectEnvironment()
		_ = nurseandrea.DetectEnvironment()
	})
	count := strings.Count(output, "[NurseAndrea]")
	if count != 1 {
		t.Errorf("expected exactly 1 warning, got %d (output=%q)", count, output)
	}
}

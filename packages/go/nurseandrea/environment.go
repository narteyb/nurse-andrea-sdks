package nurseandrea

import (
	"fmt"
	"os"
	"sync"
)

// SupportedEnvironments lists the only values accepted by the NA ingest endpoint.
var SupportedEnvironments = []string{"production", "staging", "development"}

var (
	envWarnMu sync.Mutex
	envWarned bool
)

// DetectEnvironment reads GO_ENV / APP_ENV and falls back to "production" when
// unset or unsupported. Unsupported values produce a one-time stderr warning.
func DetectEnvironment() string {
	raw := firstNonEmpty(os.Getenv("GO_ENV"), os.Getenv("APP_ENV"))
	if raw == "" {
		return "production"
	}
	if isSupportedEnvironment(raw) {
		return raw
	}
	warnUnsupportedEnvironment(raw)
	return "production"
}

func isSupportedEnvironment(value string) bool {
	for _, e := range SupportedEnvironments {
		if e == value {
			return true
		}
	}
	return false
}

func warnUnsupportedEnvironment(value string) {
	envWarnMu.Lock()
	defer envWarnMu.Unlock()
	if envWarned {
		return
	}
	envWarned = true
	fmt.Fprintf(os.Stderr,
		"[NurseAndrea] Detected environment %q is not in the supported set %v. "+
			"Falling back to 'production'.\n",
		value, SupportedEnvironments)
}

// ResetEnvWarningForTests resets the one-shot warning latch. Test-only.
func ResetEnvWarningForTests() {
	envWarnMu.Lock()
	defer envWarnMu.Unlock()
	envWarned = false
}

// resetEnvWarningForTests is the package-internal alias used by resetForTests.
func resetEnvWarningForTests() { ResetEnvWarningForTests() }

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

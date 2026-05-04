// Package nurseandrea provides observability instrumentation for Go applications.
// Ship logs and HTTP metrics to NurseAndrea with a single configuration call.
package nurseandrea

// Version is the current SDK version.
// Included in all outbound payloads as sdk_version.
const Version = "0.2.1"

// Shutdown flushes all pending data and stops background goroutines.
// Call on application shutdown:
//
//	defer nurseandrea.Shutdown()
func Shutdown() {
	GetClient().Stop()
}

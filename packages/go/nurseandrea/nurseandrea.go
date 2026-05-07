// Package nurseandrea provides observability instrumentation for Go applications.
// Ship logs and HTTP metrics to NurseAndrea with a single configuration call.
package nurseandrea

// Shutdown flushes all pending data and stops background goroutines.
// Call on application shutdown:
//
//	defer nurseandrea.Shutdown()
func Shutdown() {
	GetClient().Stop()
}

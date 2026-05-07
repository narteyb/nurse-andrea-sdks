package nurseandrea

import "errors"

// ErrConfiguration is returned for any configuration-time validation failure.
// MigrationError unwraps to ErrConfiguration so callers can match either.
var ErrConfiguration = errors.New("nurseandrea: configuration error")

// ConfigurationError is the structured error type for configuration issues.
type ConfigurationError struct {
	Message string
}

func (e *ConfigurationError) Error() string { return e.Message }
func (e *ConfigurationError) Unwrap() error { return ErrConfiguration }

// MigrationError signals that a caller is using a legacy config field
// (e.g., APIKey, Token, IngestToken) that was removed in 1.0.
type MigrationError struct {
	Field   string
	Message string
}

func (e *MigrationError) Error() string { return e.Message }
func (e *MigrationError) Unwrap() error { return ErrConfiguration }

func newMigrationError(field string) *MigrationError {
	return &MigrationError{
		Field: field,
		Message: field + " is no longer supported in NurseAndrea SDK 1.0. " +
			"Migrate to OrgToken + WorkspaceSlug + Environment. " +
			"See https://docs.nurseandrea.io/sdk/migration",
	}
}

package nurseandrea

import "regexp"

var slugPattern = regexp.MustCompile(`^[a-z][a-z0-9\-]{0,63}$`)

// SlugRulesHuman is the human-readable explanation of the slug format.
const SlugRulesHuman = "Workspace slugs must be lowercase letters, numbers, or hyphens. " +
	"Must start with a letter. 1-64 characters."

// IsValidSlug returns true when the input is a syntactically valid workspace slug.
// Reserved-word enforcement remains server-side; this is a local format check only.
func IsValidSlug(slug string) bool {
	if slug == "" {
		return false
	}
	return slugPattern.MatchString(slug)
}

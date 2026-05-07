package nurseandrea_test

import (
	"strings"
	"testing"

	"github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea"
)

func TestIsValidSlug(t *testing.T) {
	cases := []struct {
		slug    string
		isValid bool
	}{
		{"a", true},
		{"checkout-2", true},
		{"a1-b2-c3", true},
		{"a" + strings.Repeat("b", 63), true},
		{"", false},
		{"1-checkout", false},
		{"-checkout", false},
		{"Checkout", false},
		{"check_out", false},
		{"check.out", false},
		{"check out", false},
		{"a" + strings.Repeat("b", 64), false},
	}
	for _, tc := range cases {
		t.Run(tc.slug, func(t *testing.T) {
			if got := nurseandrea.IsValidSlug(tc.slug); got != tc.isValid {
				t.Errorf("IsValidSlug(%q) = %v, want %v", tc.slug, got, tc.isValid)
			}
		})
	}
}

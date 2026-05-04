package agent

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestValidateUsername_AcceptsSimple(t *testing.T) {
	require.NoError(t, validateUsername("furkan"))
	require.NoError(t, validateUsername("furkan_b"))
	require.NoError(t, validateUsername("a1b2c3"))
	require.NoError(t, validateUsername("dev-2026"))
}

func TestValidateUsername_RejectsTooShort(t *testing.T) {
	err := validateUsername("ab")
	require.ErrorIs(t, err, ErrUsernameFormat)
}

func TestValidateUsername_RejectsTooLong(t *testing.T) {
	err := validateUsername(strings.Repeat("a", 33))
	require.ErrorIs(t, err, ErrUsernameFormat)
}

func TestValidateUsername_RejectsLeadingDigit(t *testing.T) {
	// "must start with a letter" — guards against handles like "123" that
	// look like internal IDs in URLs.
	err := validateUsername("1337coder")
	require.ErrorIs(t, err, ErrUsernameFormat)
}

func TestValidateUsername_NormalisesUppercase(t *testing.T) {
	// validateUsername lowercases its input before format-checking so users
	// entering mixed-case handles get a consistent uniqueness key — "Furkan"
	// and "furkan" can't both exist as separate accounts. The DB-layer
	// uniqueness check (LOWER(username)) is what actually enforces this.
	require.NoError(t, validateUsername("Furkan"))
	require.NoError(t, validateUsername("MyUser_42"))
}

func TestValidateUsername_RejectsSpecialChars(t *testing.T) {
	for _, raw := range []string{"a b", "a.b", "a@b", "a/b", "a!b"} {
		err := validateUsername(raw)
		require.ErrorIs(t, err, ErrUsernameFormat, "input %q must be rejected", raw)
	}
}

func TestValidateUsername_RejectsReserved(t *testing.T) {
	for _, raw := range []string{"admin", "ADMIN", "api", "system", "guild", "legend", "support"} {
		err := validateUsername(raw)
		require.ErrorIs(t, err, ErrUsernameReserved, "input %q must be reserved", raw)
	}
}

func TestSuggestAlternativeUsernames_ReturnsValidCandidates(t *testing.T) {
	got := SuggestAlternativeUsernames("wizard")
	require.NotEmpty(t, got)
	for _, c := range got {
		require.NoError(t, validateUsername(c), "suggestion %q must itself validate", c)
	}
}

func TestSuggestAlternativeUsernames_StripsTrailingNoise(t *testing.T) {
	// Suggestions should derive from a clean base — no trailing punctuation
	// or whitespace in the seed.
	got := SuggestAlternativeUsernames("wizard__-")
	require.NotEmpty(t, got)
	for _, c := range got {
		assert.True(t, strings.HasPrefix(c, "wizard"), "suggestion %q must start with cleaned base", c)
	}
}

func TestSuggestAlternativeUsernames_EmptyInputReturnsNil(t *testing.T) {
	assert.Nil(t, SuggestAlternativeUsernames(""))
	assert.Nil(t, SuggestAlternativeUsernames("   "))
}

package agent

import (
	"errors"
	"fmt"
	"regexp"
	"strings"
)

// ErrUsernameTaken is returned when a wallet attempts to claim a username that
// is already taken by another wallet (case-insensitive comparison).
var ErrUsernameTaken = errors.New("username already taken")

// ErrUsernameReserved is returned when a wallet attempts to claim a username
// from the reserved-keyword list (admin, api, store, etc.).
var ErrUsernameReserved = errors.New("username is reserved")

// ErrUsernameFormat is returned when the username doesn't match the allowed
// character set or length constraints.
var ErrUsernameFormat = errors.New("username must be 3-32 chars, [a-z0-9_-], starting with a letter")

// usernameFormat matches our acceptable username shape:
// 3-32 characters, lowercase alphanumerics + underscore + hyphen,
// must start with a letter (avoids all-digit handles like "1337" that look
// like internal IDs).
var usernameFormat = regexp.MustCompile(`^[a-z][a-z0-9_-]{2,31}$`)

// reservedUsernames are blocked because they collide with system routes,
// product surface area, or moderation requirements. Stored lowercase; the
// validator lowercases incoming input before lookup.
var reservedUsernames = map[string]struct{}{
	"admin":      {},
	"api":        {},
	"agentstore": {},
	"anonymous":  {},
	"auth":       {},
	"claude":     {},
	"creator":    {},
	"developer":  {},
	"docs":       {},
	"guild":      {},
	"guildmaster": {},
	"help":       {},
	"leaderboard": {},
	"legend":     {},
	"library":    {},
	"login":      {},
	"mission":    {},
	"missions":   {},
	"monad":      {},
	"official":   {},
	"owner":      {},
	"profile":    {},
	"public":     {},
	"root":       {},
	"settings":   {},
	"signup":     {},
	"staff":      {},
	"store":      {},
	"support":    {},
	"system":     {},
	"team":       {},
	"user":       {},
	"wallet":     {},
}

// validateUsername returns nil if the provided username is well-formed and not
// reserved. Comparisons are case-insensitive; callers should still persist the
// original casing the user supplied (after trimming).
func validateUsername(raw string) error {
	name := strings.ToLower(strings.TrimSpace(raw))
	if !usernameFormat.MatchString(name) {
		return ErrUsernameFormat
	}
	if _, ok := reservedUsernames[name]; ok {
		return ErrUsernameReserved
	}
	return nil
}

// SuggestAlternativeUsernames returns up to 3 candidate alternatives derived
// from the requested handle. Used by the API when responding to 409 conflicts
// so the UI can hint the user toward a valid choice. Suggestions are NOT
// guaranteed to be free — the client must re-submit and accept another 409.
func SuggestAlternativeUsernames(requested string) []string {
	base := strings.ToLower(strings.TrimSpace(requested))
	if base == "" {
		return nil
	}
	// Strip non-alphanumeric tail to keep suggestions clean (e.g. "wizard__-" → "wizard").
	for len(base) > 0 {
		last := base[len(base)-1]
		if (last >= 'a' && last <= 'z') || (last >= '0' && last <= '9') {
			break
		}
		base = base[:len(base)-1]
	}
	if base == "" {
		return nil
	}
	candidates := []string{
		fmt.Sprintf("%s_1", base),
		fmt.Sprintf("%s_dev", base),
		fmt.Sprintf("%s_x", base),
	}
	out := make([]string, 0, len(candidates))
	for _, c := range candidates {
		if validateUsername(c) == nil {
			out = append(out, c)
		}
	}
	return out
}

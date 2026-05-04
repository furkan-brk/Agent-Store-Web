package agent

// api_keys.go — developer-facing API key issuance.
//
// Plaintext key shape: "agst_" + 32 hex chars (16 bytes from crypto/rand).
// Prefix is "agst_" + first 8 hex chars of the random suffix and is what we
// expose on list endpoints; KeyHash is bcrypt of the *full* plaintext and is
// never returned to the client.

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"slices"
	"sort"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// apiKeyPrefix is the literal namespace tag baked into every issued key.
const apiKeyPrefix = "agst_"

// allowedAPIKeyScopes is the closed set of permissions a key may carry.
// Adding a new scope here requires both UI and middleware (when enforcement
// lands in v3.11.3) to pick it up; keep this slice small and stable.
var allowedAPIKeyScopes = []string{
	"read:agents",
	"write:agents",
	"execute:legend",
}

// apiKeyBcryptCost is the work factor used by CreateKey. Default cost is fine
// for production (~60ms hash) but slow in tests; tests override via
// SetAPIKeyBcryptCostForTest below.
var apiKeyBcryptCost = bcrypt.DefaultCost

// SetAPIKeyBcryptCostForTest lowers the bcrypt cost factor inside test code.
// Production callers must never invoke this.
func SetAPIKeyBcryptCostForTest(cost int) (restore func()) {
	prev := apiKeyBcryptCost
	apiKeyBcryptCost = cost
	return func() { apiKeyBcryptCost = prev }
}

// Errors surfaced by the API-key service.
var (
	ErrInvalidScope    = errors.New("invalid api key scope")
	ErrAPIKeyNotFound  = errors.New("api key not found")
	ErrAPIKeyAlreadyRevoked = errors.New("api key already revoked")
)

// validateScopes returns nil only when every entry is in allowedAPIKeyScopes.
// Empty slice is allowed — represents a no-permission key (effectively a
// stub), useful for testing the issuance flow.
func validateScopes(scopes []string) error {
	for _, s := range scopes {
		if !slices.Contains(allowedAPIKeyScopes, s) {
			return fmt.Errorf("%w: %q (allowed: %s)",
				ErrInvalidScope, s, strings.Join(allowedAPIKeyScopes, ", "))
		}
	}
	return nil
}

// dedupeScopes returns a sorted, dedup'd copy of in.
func dedupeScopes(in []string) []string {
	seen := map[string]bool{}
	out := make([]string, 0, len(in))
	for _, s := range in {
		s = strings.TrimSpace(s)
		if s == "" || seen[s] {
			continue
		}
		seen[s] = true
		out = append(out, s)
	}
	sort.Strings(out)
	return out
}

// generateAPIKey returns the plaintext key, the display prefix, and the bcrypt
// hash. Plaintext is never persisted by this package — callers store only
// hash + prefix.
func generateAPIKey() (plaintext, prefix, hash string, err error) {
	buf := make([]byte, 16) // 32 hex chars
	if _, err = rand.Read(buf); err != nil {
		return "", "", "", fmt.Errorf("rand: %w", err)
	}
	hexStr := hex.EncodeToString(buf)
	plaintext = apiKeyPrefix + hexStr
	prefix = apiKeyPrefix + hexStr[:8]
	h, err := bcrypt.GenerateFromPassword([]byte(plaintext), apiKeyBcryptCost)
	if err != nil {
		return "", "", "", fmt.Errorf("bcrypt: %w", err)
	}
	hash = string(h)
	return plaintext, prefix, hash, nil
}

// CreateKey issues a fresh API key bound to the wallet and returns the
// plaintext (visible to the caller exactly once) along with the persisted row.
//
// Validation:
//   - wallet must be non-empty
//   - name is trimmed; empty after trim is allowed (default-named key)
//   - every entry in scopes must be in allowedAPIKeyScopes
//
// The persisted row never contains the plaintext.
func (s *AgentService) CreateKey(wallet, name string, scopes []string) (string, *models.APIKey, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return "", nil, fmt.Errorf("wallet required")
	}
	if len(name) > 100 {
		return "", nil, fmt.Errorf("name too long (max 100)")
	}
	scopes = dedupeScopes(scopes)
	if err := validateScopes(scopes); err != nil {
		return "", nil, err
	}
	plaintext, prefix, hash, err := generateAPIKey()
	if err != nil {
		return "", nil, err
	}
	row := models.APIKey{
		Wallet:  wallet,
		Name:    strings.TrimSpace(name),
		KeyHash: hash,
		Prefix:  prefix,
		Scopes:  strings.Join(scopes, ","),
	}
	if err := database.DB.Create(&row).Error; err != nil {
		return "", nil, fmt.Errorf("persist api key: %w", err)
	}
	return plaintext, &row, nil
}

// ListKeys returns the wallet's keys with KeyHash zeroed so the bcrypt hash
// never leaks across the wire. Revoked keys are included so the UI can render
// the "(revoked)" tombstone.
func (s *AgentService) ListKeys(wallet string) ([]models.APIKey, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return nil, fmt.Errorf("wallet required")
	}
	var rows []models.APIKey
	if err := database.DB.
		Where("wallet = ?", wallet).
		Order("created_at DESC").
		Find(&rows).Error; err != nil {
		return nil, err
	}
	// Defensive: zero out the hash even though `json:"-"` already prevents
	// serialisation. Anyone using the slice directly (tests, internal callers)
	// gets the masked value too.
	for i := range rows {
		rows[i].KeyHash = ""
	}
	return rows, nil
}

// RevokeKey tombstones a key by setting RevokedAt. Wallet-scoped: a foreign
// wallet attempting to revoke yields ErrAPIKeyNotFound.
func (s *AgentService) RevokeKey(wallet string, id uint) error {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return fmt.Errorf("wallet required")
	}
	var row models.APIKey
	err := database.DB.
		Where("id = ? AND wallet = ?", id, wallet).
		First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return ErrAPIKeyNotFound
	}
	if err != nil {
		return err
	}
	if row.RevokedAt != nil {
		return ErrAPIKeyAlreadyRevoked
	}
	now := time.Now()
	return database.DB.Model(&row).Update("revoked_at", &now).Error
}

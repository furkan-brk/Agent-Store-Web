// Package middleware exposes Gin handlers shared across services.
//
// api_key_auth.go validates developer-issued API keys (created via the v3.11.2
// /user/api-keys endpoints) and enforces per-route scope requirements. JWT
// auth (via the gateway's X-Wallet-Address header) takes precedence — if a
// request already carries a verified wallet header, the API key check is
// skipped so internal microservice traffic isn't impacted.
package middleware

import (
	"errors"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// apiKeyNamespacePrefix mirrors the constant in services/agent/api_keys.go.
// Duplicated here to keep middleware free of the agent package import (which
// would create a circular dependency: agent → middleware → agent).
const apiKeyNamespacePrefix = "agst_"

// apiKeyDisplayPrefixLen is the length of the prefix slice we index on
// (apiKeyNamespacePrefix + first 8 hex chars of the random suffix).
const apiKeyDisplayPrefixLen = 5 + 8 // "agst_" + 8

// extractAPIKey returns the raw key from either header. Empty string when
// neither header is set or when the value doesn't carry the expected namespace
// prefix.
//
// Header precedence: X-API-Key wins over Authorization. This matches the
// pattern most public APIs use — Authorization is reserved for the gateway's
// JWT, X-API-Key is the explicit "I'm using a key" signal.
func extractAPIKey(c *gin.Context) string {
	if v := strings.TrimSpace(c.GetHeader("X-API-Key")); v != "" {
		if strings.HasPrefix(v, apiKeyNamespacePrefix) {
			return v
		}
	}
	if v := strings.TrimSpace(c.GetHeader("Authorization")); v != "" {
		// Accept both "Bearer agst_..." and bare "agst_...". The gateway's JWT
		// uses Bearer too — we only treat the value as an API key when it
		// starts with our namespace prefix.
		if rest, ok := strings.CutPrefix(v, "Bearer "); ok {
			v = strings.TrimSpace(rest)
		}
		if strings.HasPrefix(v, apiKeyNamespacePrefix) {
			return v
		}
	}
	return ""
}

// hasScope returns true if the requested scope is present in the comma-
// separated CSV. Empty `requested` means "any authenticated key passes".
func hasScope(scopesCSV, requested string) bool {
	if requested == "" {
		return true
	}
	for _, s := range strings.Split(scopesCSV, ",") {
		if strings.TrimSpace(s) == requested {
			return true
		}
	}
	return false
}

// lookupAPIKey verifies the plaintext against a non-revoked APIKey row.
//
// Strategy:
//  1. derive the display prefix (apiKeyNamespacePrefix + first 8 hex chars);
//  2. SELECT all rows with that prefix (typically 1 — collisions are vanishingly
//     rare with 4 bytes of namespace randomness);
//  3. bcrypt-compare each candidate's KeyHash against the plaintext.
//
// Returns the matching row, or an error. ErrKeyNotFound when no row matches;
// ErrKeyRevoked when a match is revoked.
func lookupAPIKey(plaintext string) (*models.APIKey, error) {
	if len(plaintext) < apiKeyDisplayPrefixLen {
		return nil, ErrKeyNotFound
	}
	prefix := plaintext[:apiKeyDisplayPrefixLen]

	var candidates []models.APIKey
	if err := database.DB.
		Where("prefix = ?", prefix).
		Find(&candidates).Error; err != nil {
		return nil, err
	}
	if len(candidates) == 0 {
		return nil, ErrKeyNotFound
	}

	for i := range candidates {
		row := &candidates[i]
		if bcrypt.CompareHashAndPassword([]byte(row.KeyHash), []byte(plaintext)) == nil {
			if row.RevokedAt != nil {
				return nil, ErrKeyRevoked
			}
			return row, nil
		}
	}
	return nil, ErrKeyNotFound
}

// ErrKeyNotFound and ErrKeyRevoked are exported so tests can match them with
// errors.Is. Callers normally don't see them — APIKeyAuth maps them to 401.
var (
	ErrKeyNotFound = errors.New("api key not found")
	ErrKeyRevoked  = errors.New("api key revoked")
)

// APIKeyAuth returns a Gin middleware that authenticates requests via API key
// and enforces requiredScope. When requiredScope is empty, any active key
// passes — useful for read endpoints that don't need scope gating.
//
// On success, c.Set("wallet", ...) and c.Set("auth_method", "api_key") fire
// so downstream handlers behave the same as JWT-authed callers.
//
// LastUsedAt is updated asynchronously in a goroutine — best-effort, errors
// are logged but never block the request.
func APIKeyAuth(requiredScope string) gin.HandlerFunc {
	return func(c *gin.Context) {
		key := extractAPIKey(c)
		if key == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing api key"})
			return
		}
		row, err := lookupAPIKey(key)
		if err != nil {
			if errors.Is(err, ErrKeyRevoked) {
				c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "api key revoked"})
				return
			}
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid api key"})
			return
		}
		if !hasScope(row.Scopes, requiredScope) {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"error":          "missing required scope",
				"required_scope": requiredScope,
			})
			return
		}

		c.Set("wallet", row.Wallet)
		c.Set("auth_method", "api_key")

		// Async LastUsedAt bump. Best-effort — a missed timestamp is recoverable;
		// blocking the request to write it is not. Nil-DB guard mirrors the
		// RecordActivity pattern in services/agent/social.go: t.Cleanup may
		// reset database.DB before the goroutine lands its write.
		go func(id uint) {
			db := database.DB
			if db == nil {
				return
			}
			now := time.Now()
			if err := db.Model(&models.APIKey{}).
				Where("id = ?", id).
				Update("last_used_at", &now).Error; err != nil {
				log.Printf("[apikey] last_used_at update failed for key %d: %v", id, err)
			}
		}(row.ID)

		c.Next()
	}
}

// AuthOrAPIKey lets a route accept either the gateway's JWT-derived wallet
// (preferred) or an API key with the requested scope. Use this on dual-auth
// endpoints during the v3.11.3 pilot rollout.
//
// Behaviour:
//   - If the gin context already carries a "wallet" key (set by JWTExtractor
//     after verifying the Authorization Bearer token), trust it: set
//     auth_method=jwt and pass through.
//   - Otherwise, fall through to APIKeyAuth(requiredScope).
//
// SECURITY (v3.12-P0-1): we used to read c.GetHeader("X-Wallet-Address")
// directly. That was unsafe because an attacker could set the header on
// inbound requests and skip both JWT and API key auth entirely. The fix is
// to trust *only* the gin-context value written by JWTExtractor. The
// StripInboundWalletHeader middleware (mounted at the top of the chain in
// monolith + gateway) deletes any forged inbound header so even code that
// later reads the raw header sees a clean slate.
//
// Both branches abort with 401/403 on failure — the caller never sees a
// half-authed request.
func AuthOrAPIKey(requiredScope string) gin.HandlerFunc {
	apiKeyHandler := APIKeyAuth(requiredScope)
	return func(c *gin.Context) {
		// Only trust the wallet if the JWT-extractor middleware put it into
		// the gin context. Reading the raw header is unsafe — see the
		// SECURITY note above.
		if v, ok := c.Get("wallet"); ok {
			if wallet, ok := v.(string); ok {
				wallet = strings.TrimSpace(wallet)
				if wallet != "" {
					c.Set("wallet", wallet)
					c.Set("auth_method", "jwt")
					c.Next()
					return
				}
			}
		}
		apiKeyHandler(c)
	}
}

// keep gorm import alive even if all error paths above migrate away from it
var _ = gorm.ErrRecordNotFound

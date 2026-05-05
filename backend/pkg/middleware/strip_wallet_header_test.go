// strip_wallet_header_test.go — regression tests for the v3.12-P0-1
// X-Wallet-Address header bypass fix.
//
// The vulnerability: the X-Wallet-Address header is supposed to be an
// internal-only contract written by the gateway/monolith JWT extractor
// after a verified Bearer token. If an external client could send the
// header on inbound requests, every handler that trusts
// c.GetHeader("X-Wallet-Address") would let the attacker impersonate
// any wallet.
//
// The fix: StripInboundWalletHeader() deletes the header on every inbound
// request, before any auth middleware runs. The only paths that can set
// the header thereafter are JWT-derived.
package middleware_test

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/middleware"
	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// buildStrippedAuthChain emulates the production middleware order:
//
//	StripInboundWalletHeader -> (caller-supplied JWT-extractor stub) -> InternalAuth
//
// The stub stands in for gateway.JWTExtractor so we can drive the
// "JWT-set wallet" behavior without dragging the JWT lib into this test.
// jwtWallet is the wallet a *valid* JWT would be parsed to ("" = no JWT).
func buildStrippedAuthChain(jwtWallet string) http.Handler {
	r := gin.New()
	r.Use(middleware.StripInboundWalletHeader())
	r.Use(func(c *gin.Context) {
		// Stub JWT extractor: when jwtWallet is set, behave as if the
		// Bearer token validated to that wallet. Critically, also write
		// the header so InternalAuth (downstream) can read it — this is
		// what monolith/main.go's wallet-injection middleware does.
		if jwtWallet != "" {
			c.Set("wallet", jwtWallet)
			c.Request.Header.Set("X-Wallet-Address", jwtWallet)
		}
		c.Next()
	})
	r.GET("/protected", middleware.InternalAuth(), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"wallet": c.GetString("wallet")})
	})
	return r
}

func TestXWalletHeaderBypass_ForgedHeaderRejected(t *testing.T) {
	// External attacker sends X-Wallet-Address with no JWT. Without the
	// strip middleware, InternalAuth would happily set wallet=0xVictim
	// and let the request through.
	h := buildStrippedAuthChain("")

	req, _ := http.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("X-Wallet-Address", "0xVictim")
	w := httptest.NewRecorder()
	h.ServeHTTP(w, req)

	assert.Equal(t, http.StatusUnauthorized, w.Code,
		"forged X-Wallet-Address header without a JWT must NOT authenticate the request")
	assert.Contains(t, w.Body.String(), "missing wallet header",
		"InternalAuth should report no wallet — the strip middleware deleted the forgery")
}

func TestXWalletHeaderBypass_ForgedHeaderLowercase(t *testing.T) {
	// Defensive: net/http canonicalises but verify case-insensitive strip
	// against an explicitly lowercased header on the wire.
	h := buildStrippedAuthChain("")

	req, _ := http.NewRequest(http.MethodGet, "/protected", nil)
	req.Header["x-wallet-address"] = []string{"0xVictim"} // bypass canonical insert
	w := httptest.NewRecorder()
	h.ServeHTTP(w, req)

	assert.Equal(t, http.StatusUnauthorized, w.Code,
		"lowercase variant of X-Wallet-Address must also be stripped")
}

func TestXWalletHeaderStrippedBeforeJWT(t *testing.T) {
	// Both: the attacker provides a forged X-Wallet-Address AND a valid
	// JWT for a *different* wallet. The JWT-derived wallet must win.
	jwtWallet := "0xJWTOwner"
	h := buildStrippedAuthChain(jwtWallet)

	req, _ := http.NewRequest(http.MethodGet, "/protected", nil)
	// Forge a different wallet — strip middleware deletes it first.
	req.Header.Set("X-Wallet-Address", "0xForgedAttacker")
	w := httptest.NewRecorder()
	h.ServeHTTP(w, req)

	require.Equal(t, http.StatusOK, w.Code,
		"valid JWT path should authenticate")
	assert.Contains(t, w.Body.String(), jwtWallet,
		"JWT-derived wallet must override the forged header")
	assert.NotContains(t, w.Body.String(), "0xForgedAttacker",
		"forged wallet must never reach the handler")
}

func TestStripInboundWalletHeader_LeavesOtherHeadersUntouched(t *testing.T) {
	// Defensive: the strip middleware must scope its destruction to a
	// single header key. Other headers (Authorization, custom auth, etc.)
	// must pass through unmodified.
	r := gin.New()
	r.Use(middleware.StripInboundWalletHeader())
	r.GET("/echo", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"authorization": c.GetHeader("Authorization"),
			"x_custom":      c.GetHeader("X-Custom-Header"),
			"x_wallet":      c.GetHeader("X-Wallet-Address"),
		})
	})

	req, _ := http.NewRequest(http.MethodGet, "/echo", nil)
	req.Header.Set("Authorization", "Bearer eyJ...")
	req.Header.Set("X-Custom-Header", "keep-me")
	req.Header.Set("X-Wallet-Address", "0xVictim")

	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	require.Equal(t, http.StatusOK, w.Code)
	assert.Contains(t, w.Body.String(), "Bearer eyJ...",
		"Authorization header must survive")
	assert.Contains(t, w.Body.String(), "keep-me",
		"unrelated custom headers must survive")
	assert.NotContains(t, w.Body.String(), "0xVictim",
		"X-Wallet-Address must have been stripped")
}

// TestAuthOrAPIKey_ForgedWalletHeaderRejected verifies that the v3.12-P0-1
// hardening of AuthOrAPIKey doesn't let an attacker bypass auth by setting
// the X-Wallet-Address header directly. AuthOrAPIKey now reads only the
// gin.Context "wallet" key (set by JWTExtractor) — never the raw header.
func TestAuthOrAPIKey_ForgedWalletHeaderRejected(t *testing.T) {
	testutil.NewTestDB(t) // AuthOrAPIKey -> APIKeyAuth needs a DB to lookup keys

	// Mount the chain WITHOUT a JWT extractor — simulating an attacker
	// who tries to skip both JWT and API key auth by setting the header.
	r := gin.New()
	r.Use(middleware.StripInboundWalletHeader())
	r.GET("/dual", middleware.AuthOrAPIKey("write:agents"), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"wallet": c.GetString("wallet")})
	})

	req, _ := http.NewRequest(http.MethodGet, "/dual", nil)
	req.Header.Set("X-Wallet-Address", "0xForgedAttacker")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	assert.Equal(t, http.StatusUnauthorized, w.Code,
		"AuthOrAPIKey must not accept a forged X-Wallet-Address — it should fall through to APIKeyAuth and 401 on missing key")
	assert.NotContains(t, w.Body.String(), "0xForgedAttacker",
		"forged wallet must never reach the handler context")
}

// TestAuthOrAPIKey_ContextWalletAccepted is the positive control — when the
// JWT extractor has already set "wallet" in the gin context (production
// path), AuthOrAPIKey trusts it and skips API key auth.
func TestAuthOrAPIKey_ContextWalletAccepted(t *testing.T) {
	testutil.NewTestDB(t)

	r := gin.New()
	r.Use(middleware.StripInboundWalletHeader())
	// Stub JWT extractor: pretend a Bearer token validated to 0xJWT.
	r.Use(func(c *gin.Context) {
		c.Set("wallet", "0xJWT")
		c.Next()
	})
	r.GET("/dual", middleware.AuthOrAPIKey("write:agents"), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"wallet":      c.GetString("wallet"),
			"auth_method": c.GetString("auth_method"),
		})
	})

	req, _ := http.NewRequest(http.MethodGet, "/dual", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	require.Equal(t, http.StatusOK, w.Code)
	assert.Contains(t, w.Body.String(), "0xJWT")
	assert.Contains(t, w.Body.String(), `"auth_method":"jwt"`)
}

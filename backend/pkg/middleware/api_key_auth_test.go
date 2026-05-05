package middleware_test

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/middleware"
	"github.com/agentstore/backend/pkg/models"
	"github.com/agentstore/backend/services/agent"
	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Tests live in middleware_test (external) so we can import services/agent for
// CreateKey without creating a cycle inside the middleware package.

func init() {
	gin.SetMode(gin.TestMode)
}

// newTestRig sets up an in-memory DB and an Agent service ready to mint API
// keys (with a low bcrypt cost so tests stay fast).
func newTestRig(t *testing.T) *agent.AgentService {
	t.Helper()
	testutil.NewTestDB(t)
	restore := agent.SetAPIKeyBcryptCostForTest(4) // bcrypt.MinCost
	t.Cleanup(restore)
	return agent.NewAgentService(nil, nil, nil, "", "")
}

// mountTestRoute spins up a Gin engine with one /protected endpoint guarded
// by the requested middleware factory and returns a doRequest helper.
func mountTestRoute(handler gin.HandlerFunc) (do func(req *http.Request) *httptest.ResponseRecorder) {
	r := gin.New()
	r.GET("/protected", handler, func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"wallet":      c.GetString("wallet"),
			"auth_method": c.GetString("auth_method"),
		})
	})
	return func(req *http.Request) *httptest.ResponseRecorder {
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		return w
	}
}

func TestAPIKeyAuth_ValidKeyPasses(t *testing.T) {
	svc := newTestRig(t)
	plaintext, _, err := svc.CreateKey("0xowner", "test", []string{"read:agents"})
	require.NoError(t, err)

	do := mountTestRoute(middleware.APIKeyAuth("read:agents"))
	req, _ := http.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("X-API-Key", plaintext)
	w := do(req)

	assert.Equal(t, http.StatusOK, w.Code)
	assert.Contains(t, w.Body.String(), "0xowner")
	assert.Contains(t, w.Body.String(), `"auth_method":"api_key"`)
}

func TestAPIKeyAuth_RevokedKeyRejected(t *testing.T) {
	svc := newTestRig(t)
	plaintext, row, err := svc.CreateKey("0xowner", "test", []string{"read:agents"})
	require.NoError(t, err)

	// Revoke and confirm middleware now rejects with 401.
	require.NoError(t, svc.RevokeKey("0xowner", row.ID))

	do := mountTestRoute(middleware.APIKeyAuth("read:agents"))
	req, _ := http.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("X-API-Key", plaintext)
	w := do(req)

	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assert.Contains(t, w.Body.String(), "revoked")
}

func TestAPIKeyAuth_MissingScopeReturns403(t *testing.T) {
	svc := newTestRig(t)
	// Key has only read:agents but the route demands write:agents.
	plaintext, _, err := svc.CreateKey("0xowner", "test", []string{"read:agents"})
	require.NoError(t, err)

	do := mountTestRoute(middleware.APIKeyAuth("write:agents"))
	req, _ := http.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("X-API-Key", plaintext)
	w := do(req)

	assert.Equal(t, http.StatusForbidden, w.Code,
		"scope mismatch must be 403 (authenticated but not permitted), not 401")
	assert.Contains(t, w.Body.String(), "missing required scope")
}

func TestAPIKeyAuth_MissingHeaderReturns401(t *testing.T) {
	newTestRig(t) // Need DB so the lookup query has somewhere to dial.

	do := mountTestRoute(middleware.APIKeyAuth("read:agents"))
	req, _ := http.NewRequest(http.MethodGet, "/protected", nil)
	w := do(req)

	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assert.Contains(t, w.Body.String(), "missing api key")
}

func TestAuthOrAPIKey_JWTContextWalletTakesPrecedence(t *testing.T) {
	// JWT path doesn't even need a key — wallet set in the gin context by
	// the JWT extractor is enough.
	//
	// SECURITY (v3.12-P0-1): updated from the original test, which relied on
	// AuthOrAPIKey reading the raw X-Wallet-Address header. That was an
	// auth-bypass vector: an attacker could set the header on inbound
	// requests and skip both JWT and API-key checks. AuthOrAPIKey now trusts
	// only c.Get("wallet") which is set by the JWT extractor *after*
	// verifying the Bearer token signature.
	testutil.NewTestDB(t)

	r := gin.New()
	// Stub JWT extractor — emulates gateway.JWTExtractor on a successful
	// verify. In production the wallet is the parsed claim from a signed
	// JWT; here we just inject it directly.
	r.Use(func(c *gin.Context) {
		c.Set("wallet", "0xjwtwallet")
		c.Next()
	})
	r.GET("/protected", middleware.AuthOrAPIKey("write:agents"), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"wallet":      c.GetString("wallet"),
			"auth_method": c.GetString("auth_method"),
		})
	})

	req, _ := http.NewRequest(http.MethodGet, "/protected", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
	assert.Contains(t, w.Body.String(), "0xjwtwallet")
	assert.Contains(t, w.Body.String(), `"auth_method":"jwt"`,
		"JWT path must mark auth_method=jwt so handlers can audit how the request was authed")

	// Bonus assertion: last_used_at on any persisted key should NOT be set,
	// because the API-key code path should never have run.
	var keys []models.APIKey
	require.NoError(t, database.DB.Find(&keys).Error)
	for _, k := range keys {
		assert.Nil(t, k.LastUsedAt, "API-key path must be fully bypassed when JWT context wallet is present")
	}
}

// TestAPIKeyAuth_LastUsedAtUpdated verifies the synchronous LastUsedAt bump.
// v3.12-P1-12: was async + polled; flaked under full-suite runs because
// t.Cleanup tore down database.DB before the goroutine landed its write. The
// fix made the update synchronous, so this test no longer needs polling.
func TestAPIKeyAuth_LastUsedAtUpdated(t *testing.T) {
	svc := newTestRig(t)
	plaintext, row, err := svc.CreateKey("0xowner", "test", []string{"read:agents"})
	require.NoError(t, err)

	do := mountTestRoute(middleware.APIKeyAuth("read:agents"))
	req, _ := http.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("X-API-Key", plaintext)
	w := do(req)
	require.Equal(t, http.StatusOK, w.Code)

	// Synchronous — the write must already be persisted by the time the
	// request returns. No polling.
	var refreshed models.APIKey
	require.NoError(t, database.DB.First(&refreshed, row.ID).Error)
	require.NotNil(t, refreshed.LastUsedAt, "LastUsedAt must be stamped after a successful auth")
}

package agent

import (
	"strings"
	"testing"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/cache"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"golang.org/x/crypto/bcrypt"
)

// API key tests run with bcrypt cost=4 so the suite stays fast (~5ms per hash
// vs ~60ms at default cost). The cost only affects test runtime, not the
// security model — the hash bytes remain bcrypt-shaped.

func newAPIKeyTestSvc(t *testing.T) *AgentService {
	t.Helper()
	testutil.NewTestDB(t)
	t.Cleanup(SetAPIKeyBcryptCostForTest(bcrypt.MinCost))
	return NewAgentService(nil, nil, cache.NewStore(), "", "")
}

func TestCreateKey_PlaintextHashesToStoredHash(t *testing.T) {
	svc := newAPIKeyTestSvc(t)

	plaintext, row, err := svc.CreateKey("0xabc", "ci-bot", []string{"read:agents"})
	require.NoError(t, err)
	require.NotNil(t, row)

	// Plaintext shape: "agst_" + 32 hex chars.
	assert.True(t, strings.HasPrefix(plaintext, apiKeyPrefix), "plaintext must carry namespace prefix")
	assert.Len(t, plaintext, len(apiKeyPrefix)+32, "plaintext must be 5 + 32 chars")

	// Prefix is the first 8 chars after "agst_".
	assert.Len(t, row.Prefix, len(apiKeyPrefix)+8)
	assert.True(t, strings.HasPrefix(plaintext, row.Prefix))

	// The persisted row must have a real bcrypt hash that matches the
	// plaintext we returned to the caller.
	var stored models.APIKey
	require.NoError(t, database.DB.First(&stored, row.ID).Error)
	require.NotEmpty(t, stored.KeyHash, "hash must be persisted")
	assert.NoError(t, bcrypt.CompareHashAndPassword([]byte(stored.KeyHash), []byte(plaintext)),
		"persisted hash must verify against returned plaintext")
}

func TestListKeys_MasksHash(t *testing.T) {
	svc := newAPIKeyTestSvc(t)

	_, _, err := svc.CreateKey("0xabc", "k1", []string{"read:agents"})
	require.NoError(t, err)
	_, _, err = svc.CreateKey("0xabc", "k2", []string{"write:agents"})
	require.NoError(t, err)

	rows, err := svc.ListKeys("0xabc")
	require.NoError(t, err)
	require.Len(t, rows, 2)
	for _, r := range rows {
		assert.Empty(t, r.KeyHash, "list response must zero out the bcrypt hash")
		assert.NotEmpty(t, r.Prefix, "prefix must remain visible for display")
	}
}

func TestRevokeKey_TombstonesAndIsWalletScoped(t *testing.T) {
	svc := newAPIKeyTestSvc(t)

	_, mine, err := svc.CreateKey("0xabc", "mine", []string{"read:agents"})
	require.NoError(t, err)

	require.NoError(t, svc.RevokeKey("0xabc", mine.ID))

	var stored models.APIKey
	require.NoError(t, database.DB.First(&stored, mine.ID).Error)
	require.NotNil(t, stored.RevokedAt, "revoke must stamp RevokedAt")

	// Second revoke surfaces the conflict.
	err = svc.RevokeKey("0xabc", mine.ID)
	assert.ErrorIs(t, err, ErrAPIKeyAlreadyRevoked)

	// A foreign wallet must not be able to revoke it (or even see it).
	err = svc.RevokeKey("0xdef", mine.ID)
	assert.ErrorIs(t, err, ErrAPIKeyNotFound)
}

func TestListKeys_WalletIsolation(t *testing.T) {
	svc := newAPIKeyTestSvc(t)

	_, _, err := svc.CreateKey("0xabc", "alice", []string{"read:agents"})
	require.NoError(t, err)
	_, _, err = svc.CreateKey("0xdef", "bob", []string{"read:agents"})
	require.NoError(t, err)

	alice, err := svc.ListKeys("0xabc")
	require.NoError(t, err)
	require.Len(t, alice, 1)
	assert.Equal(t, "alice", alice[0].Name)

	bob, err := svc.ListKeys("0xdef")
	require.NoError(t, err)
	require.Len(t, bob, 1)
	assert.Equal(t, "bob", bob[0].Name)
}

func TestCreateKey_RejectsUnknownScope(t *testing.T) {
	svc := newAPIKeyTestSvc(t)

	_, _, err := svc.CreateKey("0xabc", "k", []string{"read:agents", "delete:everything"})
	require.Error(t, err)
	assert.ErrorIs(t, err, ErrInvalidScope)

	// Empty scopes is permitted (stub key, no permissions).
	_, row, err := svc.CreateKey("0xabc", "stub", []string{})
	require.NoError(t, err)
	assert.Empty(t, row.Scopes)
}

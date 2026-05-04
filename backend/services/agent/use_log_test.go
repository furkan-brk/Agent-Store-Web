package agent

import (
	"testing"
	"time"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Cooldown matrix:
//
//   first call  → counted=true, log row inserted
//   second call (same wallet, < 60s)   → counted=false (cooldown hit)
//   second call (same ip_hash, < 60s) → counted=false
//   second call (no identity)          → counted=true (cooldown bypassed)
//
// recordUseAttempt is the unit under test; the higher-level
// IncrementUseCount integration is exercised in service_test.go.

func TestRecordUseAttempt_FirstCallCountsAndLogs(t *testing.T) {
	testutil.NewTestDB(t)

	allowed := recordUseAttempt(42, "0xabc", "iphash-abc")
	require.True(t, allowed, "first call must be allowed")

	var count int64
	require.NoError(t, database.DB.Model(&models.AgentUseLog{}).Count(&count).Error)
	assert.EqualValues(t, 1, count, "expected one log row")
}

func TestRecordUseAttempt_SameWalletWithinWindowIsBlocked(t *testing.T) {
	testutil.NewTestDB(t)

	require.True(t, recordUseAttempt(42, "0xabc", "iphash-abc"))
	allowed := recordUseAttempt(42, "0xabc", "iphash-OTHER")
	assert.False(t, allowed, "same wallet within window must be blocked")

	var count int64
	database.DB.Model(&models.AgentUseLog{}).Count(&count)
	assert.EqualValues(t, 1, count, "blocked attempt must not insert a row")
}

func TestRecordUseAttempt_SameIPHashWithinWindowIsBlocked(t *testing.T) {
	testutil.NewTestDB(t)

	require.True(t, recordUseAttempt(42, "0xabc", "iphash-X"))
	// Different wallet but same ip_hash — also blocked.
	allowed := recordUseAttempt(42, "0xdef", "iphash-X")
	assert.False(t, allowed, "same ip_hash within window must be blocked")
}

func TestRecordUseAttempt_DifferentAgentIDsAreIndependent(t *testing.T) {
	testutil.NewTestDB(t)

	require.True(t, recordUseAttempt(1, "0xabc", "iphash-1"))
	allowed := recordUseAttempt(2, "0xabc", "iphash-1")
	assert.True(t, allowed, "different agent must not share cooldown")
}

func TestRecordUseAttempt_OutsideWindowAllowsAgain(t *testing.T) {
	testutil.NewTestDB(t)

	// Manually insert a log row with a stale timestamp so we don't have to
	// sleep the cooldown duration in the test.
	stale := time.Now().Add(-2 * useCooldownWindow)
	require.NoError(t, database.DB.Create(&models.AgentUseLog{
		AgentID:   42,
		Wallet:    "0xabc",
		IPHash:    "iphash-abc",
		CreatedAt: stale,
	}).Error)

	allowed := recordUseAttempt(42, "0xabc", "iphash-abc")
	assert.True(t, allowed, "after window, attempt must be allowed again")
}

func TestRecordUseAttempt_NoIdentityBypassesCooldown(t *testing.T) {
	testutil.NewTestDB(t)

	// Internal/anonymous calls (no wallet, no ip) always count — used by
	// trusted server-to-server paths like workflow execution.
	require.True(t, recordUseAttempt(42, "", ""))
	require.True(t, recordUseAttempt(42, "", ""))
}

func TestHashIP_DeterministicAndPrivacyPreserving(t *testing.T) {
	a := HashIP("203.0.113.5")
	b := HashIP("203.0.113.5")
	c := HashIP("203.0.113.6")

	assert.Equal(t, a, b, "same IP must produce same hash")
	assert.NotEqual(t, a, c, "different IPs must produce different hashes")
	assert.NotContains(t, a, "203", "raw IP octets must not appear in the hash")
	assert.Empty(t, HashIP(""), "empty input → empty output")
	assert.Empty(t, HashIP("   "), "whitespace input → empty output")
}

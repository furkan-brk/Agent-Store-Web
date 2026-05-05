package agent

// rating_verified_test.go — covers v3.11.4 GetRatings(verifiedOnly) filter
// and the CopyAnalytics RecordActivity hook.

import (
	"testing"
	"time"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/cache"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func newRatingVerifiedSvc(t *testing.T) *AgentService {
	t.Helper()
	testutil.NewTestDB(t)
	return NewAgentService(nil, nil, cache.NewStore(), "", "")
}

// seedRatingsAndPurchase inserts 3 ratings on agent 1: one from a verified
// purchaser ("0xbuyer"), two from unverified wallets.
func seedRatingsAndPurchase(t *testing.T) {
	t.Helper()
	now := time.Now()
	require.NoError(t, database.DB.Create(&models.AgentRating{
		AgentID: 1, Wallet: "0xbuyer", Rating: 5, Comment: "verified great",
		CreatedAt: now,
	}).Error)
	require.NoError(t, database.DB.Create(&models.AgentRating{
		AgentID: 1, Wallet: "0xrando1", Rating: 3, Comment: "meh",
		CreatedAt: now.Add(-time.Hour),
	}).Error)
	require.NoError(t, database.DB.Create(&models.AgentRating{
		AgentID: 1, Wallet: "0xrando2", Rating: 1, Comment: "bad",
		CreatedAt: now.Add(-2 * time.Hour),
	}).Error)
	// Only 0xbuyer has a PurchasedAgent row.
	require.NoError(t, database.DB.Create(&models.PurchasedAgent{
		BuyerWallet: "0xbuyer", AgentID: 1, TxHash: "0xdeadbeef", AmountMon: 1.0,
	}).Error)
}

func TestGetRatings_VerifiedOnlyExcludesUnpurchasedReviewers(t *testing.T) {
	svc := newRatingVerifiedSvc(t)
	seedRatingsAndPurchase(t)

	rows, avg, count, err := svc.GetRatings(1, true)
	require.NoError(t, err)
	require.Len(t, rows, 1, "only the purchaser's rating should appear when verified_only=true")
	assert.Equal(t, "0xbuyer", rows[0].Wallet)
	assert.EqualValues(t, 1, count)
	assert.InDelta(t, 5.0, avg, 0.001, "average should be just the verified rating")
}

func TestGetRatings_VerifiedOnlyFalsePreservesAllRatings(t *testing.T) {
	svc := newRatingVerifiedSvc(t)
	seedRatingsAndPurchase(t)

	rows, avg, count, err := svc.GetRatings(1, false)
	require.NoError(t, err)
	require.Len(t, rows, 3, "all 3 ratings visible when verified_only=false (backward compat)")
	assert.EqualValues(t, 3, count)
	// avg = (5 + 3 + 1) / 3 = 3.0
	assert.InDelta(t, 3.0, avg, 0.001)
}

func TestCopyAnalytics_RecordsPromptCopyActivity(t *testing.T) {
	svc := newRatingVerifiedSvc(t)
	// Direct service call (handler tested via integration; we exercise the
	// underlying RecordActivity write here).
	svc.RecordActivity("0xreader", "prompt_copy", 42, nil)

	var rows []models.UserActivity
	require.NoError(t, database.DB.Where("wallet = ? AND type = ?", "0xreader", "prompt_copy").Find(&rows).Error)
	require.Len(t, rows, 1)
	assert.EqualValues(t, 42, rows[0].RefID)
}

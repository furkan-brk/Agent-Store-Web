package agent

import (
	"fmt"
	"testing"
	"time"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/cache"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Helpers ------------------------------------------------------------

func newModerationSvc(t *testing.T) *AgentService {
	t.Helper()
	testutil.NewTestDB(t)
	return NewAgentService(nil, nil, cache.NewStore(), "", "")
}

func seedRating(t *testing.T, agentID uint, authorWallet string) models.AgentRating {
	t.Helper()
	r := models.AgentRating{
		AgentID: agentID,
		Wallet:  authorWallet,
		Rating:  1,
		Comment: "boring",
	}
	require.NoError(t, database.DB.Create(&r).Error)
	return r
}

// Tests --------------------------------------------------------------

func TestFlagRating_DedupesPerWalletViaUniqueIndex(t *testing.T) {
	svc := newModerationSvc(t)
	r := seedRating(t, 1, "0xauthor")

	// First flag — counted.
	hidden, err := svc.FlagRating("0xreporter", r.ID, "spam")
	require.NoError(t, err)
	assert.False(t, hidden)

	// Same wallet flags again — silently no-op.
	hidden, err = svc.FlagRating("0xreporter", r.ID, "still spam")
	require.NoError(t, err)
	assert.False(t, hidden)

	var count int64
	require.NoError(t, database.DB.Model(&models.RatingFlag{}).
		Where("rating_id = ?", r.ID).Count(&count).Error)
	assert.EqualValues(t, 1, count, "duplicate flag must not create a second row")
}

func TestFlagRating_RateLimitedAfterThreeFlags(t *testing.T) {
	svc := newModerationSvc(t)

	// Create 3 distinct ratings so the wallet's 3 flags don't trip the
	// per-rating dedup path. (Rate limit is per reporter, not per rating.)
	ratings := make([]models.AgentRating, 3)
	for i := range ratings {
		ratings[i] = seedRating(t, uint(i+1), fmt.Sprintf("0xauthor%d", i))
	}

	for i, r := range ratings {
		_, err := svc.FlagRating("0xreporter", r.ID, "spam")
		require.NoErrorf(t, err, "flag %d in rolling window must succeed", i)
	}

	// Fourth flag inside the same window — rate limit kicks in.
	r4 := seedRating(t, 99, "0xanother")
	_, err := svc.FlagRating("0xreporter", r4.ID, "spam")
	assert.ErrorIs(t, err, ErrFlagRateLimited)
}

func TestFlagRating_AutoHidesAtThreeDistinctFlags(t *testing.T) {
	svc := newModerationSvc(t)
	r := seedRating(t, 1, "0xauthor")

	// 3 distinct wallets each flag once → threshold crossed on the third.
	for i := range 3 {
		hidden, err := svc.FlagRating(fmt.Sprintf("0xreporter%d", i), r.ID, "spam")
		require.NoError(t, err)
		if i < 2 {
			assert.False(t, hidden, "still below threshold")
		} else {
			assert.True(t, hidden, "third distinct flag must hide the rating")
		}
	}

	// Verify Hidden persisted and GetRatings drops it from the public list.
	var stored models.AgentRating
	require.NoError(t, database.DB.First(&stored, r.ID).Error)
	assert.True(t, stored.Hidden)

	rows, _, count, err := svc.GetRatings(1, false)
	require.NoError(t, err)
	assert.Empty(t, rows, "hidden rating must not appear in public list")
	assert.EqualValues(t, 0, count)
}

func TestIsAbusive_DetectsProfanityAndUrlSpam(t *testing.T) {
	// Profanity heuristic: case-insensitive substring match on the blocklist.
	assert.True(t, isAbusive("This is shit"))
	assert.True(t, isAbusive("FUCK this thing"))

	// URL-count heuristic: >2 http(s) URLs is treated as link spam.
	assert.True(t, isAbusive("buy here http://a.com http://b.com http://c.com http://d.com"))

	// Clean and url-light comments are NOT abusive.
	assert.False(t, isAbusive("Pretty solid agent, recommend"))
	assert.False(t, isAbusive("See https://example.com for more"))
	assert.False(t, isAbusive(""))
}

func TestFlagRating_WalletIsolationAndSelfFlag(t *testing.T) {
	svc := newModerationSvc(t)
	r := seedRating(t, 1, "0xauthor")

	// Self-flag is forbidden.
	_, err := svc.FlagRating("0xauthor", r.ID, "i hate myself")
	assert.ErrorIs(t, err, ErrSelfFlag)

	// Wallet A flagging rating r1 must not affect Wallet B's flag count on
	// rating r2 — the rate-limit query is per-reporter, not global.
	r2 := seedRating(t, 2, "0xauthor2")
	_, err = svc.FlagRating("0xreporterA", r.ID, "x")
	require.NoError(t, err)
	_, err = svc.FlagRating("0xreporterB", r2.ID, "y")
	require.NoError(t, err)

	// Sanity: each reporter has exactly one flag.
	var aCount, bCount int64
	database.DB.Model(&models.RatingFlag{}).
		Where("reporter_wallet = ?", "0xreportera").Count(&aCount)
	database.DB.Model(&models.RatingFlag{}).
		Where("reporter_wallet = ?", "0xreporterb").Count(&bCount)
	assert.EqualValues(t, 1, aCount)
	assert.EqualValues(t, 1, bCount)

	// Non-existent rating → ErrRatingNotFound.
	_, err = svc.FlagRating("0xreporterC", 9999, "ghost")
	assert.ErrorIs(t, err, ErrRatingNotFound)

	// Make sure the rate-window cutoff is honoured: a stale flag outside the
	// window should not count toward the limit.
	stale := time.Now().Add(-2 * flagRateWindow)
	for i := range flagRateMaxInWindow {
		require.NoError(t, database.DB.Create(&models.RatingFlag{
			RatingID:       uint(900 + i),
			ReporterWallet: "0xreporterC",
			Reason:         "old",
			CreatedAt:      stale,
		}).Error)
	}
	r3 := seedRating(t, 3, "0xauthor3")
	_, err = svc.FlagRating("0xreporterC", r3.ID, "fresh")
	assert.NoError(t, err, "stale flags must not count toward the rolling window")
}

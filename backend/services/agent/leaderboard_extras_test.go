package agent

// leaderboard_extras_test.go — covers v3.11.4 leaderboard category, me, and
// weekly reward features.

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

func newLeaderboardSvc(t *testing.T) *AgentService {
	t.Helper()
	testutil.NewTestDB(t)
	return NewAgentService(nil, nil, cache.NewStore(), "", "")
}

func seedAgentForLeaderboard(t *testing.T, wallet, category string, saves int64) {
	t.Helper()
	require.NoError(t, database.DB.Create(&models.Agent{
		Title: "x", CreatorWallet: wallet, Category: category,
		Prompt: "p", SaveCount: saves,
	}).Error)
}

func TestGetLeaderboardByCategory_FiltersAndRanks(t *testing.T) {
	svc := newLeaderboardSvc(t)
	seedAgentForLeaderboard(t, "0xa", "backend", 100)
	seedAgentForLeaderboard(t, "0xa", "backend", 50) // 0xa total = 150
	seedAgentForLeaderboard(t, "0xb", "backend", 75)
	seedAgentForLeaderboard(t, "0xc", "frontend", 999) // wrong cat

	rows, err := svc.GetLeaderboardByCategory("backend", "all")
	require.NoError(t, err)
	require.Len(t, rows, 2, "0xc filtered out")
	assert.Equal(t, "0xa", rows[0].Wallet)
	assert.EqualValues(t, 1, rows[0].Rank)
	assert.EqualValues(t, 150, rows[0].TotalSaves)
	assert.Equal(t, "0xb", rows[1].Wallet)
}

func TestGetUserRank_ReturnsNeighbors(t *testing.T) {
	svc := newLeaderboardSvc(t)
	// 5 wallets at decreasing save counts → 0xa #1 → 0xe #5
	seedAgentForLeaderboard(t, "0xa", "x", 50)
	seedAgentForLeaderboard(t, "0xb", "x", 40)
	seedAgentForLeaderboard(t, "0xc", "x", 30)
	seedAgentForLeaderboard(t, "0xd", "x", 20)
	seedAgentForLeaderboard(t, "0xe", "x", 10)

	out, err := svc.GetUserRank("0xc", "all")
	require.NoError(t, err)
	assert.EqualValues(t, 3, out.Rank)
	assert.EqualValues(t, 5, out.Total)
	require.Len(t, out.Neighbors, 5, "myself + 2 above + 2 below")
	// IsMe flag set on the rank-3 entry
	for _, n := range out.Neighbors {
		if n.Wallet == "0xc" {
			assert.True(t, n.IsMe)
		} else {
			assert.False(t, n.IsMe)
		}
	}
}

func TestGetUserRank_OffBoardReturnsBottom(t *testing.T) {
	svc := newLeaderboardSvc(t)
	seedAgentForLeaderboard(t, "0xa", "x", 50)
	seedAgentForLeaderboard(t, "0xb", "x", 40)

	out, err := svc.GetUserRank("0xunknown", "all")
	require.NoError(t, err)
	assert.EqualValues(t, 0, out.Rank, "wallet not on the board → rank 0")
	assert.LessOrEqual(t, len(out.Neighbors), 5)
}

func TestRecordWeeklyLeaderReward_PaysTopThreeAndIsIdempotent(t *testing.T) {
	svc := newLeaderboardSvc(t)
	seedAgentForLeaderboard(t, "0xa", "x", 100)
	seedAgentForLeaderboard(t, "0xb", "x", 50)
	seedAgentForLeaderboard(t, "0xc", "x", 25)
	// User rows for credit bumps
	for _, w := range []string{"0xa", "0xb", "0xc"} {
		require.NoError(t, database.DB.Create(&models.User{
			WalletAddress: w, Credits: 0,
		}).Error)
	}

	out, err := svc.RecordWeeklyLeaderReward()
	require.NoError(t, err)
	require.False(t, out.Skipped)
	assert.GreaterOrEqual(t, len(out.Rewards), 3, "at least the top-3 paid")

	// 2nd call is a no-op (idempotent via composite unique index).
	out2, err := svc.RecordWeeklyLeaderReward()
	require.NoError(t, err)
	assert.True(t, out2.Skipped)
}

func TestListWeeklyRewards_NewestFirst(t *testing.T) {
	svc := newLeaderboardSvc(t)
	require.NoError(t, database.DB.Create(&models.WeeklyLeaderReward{
		Week: "2026-W01", Wallet: "0xa", Rank: 1, Credits: 100,
		AwardedAt: time.Now().Add(-30 * 24 * time.Hour),
	}).Error)
	require.NoError(t, database.DB.Create(&models.WeeklyLeaderReward{
		Week: "2026-W18", Wallet: "0xa", Rank: 1, Credits: 100,
		AwardedAt: time.Now(),
	}).Error)

	rows, err := svc.ListWeeklyRewards(4)
	require.NoError(t, err)
	require.Len(t, rows, 2)
	assert.Equal(t, "2026-W18", rows[0].Week, "newer week comes first")
}

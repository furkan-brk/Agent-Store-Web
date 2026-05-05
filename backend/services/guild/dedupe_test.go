package guild

import (
	"testing"
	"time"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestDedupeGuildMembers asserts the v3.12-P1-13 production migration helper
// prunes duplicate (guild_id, agent_id) rows, keeping the lowest ID. We drop
// the unique index first so we can synthesise the legacy duplicates that
// production DBs accumulated before the constraint existed.
func TestDedupeGuildMembers(t *testing.T) {
	testutil.NewTestDB(t)
	db := database.DB

	// Drop the composite unique index so we can insert duplicates the way
	// legacy code did (pre-constraint).
	require.NoError(t, db.Exec("DROP INDEX IF EXISTS idx_guild_member_pair").Error)

	// Three rows with the same (guild_id, agent_id). IDs will be 1, 2, 3 —
	// auto-assigned in insert order.
	now := time.Now()
	rows := []models.GuildMember{
		{GuildID: 7, AgentID: 42, Role: "wizard", JoinedAt: now.Add(-3 * time.Hour)},
		{GuildID: 7, AgentID: 42, Role: "wizard", JoinedAt: now.Add(-2 * time.Hour)},
		{GuildID: 7, AgentID: 42, Role: "wizard", JoinedAt: now.Add(-1 * time.Hour)},
	}
	for i := range rows {
		require.NoError(t, db.Create(&rows[i]).Error)
	}

	// Independent member row in a different guild — must survive dedupe.
	other := models.GuildMember{GuildID: 8, AgentID: 42, Role: "guardian", JoinedAt: now}
	require.NoError(t, db.Create(&other).Error)

	// Sanity check: 4 rows pre-dedupe.
	var beforeCount int64
	require.NoError(t, db.Model(&models.GuildMember{}).Count(&beforeCount).Error)
	require.Equal(t, int64(4), beforeCount)

	require.NoError(t, dedupeGuildMembers(db))

	var afterCount int64
	require.NoError(t, db.Model(&models.GuildMember{}).Count(&afterCount).Error)
	assert.Equal(t, int64(2), afterCount, "dedupe must collapse duplicates to one row per (guild_id, agent_id)")

	// The surviving row in (7, 42) must be the lowest-ID one (id=1, the
	// earliest insert).
	var survivor models.GuildMember
	require.NoError(t, db.Where("guild_id = ? AND agent_id = ?", 7, 42).First(&survivor).Error)
	assert.Equal(t, uint(1), survivor.ID, "lowest-ID row wins")

	// The (8, 42) row must still exist untouched.
	var otherSurvivor models.GuildMember
	require.NoError(t, db.Where("guild_id = ? AND agent_id = ?", 8, 42).First(&otherSurvivor).Error)
	assert.Equal(t, "guardian", otherSurvivor.Role)
}

// TestDedupeGuildMembers_NoOpOnCleanTable verifies the helper is idempotent —
// calling it on a table with no duplicates leaves all rows in place.
func TestDedupeGuildMembers_NoOpOnCleanTable(t *testing.T) {
	testutil.NewTestDB(t)
	db := database.DB

	rows := []models.GuildMember{
		{GuildID: 1, AgentID: 1},
		{GuildID: 1, AgentID: 2},
		{GuildID: 2, AgentID: 1},
	}
	for i := range rows {
		require.NoError(t, db.Create(&rows[i]).Error)
	}

	require.NoError(t, dedupeGuildMembers(db))

	var count int64
	require.NoError(t, db.Model(&models.GuildMember{}).Count(&count).Error)
	assert.Equal(t, int64(3), count, "no duplicates → no rows removed")
}

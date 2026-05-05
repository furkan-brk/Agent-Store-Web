package guild

// events_test.go — covers v3.11.4 GuildMemberEvent audit log.

import (
	"testing"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/cache"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func newEventTestSvc(t *testing.T) *GuildService {
	t.Helper()
	testutil.NewTestDB(t)
	return NewGuildService(nil, cache.NewStore())
}

func TestLogMemberEvent_PersistsRowWithPayload(t *testing.T) {
	svc := newEventTestSvc(t)
	svc.LogMemberEvent(7, "0xowner", models.GuildEventJoined, map[string]any{
		"agent_id": 42, "role": "leader",
	})

	var rows []models.GuildMemberEvent
	require.NoError(t, database.DB.Where("guild_id = ?", 7).Find(&rows).Error)
	require.Len(t, rows, 1)
	assert.Equal(t, "0xowner", rows[0].Wallet)
	assert.Equal(t, models.GuildEventJoined, rows[0].EventType)
	assert.Contains(t, rows[0].Payload, "leader")
}

func TestLogMemberEvent_SkipsZeroOrEmptyInputs(t *testing.T) {
	svc := newEventTestSvc(t)
	svc.LogMemberEvent(0, "0xowner", models.GuildEventJoined, nil)        // zero guildID
	svc.LogMemberEvent(7, "", models.GuildEventJoined, nil)                // empty wallet
	svc.LogMemberEvent(7, "0xowner", "", nil)                              // empty type

	var n int64
	database.DB.Model(&models.GuildMemberEvent{}).Count(&n)
	assert.EqualValues(t, 0, n, "no events should land for invalid inputs")
}

func TestListGuildEvents_NewestFirstAndLimitClamp(t *testing.T) {
	svc := newEventTestSvc(t)
	for i := range 5 {
		svc.LogMemberEvent(7, "0xowner", models.GuildEventJoined, map[string]any{"i": i})
	}

	rows, err := svc.ListGuildEvents(7, 100) // requested 100 → clamped to 50 default cap
	require.NoError(t, err)
	require.Len(t, rows, 5)
	// id DESC: first row should have higher id than last
	assert.Greater(t, rows[0].ID, rows[len(rows)-1].ID, "rows must be newest-first")
}

func TestListGuildEvents_GuildScoped(t *testing.T) {
	svc := newEventTestSvc(t)
	svc.LogMemberEvent(1, "0xa", models.GuildEventJoined, nil)
	svc.LogMemberEvent(2, "0xb", models.GuildEventJoined, nil)

	rows, err := svc.ListGuildEvents(1, 20)
	require.NoError(t, err)
	require.Len(t, rows, 1)
	assert.Equal(t, "0xa", rows[0].Wallet)
}

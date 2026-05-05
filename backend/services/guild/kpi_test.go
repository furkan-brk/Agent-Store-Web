package guild

// kpi_test.go — covers v3.11.4 GetGuildMasterKPI ratios.

import (
	"testing"
	"time"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func newKPITestSvc(t *testing.T) *GuildMasterService {
	t.Helper()
	testutil.NewTestDB(t)
	return NewGuildMasterService(nil)
}

func seedGMActivity(t *testing.T, wallet, actType string, sessionID uint, when time.Time) {
	t.Helper()
	row := models.UserActivity{
		Wallet:    wallet,
		Type:      actType,
		CreatedAt: when,
	}
	if sessionID != 0 {
		row.Metadata = `{"session_id":` + intStr(int(sessionID)) + `}`
	}
	require.NoError(t, database.DB.Create(&row).Error)
}

func intStr(n int) string {
	if n == 0 {
		return "0"
	}
	digits := []byte{}
	neg := n < 0
	if neg {
		n = -n
	}
	for n > 0 {
		digits = append([]byte{byte('0' + n%10)}, digits...)
		n /= 10
	}
	if neg {
		digits = append([]byte{'-'}, digits...)
	}
	return string(digits)
}

func TestGetGuildMasterKPI_AllZeroWhenNoActivity(t *testing.T) {
	svc := newKPITestSvc(t)
	kpi, err := svc.GetGuildMasterKPI("0xowner", "30d")
	require.NoError(t, err)
	assert.EqualValues(t, 0, kpi.SuggestCount)
	assert.EqualValues(t, -1, kpi.SuggestAcceptanceRate, "empty denom → -1 sentinel")
	assert.EqualValues(t, -1, kpi.RerunRate)
	assert.EqualValues(t, -1, kpi.ChatToActionRate)
}

func TestGetGuildMasterKPI_AcceptanceAndRerunRatios(t *testing.T) {
	svc := newKPITestSvc(t)
	now := time.Now()
	// Session 1: 2 suggests (one rerun), 1 mission bridge
	seedGMActivity(t, "0xowner", GMActSuggest, 1, now)
	seedGMActivity(t, "0xowner", GMActSuggest, 1, now)
	seedGMActivity(t, "0xowner", GMActBridgeMission, 1, now)
	// Session 2: 1 suggest, 1 legend bridge (accepted first try)
	seedGMActivity(t, "0xowner", GMActSuggest, 2, now)
	seedGMActivity(t, "0xowner", GMActBridgeLegend, 2, now)
	// 4 chat events
	for range 4 {
		seedGMActivity(t, "0xowner", GMActChat, 0, now)
	}

	kpi, err := svc.GetGuildMasterKPI("0xowner", "30d")
	require.NoError(t, err)
	assert.EqualValues(t, 3, kpi.SuggestCount)
	assert.EqualValues(t, 2, kpi.BridgeCount)
	assert.EqualValues(t, 4, kpi.ChatCount)
	assert.EqualValues(t, 2, kpi.DistinctSuggestSessions)
	// Acceptance: 2 bridges / 3 suggests = 0.667
	assert.InDelta(t, 0.6667, kpi.SuggestAcceptanceRate, 0.001)
	// Rerun: (3 suggests - 2 distinct sessions) / 3 = 0.333
	assert.InDelta(t, 0.3333, kpi.RerunRate, 0.001)
	// ChatToAction: 2 bridges / 4 chats = 0.5
	assert.InDelta(t, 0.5, kpi.ChatToActionRate, 0.001)
}

func TestGetGuildMasterKPI_SinceWindowFiltersOldRows(t *testing.T) {
	svc := newKPITestSvc(t)
	now := time.Now()
	old := now.Add(-60 * 24 * time.Hour)
	seedGMActivity(t, "0xowner", GMActSuggest, 1, old)   // outside 30d
	seedGMActivity(t, "0xowner", GMActSuggest, 2, now)   // inside

	kpi, err := svc.GetGuildMasterKPI("0xowner", "30d")
	require.NoError(t, err)
	assert.EqualValues(t, 1, kpi.SuggestCount, "60-day-old row should be excluded by 30d window")
}

package agent

import (
	"strings"
	"testing"
	"time"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/cache"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func newFunnelTestSvc(t *testing.T) *AgentService {
	t.Helper()
	testutil.NewTestDB(t)
	return NewAgentService(nil, nil, cache.NewStore(), "", "")
}

// seedActivity inserts a UserActivity row directly (bypasses RecordActivity
// to control type strings and timestamps).
func seedActivity(t *testing.T, wallet, actType string, refID uint, when time.Time) {
	t.Helper()
	row := &models.UserActivity{
		Wallet:    strings.ToLower(wallet),
		Type:      actType,
		RefID:     refID,
		CreatedAt: when,
	}
	require.NoError(t, database.DB.Create(row).Error)
}

func TestGetFunnelMetrics_SuggestToExecuteRatio(t *testing.T) {
	svc := newFunnelTestSvc(t)
	now := time.Now().UTC()

	// 4 suggests, 1 execute → 25%.
	for i := range 4 {
		seedActivity(t, "0xowner", funnelEventSuggest, uint(i+1), now)
	}
	seedActivity(t, "0xowner", funnelEventExecute, 99, now)

	m, err := svc.GetFunnelMetrics("0xowner", "30d")
	require.NoError(t, err)
	require.NotNil(t, m)
	assert.InDelta(t, 0.25, m.SuggestToExecute, 0.001)
}

func TestGetFunnelMetrics_EditToPublishRatio(t *testing.T) {
	svc := newFunnelTestSvc(t)
	now := time.Now().UTC()

	// 2 edits, 2 publishes → 100%.
	for i := range 2 {
		seedActivity(t, "0xowner", funnelEventEdit, uint(i+1), now)
		seedActivity(t, "0xowner", funnelEventPublish, uint(i+1), now)
	}

	m, err := svc.GetFunnelMetrics("0xowner", "30d")
	require.NoError(t, err)
	assert.InDelta(t, 1.0, m.EditToPublish, 0.001)
}

func TestGetFunnelMetrics_DenominatorZeroReturnsNegativeOne(t *testing.T) {
	svc := newFunnelTestSvc(t)

	// No activity at all → all ratios should be -1 ("no signal").
	m, err := svc.GetFunnelMetrics("0xempty", "30d")
	require.NoError(t, err)
	assert.EqualValues(t, -1, m.SuggestToExecute, "no suggests = no signal, not 0%")
	assert.EqualValues(t, -1, m.EditToPublish)
	assert.EqualValues(t, -1, m.TrialToPurchase)
}

func TestGetFunnelMetrics_PublishToFirstSaveMedian(t *testing.T) {
	svc := newFunnelTestSvc(t)
	now := time.Now().UTC()

	// Three agents, each with a known publish→first-save gap.
	// gaps: 5min, 10min, 15min → median = 10min = 600000ms.
	gapsMinutes := []int{5, 10, 15}
	for i, gap := range gapsMinutes {
		createdAt := now.Add(-time.Duration(gap*2) * time.Minute)
		a := &models.Agent{
			Title:         "X",
			Prompt:        "p",
			CreatorWallet: "0xowner",
			CharacterType: "wizard",
			CreatedAt:     createdAt,
		}
		require.NoError(t, database.DB.Create(a).Error)

		// Save came `gap` minutes after creation.
		entry := &models.LibraryEntry{
			UserWallet: "0xfan",
			AgentID:    a.ID,
			SavedAt:    createdAt.Add(time.Duration(gap) * time.Minute),
		}
		require.NoError(t, database.DB.Create(entry).Error)
		_ = i
	}

	m, err := svc.GetFunnelMetrics("0xowner", "30d")
	require.NoError(t, err)
	wantMs := int64(10 * 60 * 1000)
	assert.Equal(t, wantMs, m.PublishToFirstSaveMedianMs,
		"median of [5,10,15] minutes should be 10 minutes (600000ms)")
}

func TestGetFunnelMetrics_SinceFilterWindowsOutOldEvents(t *testing.T) {
	svc := newFunnelTestSvc(t)
	now := time.Now().UTC()

	// Old event (50 days ago) — should NOT count in 7d window.
	seedActivity(t, "0xowner", funnelEventSuggest, 1, now.AddDate(0, 0, -50))
	// Recent event (1 day ago) — counts.
	seedActivity(t, "0xowner", funnelEventSuggest, 2, now.AddDate(0, 0, -1))
	seedActivity(t, "0xowner", funnelEventExecute, 99, now.AddDate(0, 0, -1))

	m, err := svc.GetFunnelMetrics("0xowner", "7d")
	require.NoError(t, err)
	// 1 suggest in window, 1 execute → 100%.
	assert.InDelta(t, 1.0, m.SuggestToExecute, 0.001,
		"50-day-old event must be excluded from 7d window")
}

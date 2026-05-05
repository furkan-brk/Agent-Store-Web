package agent

// discovery_funnel_test.go — covers v3.11.4 GetDiscoveryFunnel ratios.

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

func newDiscoveryTestSvc(t *testing.T) *AgentService {
	t.Helper()
	testutil.NewTestDB(t)
	return NewAgentService(nil, nil, cache.NewStore(), "", "")
}

func seedDiscoveryActivity(t *testing.T, wallet, actType string, refID uint, when time.Time) {
	t.Helper()
	require.NoError(t, database.DB.Create(&models.UserActivity{
		Wallet: wallet, Type: actType, RefID: refID, CreatedAt: when,
	}).Error)
}

func TestGetDiscoveryFunnel_AllSentinelWhenEmpty(t *testing.T) {
	svc := newDiscoveryTestSvc(t)
	out, err := svc.GetDiscoveryFunnel("0xowner", "30d")
	require.NoError(t, err)
	assert.EqualValues(t, -1, out.SearchToSave, "empty denominator → -1")
	assert.EqualValues(t, -1, out.ImpressionToOpen)
	assert.EqualValues(t, -1, out.OpenToSave)
}

func TestGetDiscoveryFunnel_ComputesRatios(t *testing.T) {
	svc := newDiscoveryTestSvc(t)
	now := time.Now()
	// 4 searches, 2 saves → SearchToSave = 0.5
	for i := range 4 {
		seedDiscoveryActivity(t, "0xowner", discoveryEventSearch, uint(i+1), now)
	}
	for i := range 2 {
		seedDiscoveryActivity(t, "0xowner", models.ActivityAgentSaved, uint(i+1), now)
	}
	// 10 impressions, 4 opens → ImpressionToOpen = 0.4
	for i := range 10 {
		seedDiscoveryActivity(t, "0xowner", discoveryEventImpression, uint(i+1), now)
	}
	for i := range 4 {
		seedDiscoveryActivity(t, "0xowner", discoveryEventOpen, uint(i+1), now)
	}
	// open→save = 2 saves / 4 opens = 0.5

	out, err := svc.GetDiscoveryFunnel("0xowner", "30d")
	require.NoError(t, err)
	assert.EqualValues(t, 4, out.SearchCount)
	assert.EqualValues(t, 2, out.SaveCount)
	assert.EqualValues(t, 10, out.ImpressionCount)
	assert.EqualValues(t, 4, out.OpenCount)
	assert.InDelta(t, 0.5, out.SearchToSave, 0.001)
	assert.InDelta(t, 0.4, out.ImpressionToOpen, 0.001)
	assert.InDelta(t, 0.5, out.OpenToSave, 0.001)
}

func TestGetDiscoveryFunnel_SinceWindowFiltersOldRows(t *testing.T) {
	svc := newDiscoveryTestSvc(t)
	now := time.Now()
	old := now.Add(-60 * 24 * time.Hour)
	seedDiscoveryActivity(t, "0xowner", discoveryEventSearch, 1, old)
	seedDiscoveryActivity(t, "0xowner", discoveryEventSearch, 2, now)

	out, err := svc.GetDiscoveryFunnel("0xowner", "30d")
	require.NoError(t, err)
	assert.EqualValues(t, 1, out.SearchCount, "60d row excluded by 30d window")
}

package agent

// achievements_test.go — covers v3.11.4 wallet milestone awarding.

import (
	"testing"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/cache"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func newAchievementSvc(t *testing.T) *AgentService {
	t.Helper()
	testutil.NewTestDB(t)
	return NewAgentService(nil, nil, cache.NewStore(), "", "")
}

func TestCheckAndAwardAchievements_FirstAgentAndIdempotency(t *testing.T) {
	svc := newAchievementSvc(t)
	require.NoError(t, database.DB.Create(&models.Agent{
		Title: "X", CreatorWallet: "0xowner", Prompt: "p",
	}).Error)

	svc.CheckAndAwardAchievements("0xowner")
	rows, err := svc.ListAchievements("0xowner")
	require.NoError(t, err)
	// Owner with 1 agent + zero saves is also automatically the lone top creator,
	// so we expect first_agent (definitely) and top_creator (lone occupant).
	types := map[string]bool{}
	for _, r := range rows {
		types[r.Type] = true
	}
	assert.True(t, types[models.AchievementFirstAgent], "first_agent must be earned")
	prevCount := len(rows)

	// Re-running the check is a no-op thanks to OnConflict-DoNothing.
	svc.CheckAndAwardAchievements("0xowner")
	again, _ := svc.ListAchievements("0xowner")
	assert.Len(t, again, prevCount, "idempotent: no duplicate row count change")
}

func TestCheckAndAwardAchievements_FirstSaleSeenViaPurchaseJoin(t *testing.T) {
	svc := newAchievementSvc(t)
	// owner creates an agent, buyer purchases it.
	require.NoError(t, database.DB.Create(&models.Agent{
		Title: "X", CreatorWallet: "0xowner", Prompt: "p",
	}).Error)
	require.NoError(t, database.DB.Create(&models.PurchasedAgent{
		BuyerWallet: "0xbuyer", AgentID: 1, TxHash: "0xa1", AmountMon: 1.0,
	}).Error)

	svc.CheckAndAwardAchievements("0xowner")
	rows, _ := svc.ListAchievements("0xowner")
	types := []string{}
	for _, r := range rows {
		types = append(types, r.Type)
	}
	assert.Contains(t, types, models.AchievementFirstAgent)
	assert.Contains(t, types, models.AchievementFirstSale)
}

func TestCheckAndAwardAchievements_FirstForkAndHundredSavesAndTopCreator(t *testing.T) {
	svc := newAchievementSvc(t)
	// 0xowner has an agent with 100+ saves (auto: top_creator + hundred_saves).
	require.NoError(t, database.DB.Create(&models.Agent{
		Title: "Big", CreatorWallet: "0xowner", Prompt: "p", SaveCount: 150,
	}).Error)
	// Forker activity row triggers first_fork.
	require.NoError(t, database.DB.Create(&models.UserActivity{
		Wallet: "0xforker", Type: models.ActivityAgentForked, RefID: 1,
	}).Error)

	svc.CheckAndAwardAchievements("0xowner")
	svc.CheckAndAwardAchievements("0xforker")

	ownerBadges, _ := svc.ListAchievements("0xowner")
	ownerTypes := map[string]bool{}
	for _, r := range ownerBadges {
		ownerTypes[r.Type] = true
	}
	assert.True(t, ownerTypes[models.AchievementHundredSaves], "owner should have hundred_saves (150 >= 100)")
	assert.True(t, ownerTypes[models.AchievementTopCreator], "owner is top creator (only one)")

	forkerBadges, _ := svc.ListAchievements("0xforker")
	forkerTypes := []string{}
	for _, r := range forkerBadges {
		forkerTypes = append(forkerTypes, r.Type)
	}
	assert.Contains(t, forkerTypes, models.AchievementFirstFork)
}

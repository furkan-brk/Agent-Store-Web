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

// notification_hooks_test.go covers the v3.11.3 hook surface that fires
// inbox events from social/library/fork actions. Each test exercises one
// hook in isolation so a regression points to the right call site.

func newHookTestSvc(t *testing.T) *AgentService {
	t.Helper()
	testutil.NewTestDB(t)
	return NewAgentService(nil, nil, cache.NewStore(), "", "")
}

// inboxFor returns every notification event for a wallet, newest first.
func inboxFor(t *testing.T, wallet string) []models.NotificationEvent {
	t.Helper()
	var rows []models.NotificationEvent
	require.NoError(t, database.DB.
		Where("wallet = ?", strings.ToLower(wallet)).
		Order("id DESC").Find(&rows).Error)
	return rows
}

func TestFollowUser_TriggersFolloweeNotification(t *testing.T) {
	svc := newHookTestSvc(t)

	require.NoError(t, svc.FollowUser("0xfollower", "0xfollowee"))

	inbox := inboxFor(t, "0xfollowee")
	require.Len(t, inbox, 1, "followee must receive exactly one social event")
	assert.Equal(t, "social", inbox[0].Type)
	assert.Contains(t, inbox[0].Title, "follower")

	// Follower must NOT receive a notification — that would be self-spam.
	assert.Empty(t, inboxFor(t, "0xfollower"))
}

func TestAddToLibrary_TriggersCreatorNotification(t *testing.T) {
	svc := newHookTestSvc(t)

	creator := "0xcreator"
	id := seedAgent(t, creator, "Saved By A Fan")

	require.NoError(t, svc.AddToLibrary("0xfan", id))

	inbox := inboxFor(t, creator)
	require.Len(t, inbox, 1, "creator must receive a save notification")
	assert.Equal(t, "social", inbox[0].Type)
	assert.Contains(t, inbox[0].Body, "Saved By A Fan")

	// Self-saves don't notify.
	require.NoError(t, svc.AddToLibrary(creator, id)) // already saved by fan, this adds creator
	// The creator must still have only 1 event — saving your own agent doesn't push.
	assert.Len(t, inboxFor(t, creator), 1, "self-save must not enqueue a duplicate notification")
}

func TestAddToLibrary_DisabledPrefDropsEvent(t *testing.T) {
	svc := newHookTestSvc(t)

	creator := "0xcreator"
	id := seedAgent(t, creator, "X")

	// Disable web/social for the creator.
	require.NoError(t, svc.UpdatePref(creator, "web", "social", false))

	require.NoError(t, svc.AddToLibrary("0xfan", id))

	assert.Empty(t, inboxFor(t, creator),
		"disabled web/social pref must drop the auto-event")
}

func TestForkAgent_NotifiesOriginalCreator(t *testing.T) {
	svc := newHookTestSvc(t)

	original := &models.Agent{
		Title:         "OG Wizard",
		Prompt:        "stub",
		CreatorWallet: "0xog",
		CharacterType: "wizard",
	}
	require.NoError(t, database.DB.Create(original).Error)

	// Seed credits for the forker so deductCredits doesn't error.
	require.NoError(t, database.DB.Create(&models.User{
		WalletAddress: "0xforker",
		Credits:       100,
	}).Error)

	fork, err := svc.ForkAgent(original.ID, "0xforker")
	require.NoError(t, err, "fork seed: %v", err)
	require.NotNil(t, fork)

	inbox := inboxFor(t, "0xog")
	require.Len(t, inbox, 1, "original creator must receive a fork notification")
	assert.Equal(t, "social", inbox[0].Type)
	assert.Contains(t, inbox[0].Title, "forked")
}

func TestNotifyOnce_DedupsWithinWindow(t *testing.T) {
	svc := newHookTestSvc(t)

	// Two follows in quick succession (the second is on the unfollow→refollow
	// path, so we explicitly delete the row in-between to bypass the
	// uniqueness guard) should produce exactly one notification because
	// notifyOnce dedups by (wallet, type, link) within the 1-hour window.
	require.NoError(t, svc.FollowUser("0xa", "0xtarget"))
	// Second insert is dedup'd by notifyOnce.
	svc.notifyOnce("0xtarget", "social", "dup", "dup", "/users/0xa")

	assert.Len(t, inboxFor(t, "0xtarget"), 1, "dedup must collapse identical (wallet,type,link) within 1h")

	// A different link bypasses dedup.
	svc.notifyOnce("0xtarget", "social", "different", "different", "/users/0xb")
	assert.Len(t, inboxFor(t, "0xtarget"), 2)
}

func TestNotifyOnce_WalletIsolation(t *testing.T) {
	svc := newHookTestSvc(t)

	// Two creators each get their own agent saved by independent fans.
	idA := seedAgent(t, "0xowna", "A")
	idB := seedAgent(t, "0xownb", "B")

	require.NoError(t, svc.AddToLibrary("0xfan1", idA))
	require.NoError(t, svc.AddToLibrary("0xfan2", idB))

	// Each creator only sees their own notification.
	inboxA := inboxFor(t, "0xowna")
	inboxB := inboxFor(t, "0xownb")
	require.Len(t, inboxA, 1)
	require.Len(t, inboxB, 1)
	assert.Contains(t, inboxA[0].Body, "A")
	assert.Contains(t, inboxB[0].Body, "B")

	// Sanity: time window so dedup logic can't accidentally drop A's row
	// thanks to a stale clock.
	assert.WithinDuration(t, time.Now(), inboxA[0].CreatedAt, 5*time.Second)
}

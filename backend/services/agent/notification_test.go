package agent

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

// notification.go is wallet-scoped: the unit tests below assert that
//   1. ListPrefs seeds the canonical 6-row default on first call,
//   2. UpdatePref upserts (insert-then-update without dup rows),
//   3. ListInbox honours id-DESC cursor pagination,
//   4. MarkRead is idempotent and wallet-scoped,
//   5. Wallets are isolated (no cross-wallet leakage),
//   6. MarkAllRead bulk-stamps every unread row.

func newNotificationTestSvc(t *testing.T) *AgentService {
	t.Helper()
	testutil.NewTestDB(t)
	return NewAgentService(nil, nil, cache.NewStore(), "", "")
}

func TestListPrefs_DefaultSeed(t *testing.T) {
	svc := newNotificationTestSvc(t)

	prefs, err := svc.ListPrefs("0xabc")
	require.NoError(t, err)
	// 3 type × 2 channel = 6 rows, all enabled.
	require.Len(t, prefs, 6, "default seed must produce 6 rows")
	for _, p := range prefs {
		assert.True(t, p.Enabled, "seeded rows must be enabled by default")
		assert.Equal(t, "0xabc", p.Wallet)
	}

	// Calling again is idempotent — must not double-seed.
	again, err := svc.ListPrefs("0xabc")
	require.NoError(t, err)
	assert.Len(t, again, 6, "second call must not duplicate rows")
}

func TestUpdatePref_UpsertAndValidation(t *testing.T) {
	svc := newNotificationTestSvc(t)

	// Seed defaults first so we exercise the update branch.
	_, err := svc.ListPrefs("0xabc")
	require.NoError(t, err)

	require.NoError(t, svc.UpdatePref("0xabc", "email", "social", false))

	// Verify the change persisted and no duplicate row was inserted.
	var prefs []models.NotificationPref
	require.NoError(t, database.DB.
		Where("wallet = ? AND channel = ? AND type = ?", "0xabc", "email", "social").
		Find(&prefs).Error)
	require.Len(t, prefs, 1, "upsert must not insert a duplicate")
	assert.False(t, prefs[0].Enabled)

	// Update path: flip back to enabled.
	require.NoError(t, svc.UpdatePref("0xabc", "email", "social", true))
	require.NoError(t, database.DB.
		Where("wallet = ? AND channel = ? AND type = ?", "0xabc", "email", "social").
		First(&prefs[0]).Error)
	assert.True(t, prefs[0].Enabled)

	// Validation: bogus channel rejected.
	err = svc.UpdatePref("0xabc", "carrier-pigeon", "social", true)
	assert.ErrorIs(t, err, ErrInvalidNotificationChannel)

	// Validation: bogus type rejected.
	err = svc.UpdatePref("0xabc", "web", "marketing", true)
	assert.ErrorIs(t, err, ErrInvalidNotificationType)
}

func TestListInbox_CursorPagination(t *testing.T) {
	svc := newNotificationTestSvc(t)

	// Insert 5 events for wallet A. Newest id wins under id-DESC ordering.
	for range 5 {
		require.NoError(t, svc.CreateNotification("0xabc", "system",
			"Title", "Body", ""))
	}

	first, err := svc.ListInbox("0xabc", 0, 3)
	require.NoError(t, err)
	require.Len(t, first, 3)
	// Newest first.
	assert.Greater(t, first[0].ID, first[1].ID)
	assert.Greater(t, first[1].ID, first[2].ID)

	// Page 2 via cursor: pass smallest id from page 1.
	cursor := first[2].ID
	second, err := svc.ListInbox("0xabc", cursor, 3)
	require.NoError(t, err)
	require.Len(t, second, 2, "remaining 2 events expected")
	for _, ev := range second {
		assert.Less(t, ev.ID, cursor, "cursor must exclude itself and later rows")
	}
}

func TestMarkRead_IdempotentAndWalletScoped(t *testing.T) {
	svc := newNotificationTestSvc(t)

	require.NoError(t, svc.CreateNotification("0xabc", "credit", "T", "B", ""))
	var ev models.NotificationEvent
	require.NoError(t, database.DB.Where("wallet = ?", "0xabc").First(&ev).Error)

	// Mark read.
	require.NoError(t, svc.MarkRead("0xabc", ev.ID))
	require.NoError(t, database.DB.First(&ev, ev.ID).Error)
	require.NotNil(t, ev.ReadAt, "ReadAt must be set after MarkRead")
	firstReadAt := *ev.ReadAt

	// Wait long enough that a re-set would change the timestamp.
	time.Sleep(5 * time.Millisecond)

	// Idempotent: marking again must not bump ReadAt (we filter on read_at IS NULL).
	require.NoError(t, svc.MarkRead("0xabc", ev.ID))
	require.NoError(t, database.DB.First(&ev, ev.ID).Error)
	assert.True(t, ev.ReadAt.Equal(firstReadAt), "second MarkRead must not reset timestamp")

	// Wallet scoping: marking another wallet's notification is a no-op (success
	// per contract — silent ignore — and the row stays unread).
	require.NoError(t, svc.CreateNotification("0xdef", "credit", "T", "B", ""))
	var foreign models.NotificationEvent
	require.NoError(t, database.DB.Where("wallet = ?", "0xdef").First(&foreign).Error)
	require.NoError(t, svc.MarkRead("0xabc", foreign.ID))
	require.NoError(t, database.DB.First(&foreign, foreign.ID).Error)
	assert.Nil(t, foreign.ReadAt, "foreign wallet's notification must remain unread")
}

func TestListInbox_WalletIsolation(t *testing.T) {
	svc := newNotificationTestSvc(t)

	require.NoError(t, svc.CreateNotification("0xabc", "social", "A", "B", ""))
	require.NoError(t, svc.CreateNotification("0xdef", "social", "X", "Y", ""))

	rowsA, err := svc.ListInbox("0xabc", 0, 50)
	require.NoError(t, err)
	require.Len(t, rowsA, 1)
	assert.Equal(t, "A", rowsA[0].Title)

	rowsB, err := svc.ListInbox("0xdef", 0, 50)
	require.NoError(t, err)
	require.Len(t, rowsB, 1)
	assert.Equal(t, "X", rowsB[0].Title)
}

func TestMarkAllRead_BulkStamps(t *testing.T) {
	svc := newNotificationTestSvc(t)

	// 3 unread + 1 already-read should not be re-stamped.
	for range 3 {
		require.NoError(t, svc.CreateNotification("0xabc", "system", "T", "B", ""))
	}
	require.NoError(t, svc.CreateNotification("0xabc", "system", "T", "B", ""))
	var rows []models.NotificationEvent
	require.NoError(t, database.DB.Where("wallet = ?", "0xabc").Order("id ASC").Find(&rows).Error)
	preset := time.Now().Add(-time.Hour)
	require.NoError(t, database.DB.Model(&rows[0]).Update("read_at", &preset).Error)

	updated, err := svc.MarkAllRead("0xabc")
	require.NoError(t, err)
	assert.EqualValues(t, 3, updated, "only the 3 unread rows should be updated")

	// All rows should now have ReadAt non-nil.
	var verified []models.NotificationEvent
	require.NoError(t, database.DB.Where("wallet = ?", "0xabc").Find(&verified).Error)
	for _, r := range verified {
		assert.NotNil(t, r.ReadAt, "every row must be read after MarkAllRead")
	}

	// Pre-set row's ReadAt should not have been overwritten.
	var preserved models.NotificationEvent
	require.NoError(t, database.DB.First(&preserved, rows[0].ID).Error)
	require.NotNil(t, preserved.ReadAt)
	assert.True(t, preserved.ReadAt.Equal(preset), "pre-existing ReadAt must be preserved")
}

func TestCreateNotification_RespectsDisabledPref(t *testing.T) {
	svc := newNotificationTestSvc(t)

	// Disable the 'system' web pref.
	require.NoError(t, svc.UpdatePref("0xabc", "web", "system", false))

	require.NoError(t, svc.CreateNotification("0xabc", "system", "muted", "should not land", ""))

	var count int64
	require.NoError(t, database.DB.Model(&models.NotificationEvent{}).
		Where("wallet = ?", "0xabc").Count(&count).Error)
	assert.EqualValues(t, 0, count, "disabled pref must drop the event")

	// Other types still flow.
	require.NoError(t, svc.CreateNotification("0xabc", "social", "kept", "yes", ""))
	require.NoError(t, database.DB.Model(&models.NotificationEvent{}).
		Where("wallet = ?", "0xabc").Count(&count).Error)
	assert.EqualValues(t, 1, count)
}

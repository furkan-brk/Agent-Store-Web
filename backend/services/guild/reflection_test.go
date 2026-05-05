package guild

// reflection_test.go — covers v3.11.4 GuildMasterReflection wallet-scoped writes.

import (
	"testing"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func newReflectionSvc(t *testing.T) *SessionService {
	t.Helper()
	testutil.NewTestDB(t)
	return NewSessionService()
}

func seedSessionForReflection(t *testing.T, wallet string) uint {
	t.Helper()
	row := models.GuildMasterSession{
		Wallet: wallet, Title: "test session",
	}
	require.NoError(t, database.DB.Create(&row).Error)
	return row.ID
}

func TestRecordReflection_PersistsRowUnderOwner(t *testing.T) {
	svc := newReflectionSvc(t)
	sid := seedSessionForReflection(t, "0xowner")

	row, err := svc.RecordReflection("0xowner", sid, 42, "ran fine, +3 saves so far")
	require.NoError(t, err)
	require.NotNil(t, row)
	assert.EqualValues(t, sid, row.SessionID)
	assert.EqualValues(t, 42, row.ExecutionID)
	assert.Contains(t, row.Summary, "ran fine")
}

func TestRecordReflection_RejectsForeignWallet(t *testing.T) {
	svc := newReflectionSvc(t)
	sid := seedSessionForReflection(t, "0xowner")

	_, err := svc.RecordReflection("0xstranger", sid, 42, "trying to graft a note")
	require.Error(t, err)
	assert.ErrorIs(t, err, ErrSessionNotFound, "foreign wallet must look identical to missing session")
}

func TestListReflections_NewestFirstAndScoped(t *testing.T) {
	svc := newReflectionSvc(t)
	sid := seedSessionForReflection(t, "0xowner")
	otherSid := seedSessionForReflection(t, "0xowner")

	_, err := svc.RecordReflection("0xowner", sid, 1, "first")
	require.NoError(t, err)
	_, err = svc.RecordReflection("0xowner", sid, 2, "second")
	require.NoError(t, err)
	_, err = svc.RecordReflection("0xowner", otherSid, 9, "other session")
	require.NoError(t, err)

	rows, err := svc.ListReflections("0xowner", sid, 20)
	require.NoError(t, err)
	require.Len(t, rows, 2)
	assert.Equal(t, "second", rows[0].Summary, "id DESC → second comes first")
}

package workspace

import (
	"encoding/json"
	"errors"
	"testing"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// validWorkflowInput returns a SaveLegendWorkflowInput with the minimum
// fields needed to pass validateWorkflowInput. Tests override fields as
// needed before calling SaveUserWorkflow.
func validWorkflowInput(id, name string) SaveLegendWorkflowInput {
	return SaveLegendWorkflowInput{
		ID:    id,
		Name:  name,
		Nodes: json.RawMessage(`[]`),
		Edges: json.RawMessage(`[]`),
	}
}

func TestSaveUserWorkflow_CreateBumpsRevisionToOne(t *testing.T) {
	testutil.NewTestDB(t)
	svc := &LegendService{}

	got, err := svc.SaveUserWorkflow("0xabc", validWorkflowInput("wf-1", "First"), nil)
	require.NoError(t, err)
	require.NotNil(t, got)

	// Default value is 1 (per the model column default), and BeforeUpdate
	// only fires on UPDATE — so a fresh INSERT lands at 1.
	assert.EqualValues(t, 1, got.RevisionID, "fresh insert must start at revisionID=1")
}

func TestSaveUserWorkflow_UpdateBumpsRevision(t *testing.T) {
	testutil.NewTestDB(t)
	svc := &LegendService{}

	first, err := svc.SaveUserWorkflow("0xabc", validWorkflowInput("wf-1", "First"), nil)
	require.NoError(t, err)
	startRev := first.RevisionID

	second, err := svc.SaveUserWorkflow("0xabc", validWorkflowInput("wf-1", "Second"), nil)
	require.NoError(t, err)

	assert.Greater(t, second.RevisionID, startRev,
		"update must bump revision (was %d, got %d)", startRev, second.RevisionID)
	assert.Equal(t, "Second", second.Name)
}

func TestSaveUserWorkflow_IfMatchMatchesAccepts(t *testing.T) {
	testutil.NewTestDB(t)
	svc := &LegendService{}

	first, _ := svc.SaveUserWorkflow("0xabc", validWorkflowInput("wf-1", "First"), nil)
	rev := first.RevisionID

	got, err := svc.SaveUserWorkflow("0xabc", validWorkflowInput("wf-1", "Second"), &rev)
	require.NoError(t, err, "matching If-Match must succeed")
	assert.Greater(t, got.RevisionID, rev)
}

func TestSaveUserWorkflow_IfMatchStaleReturnsConflict(t *testing.T) {
	testutil.NewTestDB(t)
	svc := &LegendService{}

	// First save establishes baseline.
	first, _ := svc.SaveUserWorkflow("0xabc", validWorkflowInput("wf-1", "v1"), nil)
	stale := first.RevisionID

	// Concurrent writer bumps the revision.
	_, err := svc.SaveUserWorkflow("0xabc", validWorkflowInput("wf-1", "v2"), nil)
	require.NoError(t, err)

	// Stale writer's If-Match should fail with the rich error type so the
	// handler can return 409 + current body.
	_, err = svc.SaveUserWorkflow("0xabc", validWorkflowInput("wf-1", "stale"), &stale)
	require.Error(t, err)

	var conflict *LegendRevisionMismatchError
	require.True(t, errors.As(err, &conflict), "expected LegendRevisionMismatchError, got %T", err)
	require.NotNil(t, conflict.Current)
	assert.Equal(t, "v2", conflict.Current.Name, "conflict body must carry the current state")
	assert.Greater(t, conflict.Current.RevisionID, stale)
}

func TestSaveUserWorkflow_IfMatchOnCreateIsIgnored(t *testing.T) {
	testutil.NewTestDB(t)
	svc := &LegendService{}

	// First save with a non-zero If-Match on a brand-new ID — should still
	// create successfully because there's no existing row to compare against.
	someRev := uint64(42)
	got, err := svc.SaveUserWorkflow("0xabc", validWorkflowInput("wf-new", "Fresh"), &someRev)
	require.NoError(t, err)
	assert.EqualValues(t, 1, got.RevisionID)
}

func TestSaveUserWorkflow_NilIfMatchPreservesLegacyBehaviour(t *testing.T) {
	testutil.NewTestDB(t)
	svc := &LegendService{}

	// Two updates back-to-back without If-Match — should both succeed
	// (last-write-wins) so older clients keep working.
	first, _ := svc.SaveUserWorkflow("0xabc", validWorkflowInput("wf-1", "a"), nil)
	second, err := svc.SaveUserWorkflow("0xabc", validWorkflowInput("wf-1", "b"), nil)
	require.NoError(t, err)
	assert.Greater(t, second.RevisionID, first.RevisionID)
	assert.Equal(t, "b", second.Name)
}

func TestSaveUserWorkflow_ConflictIsScopedPerWallet(t *testing.T) {
	testutil.NewTestDB(t)
	svc := &LegendService{}

	// Different wallets can both have a workflow with the same client ID.
	// A stale revision from wallet A must NOT be reported as a conflict
	// against wallet B's row.
	first, _ := svc.SaveUserWorkflow("0xaaa", validWorkflowInput("wf-1", "alice"), nil)
	_, _ = svc.SaveUserWorkflow("0xbbb", validWorkflowInput("wf-1", "bob"), nil)

	// Stale alice revision: must conflict against alice, not against bob.
	staleAlice := first.RevisionID
	_, err := svc.SaveUserWorkflow("0xaaa", validWorkflowInput("wf-1", "alice2"), &staleAlice)
	require.NoError(t, err, "fresh save against alice with current rev should pass")
}

func TestListUserWorkflows_IncludesRevisionID(t *testing.T) {
	testutil.NewTestDB(t)
	svc := &LegendService{}

	_, _ = svc.SaveUserWorkflow("0xabc", validWorkflowInput("wf-1", "A"), nil)
	_, _ = svc.SaveUserWorkflow("0xabc", validWorkflowInput("wf-1", "B"), nil)

	list, err := svc.ListUserWorkflows("0xabc")
	require.NoError(t, err)
	require.Len(t, list, 1)
	// After two saves the revisionID is at least 2 (insert=1, one update bump).
	assert.GreaterOrEqual(t, list[0].RevisionID, uint64(2))
}

func TestSaveUserWorkflow_RejectsMalformedNodesJSON(t *testing.T) {
	testutil.NewTestDB(t)
	svc := &LegendService{}

	bad := SaveLegendWorkflowInput{
		ID:    "wf-bad",
		Name:  "Bad",
		Nodes: json.RawMessage(`{not-json`),
		Edges: json.RawMessage(`[]`),
	}
	_, err := svc.SaveUserWorkflow("0xabc", bad, nil)
	require.Error(t, err, "malformed nodes JSON must be rejected by validateWorkflowInput")
}

func TestRecordToDTO_NormalisesEmptyJSON(t *testing.T) {
	// recordToDTO is a pure helper; covering it here so the empty-string
	// → "[]" branch isn't only tested transitively via Save.
	rec := &models.UserLegendWorkflow{
		ClientID:   "wf-empty",
		Name:       "Empty",
		NodesJSON:  "",
		EdgesJSON:  "",
		RevisionID: 7,
	}
	dto := recordToDTO(rec)
	require.NotNil(t, dto)
	assert.Equal(t, "wf-empty", dto.ID)
	assert.EqualValues(t, 7, dto.RevisionID)
	assert.Equal(t, json.RawMessage("[]"), dto.Nodes)
	assert.Equal(t, json.RawMessage("[]"), dto.Edges)
}

func TestSaveUserWorkflow_PersistsToDatabase(t *testing.T) {
	testutil.NewTestDB(t)
	svc := &LegendService{}

	_, err := svc.SaveUserWorkflow("0xabc", validWorkflowInput("wf-1", "Persisted"), nil)
	require.NoError(t, err)

	// Round-trip via raw DB to make sure RevisionID + name actually hit storage.
	var row models.UserLegendWorkflow
	require.NoError(t, database.DB.
		Where("user_wallet = ? AND client_id = ?", "0xabc", "wf-1").
		First(&row).Error)
	assert.Equal(t, "Persisted", row.Name)
	assert.EqualValues(t, 1, row.RevisionID)
}

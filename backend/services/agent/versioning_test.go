package agent

import (
	"strings"
	"testing"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/cache"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/lib/pq"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// newVersioningTestSvc spins up an in-memory DB + service. aiClient is nil —
// the version snapshot path is pure DB work and never touches the AI pipeline.
func newVersioningTestSvc(t *testing.T) *AgentService {
	t.Helper()
	testutil.NewTestDB(t)
	return NewAgentService(nil, nil, cache.NewStore(), "", "")
}

func seedOwnedAgent(t *testing.T, _ *AgentService, wallet, title string) uint {
	t.Helper()
	a := &models.Agent{
		Title:         title,
		Prompt:        "v1 prompt",
		Description:   "v1 description",
		CreatorWallet: strings.ToLower(wallet),
		CharacterType: "wizard",
		Tags:          pq.StringArray{"alpha"},
		CharacterData: `{"traits":["clever"],"profile":{"mood":"calm","role_purpose":"help"},"stats":{"power":7}}`,
	}
	require.NoError(t, database.DB.Create(a).Error)
	return a.ID
}

func TestSnapshotAgentVersion_OnUpdate(t *testing.T) {
	svc := newVersioningTestSvc(t)
	id := seedOwnedAgent(t, svc, "0xowner", "Original")

	// Update via the public path so the snapshot hook fires.
	newPrompt := "v2 prompt with material change"
	_, err := svc.UpdateAgent(id, "0xowner", &UpdateAgentRequest{Prompt: &newPrompt}, nil)
	require.NoError(t, err)

	// Exactly one snapshot row, version=1, captures the post-update state.
	var rows []models.AgentVersion
	require.NoError(t, database.DB.Where("agent_id = ?", id).Find(&rows).Error)
	require.Len(t, rows, 1, "first UpdateAgent must produce one snapshot")
	assert.Equal(t, 1, rows[0].Version)
	assert.Contains(t, rows[0].FieldsJSON, "v2 prompt", "snapshot must include the updated prompt")
}

func TestListAgentVersions_OrderingAndCap(t *testing.T) {
	svc := newVersioningTestSvc(t)
	id := seedOwnedAgent(t, svc, "0xowner", "X")

	// Make 22 updates — cap is 20, so the oldest 2 should evict.
	for i := range 22 {
		newPrompt := "rev " + string(rune('A'+i%26)) + " — extra padding to clear length min"
		_, err := svc.UpdateAgent(id, "0xowner", &UpdateAgentRequest{Prompt: &newPrompt}, nil)
		require.NoError(t, err)
	}

	versions, err := svc.ListAgentVersions("0xowner", id)
	require.NoError(t, err)
	assert.Len(t, versions, maxAgentVersions, "must cap at maxAgentVersions")
	// Newest first — first row's version is the highest.
	assert.Equal(t, 22, versions[0].Version, "list ordering must be newest first")
	assert.Equal(t, 3, versions[len(versions)-1].Version, "oldest 2 must have been pruned")
}

func TestGetAgentVersion_OwnerOnly(t *testing.T) {
	svc := newVersioningTestSvc(t)
	id := seedOwnedAgent(t, svc, "0xowner", "X")

	newDesc := "edited description with enough body to pass min len"
	_, err := svc.UpdateAgent(id, "0xowner", &UpdateAgentRequest{Description: &newDesc}, nil)
	require.NoError(t, err)

	// Owner read passes.
	got, err := svc.GetAgentVersion("0xowner", id, 1)
	require.NoError(t, err)
	require.NotNil(t, got)
	assert.Equal(t, 1, got.Version)
	require.NotNil(t, got.Fields.Description)
	assert.Equal(t, newDesc, *got.Fields.Description)

	// Non-owner gets "agent not found" — never leaks existence.
	_, err = svc.GetAgentVersion("0xstranger", id, 1)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "unauthorized")

	// Missing version id surfaces ErrAgentVersionNotFound for owner.
	_, err = svc.GetAgentVersion("0xowner", id, 999)
	require.ErrorIs(t, err, ErrAgentVersionNotFound)
}

func TestRollbackAgentVersion_RestoresFieldsAndCreatesNewVersions(t *testing.T) {
	svc := newVersioningTestSvc(t)
	id := seedOwnedAgent(t, svc, "0xowner", "Original Title")

	// v1 = first edit.
	v2Prompt := "second prompt with more body to clear min"
	_, err := svc.UpdateAgent(id, "0xowner", &UpdateAgentRequest{Prompt: &v2Prompt}, nil)
	require.NoError(t, err)

	// v2 = second edit (this is what we'll rollback away from).
	v3Prompt := "third prompt with even more body to clear min"
	_, err = svc.UpdateAgent(id, "0xowner", &UpdateAgentRequest{Prompt: &v3Prompt}, nil)
	require.NoError(t, err)

	// Snapshot v1's prompt for the assertion below.
	v1, err := svc.GetAgentVersion("0xowner", id, 1)
	require.NoError(t, err)
	require.NotNil(t, v1.Fields.Prompt)
	wantPrompt := *v1.Fields.Prompt

	// Rollback to v1 — should bump version count by 2 (current snapshot + post-rollback).
	beforeCount := int64(0)
	database.DB.Model(&models.AgentVersion{}).Where("agent_id = ?", id).Count(&beforeCount)

	got, err := svc.RollbackAgentVersion("0xowner", id, 1)
	require.NoError(t, err)
	require.NotNil(t, got)
	assert.Equal(t, wantPrompt, got.Prompt, "rolled-back prompt must equal the historical snapshot")

	afterCount := int64(0)
	database.DB.Model(&models.AgentVersion{}).Where("agent_id = ?", id).Count(&afterCount)
	assert.Equal(t, beforeCount+2, afterCount, "rollback must add 2 snapshots: pre-rollback current + post-rollback")
}

func TestRollbackAgentVersion_NonOwnerRejected(t *testing.T) {
	svc := newVersioningTestSvc(t)
	id := seedOwnedAgent(t, svc, "0xalice", "Alice's")

	newPrompt := "v2 prompt long enough to satisfy validation"
	_, err := svc.UpdateAgent(id, "0xalice", &UpdateAgentRequest{Prompt: &newPrompt}, nil)
	require.NoError(t, err)

	// Bob tries to roll Alice's agent back. Must fail; agent must remain at v2.
	_, err = svc.RollbackAgentVersion("0xbob", id, 1)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "unauthorized")

	var refreshed models.Agent
	require.NoError(t, database.DB.First(&refreshed, id).Error)
	assert.Equal(t, newPrompt, refreshed.Prompt, "wallet isolation: agent stays at the latest version")
}

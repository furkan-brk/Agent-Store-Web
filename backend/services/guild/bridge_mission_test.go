package guild

import (
	"encoding/json"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gorm.io/gorm"
)

// newBridge returns a bridge wired against the in-memory test DB. The
// bridge needs a SessionService (for ToMission/ToLegend on sessions) but
// MissionToLegend doesn't touch it — passing a fresh instance keeps the
// constructor happy without any setup.
func newBridge(t *testing.T) *BridgeService {
	t.Helper()
	testutil.NewTestDB(t)
	return NewBridgeService(NewSessionService())
}

func insertMission(t *testing.T, wallet, prompt string) models.UserMission {
	t.Helper()
	m := models.UserMission{
		UserWallet: strings.ToLower(wallet),
		ClientID:   "test-mission-" + wallet,
		Title:      "Test Mission",
		Slug:       "test-mission",
		Prompt:     prompt,
		CreatedAt:  time.Now(),
	}
	require.NoError(t, database.DB.Create(&m).Error)
	return m
}

func TestMissionToLegend_RoundTripCreatesWorkflow(t *testing.T) {
	br := newBridge(t)
	wallet := "0xabc123"
	m := insertMission(t, wallet, "You are a careful PR reviewer. Summarise diffs.")

	res, err := br.MissionToLegend(wallet, m.ID)
	require.NoError(t, err)
	require.NotNil(t, res)
	assert.NotEmpty(t, res.WorkflowID)
	assert.Contains(t, res.WorkflowName, "Test Mission")
	assert.Equal(t, 3, res.NodeCount, "START + agent + END = 3 nodes")
	assert.Equal(t, 2, res.EdgeCount, "fan-in/fan-out = 2 edges")

	// Workflow row should exist on disk for the same wallet.
	var wf models.UserLegendWorkflow
	require.NoError(t, database.DB.
		Where("client_id = ? AND user_wallet = ?", res.WorkflowID, strings.ToLower(wallet)).
		First(&wf).Error)
	assert.Equal(t, res.WorkflowName, wf.Name)
}

func TestMissionToLegend_WrongWalletNotFound(t *testing.T) {
	br := newBridge(t)
	owner := "0xowner"
	intruder := "0xintruder"
	m := insertMission(t, owner, "valid prompt")

	_, err := br.MissionToLegend(intruder, m.ID)
	require.Error(t, err)
	assert.True(t, errors.Is(err, gorm.ErrRecordNotFound),
		"cross-wallet mission lookup must surface as record-not-found")
}

func TestMissionToLegend_EmptyPromptRejected(t *testing.T) {
	br := newBridge(t)
	wallet := "0xabc"
	m := insertMission(t, wallet, "   ") // whitespace-only

	_, err := br.MissionToLegend(wallet, m.ID)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "no prompt", "whitespace prompt must be rejected with descriptive error")
}

func TestMissionToLegend_WorkflowNodesAreValidJSON(t *testing.T) {
	br := newBridge(t)
	wallet := "0xabc"
	m := insertMission(t, wallet, "real prompt body that survives the round trip")

	res, err := br.MissionToLegend(wallet, m.ID)
	require.NoError(t, err)

	var wf models.UserLegendWorkflow
	require.NoError(t, database.DB.
		Where("client_id = ?", res.WorkflowID).First(&wf).Error)

	// nodes_json must parse to a list with 3 entries (start/agent/end).
	var nodes []map[string]any
	require.NoError(t, json.Unmarshal([]byte(wf.NodesJSON), &nodes))
	require.Len(t, nodes, 3)
	assert.Equal(t, "start", nodes[0]["type"])
	assert.Equal(t, "agent", nodes[1]["type"])
	assert.Equal(t, "end", nodes[2]["type"])
	assert.Equal(t, "real prompt body that survives the round trip", nodes[1]["prompt"],
		"agent node carries the original mission prompt")

	// edges_json must parse to a list with 2 entries connecting start→agent→end.
	var edges []map[string]any
	require.NoError(t, json.Unmarshal([]byte(wf.EdgesJSON), &edges))
	require.Len(t, edges, 2)
}

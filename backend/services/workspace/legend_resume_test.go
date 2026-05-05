package workspace

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/agentstore/backend/services/workspace/client"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// fakeAgentBackend stands in for the Agent Service's `/internal/*` endpoints.
// It records call counts so tests can verify resume behaviour (e.g. credits
// only deducted once on the resumed run, not the original failed run).
type fakeAgentBackend struct {
	credits     int64
	deductCalls int32
	chatBody    string
	chatErr     bool
}

func newFakeAgentBackend(t *testing.T, credits int64) (*fakeAgentBackend, *httptest.Server) {
	t.Helper()
	fab := &fakeAgentBackend{credits: credits}
	mux := http.NewServeMux()

	mux.HandleFunc("/internal/credits/", func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"credits": fab.credits,
			"wallet":  strings.TrimPrefix(r.URL.Path, "/internal/credits/"),
		})
	})
	mux.HandleFunc("/internal/credits/deduct", func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&fab.deductCalls, 1)
		var body map[string]any
		_ = json.NewDecoder(r.Body).Decode(&body)
		if amt, ok := body["amount"].(float64); ok {
			fab.credits -= int64(amt)
		}
		_ = json.NewEncoder(w).Encode(map[string]any{"ok": true})
	})
	mux.HandleFunc("/internal/agents/", func(w http.ResponseWriter, r *http.Request) {
		// Matches both /internal/agents/:id and /internal/agents/:id/increment-use.
		if strings.HasSuffix(r.URL.Path, "/increment-use") {
			_ = json.NewEncoder(w).Encode(map[string]any{"ok": true})
			return
		}
		// Return a stub agent — the test only cares that the call succeeds.
		_ = json.NewEncoder(w).Encode(map[string]any{
			"id":     1,
			"prompt": "stub prompt",
			"title":  "Stub Agent",
		})
	})

	srv := httptest.NewServer(mux)
	t.Cleanup(srv.Close)
	return fab, srv
}

// makeFailedExecution seeds a workflow + a half-finished execution into the
// test DB so ResumeExecution can pick up where the original run died.
//
// The execution has:
//   - one `start` node (already completed in checkpoints)
//   - one `end` node (still pending)
//
// No agent call is needed when resuming because both nodes are non-AI types,
// so AgentClient is never invoked on the resume path.
func makeFailedExecution(t *testing.T, wallet string) *models.WorkflowExecution {
	t.Helper()
	wallet = strings.ToLower(wallet)

	// Insert workflow definition first.
	wf := &models.UserLegendWorkflow{
		UserWallet: wallet,
		ClientID:   "wf-resume",
		Name:       "Resumable",
		NodesJSON: `[
			{"id":"n1","type":"start","label":"Start","x":0,"y":0,"ref_id":""},
			{"id":"n2","type":"end","label":"End","x":1,"y":0,"ref_id":""}
		]`,
		EdgesJSON: `[{"id":"e1","from":"n1","to":"n2"}]`,
	}
	require.NoError(t, database.DB.Create(wf).Error)

	// Insert execution with checkpoint where the start node finished but the
	// end node never ran. Status = "failed" mimics a real interrupted run.
	checkpoints := map[string]nodeCheckpoint{
		"n1": {Status: "completed", Output: "stub-input", DurationMs: 5},
	}
	statesBlob, _ := json.Marshal(checkpoints)
	exec := &models.WorkflowExecution{
		UserWallet:     wallet,
		WorkflowID:     "wf-resume",
		WorkflowName:   "Resumable",
		Status:         "failed",
		InputMessage:   "stub-input",
		TotalNodes:     2,
		CompletedNodes: 1,
		NodeStates:     string(statesBlob),
		ErrorMessage:   "boom",
		NodeResults:    `[]`,
	}
	require.NoError(t, database.DB.Create(exec).Error)
	return exec
}

func TestNodeStates_JSONRoundTrip(t *testing.T) {
	checkpoints := map[string]nodeCheckpoint{
		"n1": {Status: "completed", Output: "hello", DurationMs: 10},
		"n2": {Status: "failed", Output: "", Error: "timeout", DurationMs: 5000},
	}
	blob, err := json.Marshal(checkpoints)
	require.NoError(t, err)

	got := loadNodeStates(string(blob))
	require.Len(t, got, 2)
	assert.Equal(t, "completed", got["n1"].Status)
	assert.Equal(t, "hello", got["n1"].Output)
	assert.Equal(t, "failed", got["n2"].Status)
	assert.Equal(t, "timeout", got["n2"].Error)
	assert.EqualValues(t, 5000, got["n2"].DurationMs)
}

func TestLoadNodeStates_EmptyAndMalformed(t *testing.T) {
	// Empty string → zero map (older executions stored no checkpoints).
	got := loadNodeStates("")
	assert.NotNil(t, got)
	assert.Len(t, got, 0)

	// Malformed JSON → empty map (fail-soft so resume can still re-run all nodes).
	got = loadNodeStates(`{not json`)
	assert.NotNil(t, got)
	assert.Len(t, got, 0)
}

func TestResumeExecution_NotFoundReturns404(t *testing.T) {
	testutil.NewTestDB(t)
	svc := &LegendService{}

	_, err := svc.ResumeExecution("0xabc", 9999)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "execution not found",
		"missing execution should surface a not-found error so the handler can map to 404")
}

func TestResumeExecution_OwnershipScopedPerWallet(t *testing.T) {
	testutil.NewTestDB(t)
	svc := &LegendService{}

	// Insert an execution for alice…
	makeFailedExecution(t, "0xalice")

	// …then ask to resume it as bob. Must look like "not found" — never leak
	// existence of another wallet's execution.
	var aliceExec models.WorkflowExecution
	require.NoError(t, database.DB.
		Where("user_wallet = ?", "0xalice").
		First(&aliceExec).Error)

	_, err := svc.ResumeExecution("0xbob", aliceExec.ID)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "execution not found")
}

func TestResumeExecution_AlreadyCompletedIsNoOp(t *testing.T) {
	testutil.NewTestDB(t)
	svc := &LegendService{}

	// Insert a completed execution. Resume should return the existing DTO
	// without touching credits or re-running anything.
	exec := &models.WorkflowExecution{
		UserWallet:     "0xabc",
		WorkflowID:     "wf-done",
		WorkflowName:   "Done",
		Status:         "completed",
		InputMessage:   "x",
		FinalOutput:    "y",
		TotalNodes:     1,
		CompletedNodes: 1,
		NodeResults:    `[]`,
	}
	require.NoError(t, database.DB.Create(exec).Error)

	dto, err := svc.ResumeExecution("0xabc", exec.ID)
	require.NoError(t, err)
	require.NotNil(t, dto)
	assert.Equal(t, "completed", dto.Status)
	assert.Equal(t, "y", dto.FinalOutput)
}

func TestResumeExecution_PartialReuseSkipsCompletedNodes(t *testing.T) {
	testutil.NewTestDB(t)

	// Stand up a fake Agent Service so AgentClient.GetCredits/DeductCredits
	// have somewhere real to dial. We seed enough credits to cover the resume.
	fab, srv := newFakeAgentBackend(t, 100)

	svc := &LegendService{
		agentClient: client.NewAgentClient(srv.URL),
	}

	// Failed execution where n1 is already completed and n2 (end) is pending.
	makeFailedExecution(t, "0xabc")

	var exec models.WorkflowExecution
	require.NoError(t, database.DB.Where("user_wallet = ?", "0xabc").First(&exec).Error)

	dto, err := svc.ResumeExecution("0xabc", exec.ID)
	require.NoError(t, err)
	require.NotNil(t, dto)
	assert.Equal(t, "completed", dto.Status, "resume should drive execution to completed")

	// Reload to verify NodeStates now contains BOTH nodes.
	var refreshed models.WorkflowExecution
	require.NoError(t, database.DB.First(&refreshed, exec.ID).Error)
	cps := loadNodeStates(refreshed.NodeStates)
	assert.Equal(t, "completed", cps["n1"].Status, "n1 must remain completed (was reused, not re-run)")
	assert.Equal(t, "completed", cps["n2"].Status, "n2 should now be completed (re-run on resume)")

	// Workflow has no agent nodes → no credit deduction expected.
	assert.EqualValues(t, 0, atomic.LoadInt32(&fab.deductCalls),
		"workflow with zero agent nodes should not call DeductCredits")
}

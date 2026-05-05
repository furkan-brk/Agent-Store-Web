package workspace

// execute_workflow_test.go — regression coverage for ExecuteWorkflow + ResumeExecution.
//
// These paths were previously uncovered: the v3.11.4 T4 per-stage timeout/retry,
// the v3.11.3 node checkpoint write-during-execution, and the early validation
// gates (empty nodes, unknown workflow, insufficient credits) all lacked tests.
//
// AI calls are stubbed via an httptest.Server that mounts both the Agent
// Service `/internal/*` endpoints and the AI Pipeline `/internal/chat`
// endpoint. The same server is wired into AgentClient and AIClient so a
// single fake covers both halves of the call graph.

import (
	"encoding/json"
	"fmt"
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

// fakeBackend implements both the Agent Service and AI Pipeline test stubs.
// All three counters use atomics so parallel goroutines (the per-stage retry
// path in ExecuteWorkflow) can't race the assertions.
type fakeBackend struct {
	credits     int64
	deductCalls int32
	chatCalls   int32
	chatFail    bool   // when true, /internal/chat returns 500 to force node failure
	chatReply   string // body returned on success ("" → "stub-response")
}

func newFakeBackend(t *testing.T, credits int64) (*fakeBackend, *httptest.Server) {
	t.Helper()
	fb := &fakeBackend{credits: credits, chatReply: "stub-response"}
	mux := http.NewServeMux()

	// ── Agent Service stubs ────────────────────────────────────────────
	mux.HandleFunc("/internal/credits/deduct", func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&fb.deductCalls, 1)
		var body map[string]any
		_ = json.NewDecoder(r.Body).Decode(&body)
		if amt, ok := body["amount"].(float64); ok {
			atomic.AddInt64(&fb.credits, -int64(amt))
		}
		_ = json.NewEncoder(w).Encode(map[string]any{"ok": true})
	})
	mux.HandleFunc("/internal/credits/", func(w http.ResponseWriter, r *http.Request) {
		// Bare /internal/credits/<wallet> — credit balance lookup.
		_ = json.NewEncoder(w).Encode(map[string]any{
			"credits": atomic.LoadInt64(&fb.credits),
			"wallet":  strings.TrimPrefix(r.URL.Path, "/internal/credits/"),
		})
	})
	mux.HandleFunc("/internal/agents/", func(w http.ResponseWriter, r *http.Request) {
		if strings.HasSuffix(r.URL.Path, "/increment-use") {
			_ = json.NewEncoder(w).Encode(map[string]any{"ok": true})
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"id":     1,
			"prompt": "stub agent prompt",
			"title":  "Stub Agent",
		})
	})

	// ── AI Pipeline stub ───────────────────────────────────────────────
	mux.HandleFunc("/internal/chat", func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&fb.chatCalls, 1)
		if fb.chatFail {
			http.Error(w, "ai upstream boom", http.StatusInternalServerError)
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]any{"response": fb.chatReply})
	})

	srv := httptest.NewServer(mux)
	t.Cleanup(srv.Close)
	return fb, srv
}

// newWiredService builds a LegendService with both clients pointed at the
// fake server. The mission service is empty (sufficient for non-mission
// nodes); claudeClient stays nil so engine="claude" falls through to the
// stubbed AI pipeline.
func newWiredService(srvURL string) *LegendService {
	return &LegendService{
		aiClient:    client.NewAIClient(srvURL),
		agentClient: client.NewAgentClient(srvURL),
		missionSvc:  NewMissionService(),
	}
}

// startEndOnlyNodes returns the JSON for a minimal valid workflow:
// one start → one end, nothing in between.
func startEndOnlyNodes() (nodesJSON, edgesJSON string) {
	nodesJSON = `[
		{"id":"n1","type":"start","label":"Start","x":0,"y":0,"ref_id":""},
		{"id":"n2","type":"end","label":"End","x":1,"y":0,"ref_id":""}
	]`
	edgesJSON = `[{"id":"e1","from":"n1","to":"n2"}]`
	return
}

// agentNodeWorkflow returns nodes/edges for: start → agent(claude/haiku) → end.
// Engine is "claude" + model "haiku" so requiredCredits = claude.CreditCost["haiku"] = 1.
// claudeClient is nil in tests → execution falls through to the stubbed
// AI pipeline /internal/chat endpoint, but the cost is still computed
// from the metadata, not the runtime engine choice.
func haikuAgentWorkflow() (nodesJSON, edgesJSON string) {
	nodesJSON = `[
		{"id":"n1","type":"start","label":"Start","x":0,"y":0,"ref_id":""},
		{"id":"n2","type":"agent","label":"A","x":1,"y":0,"ref_id":"1","metadata":{"engine":"claude","model":"haiku","prompt":"override"}},
		{"id":"n3","type":"end","label":"End","x":2,"y":0,"ref_id":""}
	]`
	edgesJSON = `[
		{"id":"e1","from":"n1","to":"n2"},
		{"id":"e2","from":"n2","to":"n3"}
	]`
	return
}

// seedWorkflow inserts a UserLegendWorkflow row directly. Bypasses
// SaveUserWorkflow so we don't trigger the version-snapshot side effect.
func seedWorkflow(t *testing.T, wallet, clientID, name, nodesJSON, edgesJSON string) {
	t.Helper()
	wf := &models.UserLegendWorkflow{
		UserWallet: strings.ToLower(wallet),
		ClientID:   clientID,
		Name:       name,
		NodesJSON:  nodesJSON,
		EdgesJSON:  edgesJSON,
	}
	require.NoError(t, database.DB.Create(wf).Error)
}

// ─── 1. Empty nodes ─────────────────────────────────────────────────────────

// TestExecuteWorkflow_EmptyNodes — a workflow with zero nodes must fail
// validation (need exactly 1 start + ≥1 end), so ExecuteWorkflow returns an
// error before touching credits or creating an execution row. We assert
// (a) the error path is taken and (b) no WorkflowExecution row was written.
func TestExecuteWorkflow_EmptyNodes(t *testing.T) {
	testutil.NewTestDB(t)
	_, srv := newFakeBackend(t, 100)
	svc := newWiredService(srv.URL)

	seedWorkflow(t, "0xabc", "wf-empty", "Empty", `[]`, `[]`)

	dto, err := svc.ExecuteWorkflow("0xabc", ExecuteWorkflowInput{InputMessage: "hi"}, "wf-empty")
	require.Error(t, err, "empty workflow must fail validation")
	assert.Nil(t, dto)
	assert.Contains(t, err.Error(), "invalid workflow structure")

	// No execution row should exist for a workflow that never started.
	var count int64
	require.NoError(t, database.DB.Model(&models.WorkflowExecution{}).Count(&count).Error)
	assert.EqualValues(t, 0, count, "validation failure must not persist an execution row")
}

// ─── 2. Start + End only ────────────────────────────────────────────────────

// TestExecuteWorkflow_StartEndOnly — minimal valid graph. Both start and
// end nodes are passthroughs (no agent calls), so no credits are required
// and DeductCredits must NOT be called even though the run completes.
func TestExecuteWorkflow_StartEndOnly(t *testing.T) {
	testutil.NewTestDB(t)
	fb, srv := newFakeBackend(t, 100)
	svc := newWiredService(srv.URL)

	nodes, edges := startEndOnlyNodes()
	seedWorkflow(t, "0xabc", "wf-noop", "Noop", nodes, edges)

	dto, err := svc.ExecuteWorkflow("0xabc", ExecuteWorkflowInput{InputMessage: "hello"}, "wf-noop")
	require.NoError(t, err)
	require.NotNil(t, dto)
	assert.Equal(t, "completed", dto.Status)
	assert.EqualValues(t, 0, dto.CreditsUsed, "no agent nodes → zero credits charged")
	assert.EqualValues(t, 0, atomic.LoadInt32(&fb.deductCalls),
		"DeductCredits must not be called when requiredCredits == 0")

	// Final output is the start input echoed through end.
	assert.Equal(t, "hello", dto.FinalOutput)
}

// ─── 3. Unknown workflow ────────────────────────────────────────────────────

// TestExecuteWorkflow_UnknownWorkflow — workflow ID that doesn't exist
// returns a "workflow not found" error. The wallet scoping means even
// another user's workflow ID looks unknown.
func TestExecuteWorkflow_UnknownWorkflow(t *testing.T) {
	testutil.NewTestDB(t)
	_, srv := newFakeBackend(t, 100)
	svc := newWiredService(srv.URL)

	dto, err := svc.ExecuteWorkflow("0xabc", ExecuteWorkflowInput{InputMessage: "x"}, "wf-nope")
	require.Error(t, err)
	assert.Nil(t, dto)
	assert.Contains(t, err.Error(), "workflow not found")
}

// ─── 4. Insufficient credits ────────────────────────────────────────────────

// TestExecuteWorkflow_InsufficientCredits — wallet has 0 credits but the
// haiku-agent workflow requires 1. ExecuteWorkflow must reject before
// running any node and before creating the execution row.
func TestExecuteWorkflow_InsufficientCredits(t *testing.T) {
	testutil.NewTestDB(t)
	fb, srv := newFakeBackend(t, 0) // wallet has zero credits
	svc := newWiredService(srv.URL)

	nodes, edges := haikuAgentWorkflow()
	seedWorkflow(t, "0xabc", "wf-broke", "Broke", nodes, edges)

	dto, err := svc.ExecuteWorkflow("0xabc",
		ExecuteWorkflowInput{InputMessage: "hi", Engine: "claude"}, "wf-broke")
	require.Error(t, err)
	assert.Nil(t, dto)
	assert.Contains(t, err.Error(), "insufficient credits")
	assert.Contains(t, err.Error(), "have 0")
	assert.Contains(t, err.Error(), "need 1") // haiku = 1 credit

	// AI pipeline must NOT have been called — the gate fired earlier.
	assert.EqualValues(t, 0, atomic.LoadInt32(&fb.chatCalls),
		"insufficient-credits gate must fire before any AI invocation")
	// And no execution row should exist for a rejected request.
	var count int64
	require.NoError(t, database.DB.Model(&models.WorkflowExecution{}).Count(&count).Error)
	assert.EqualValues(t, 0, count)
}

// ─── 5. Credit deduction (happy path) ───────────────────────────────────────

// TestExecuteWorkflow_CreditDeduction — wallet has 5 credits, workflow has
// one haiku-agent node (cost 1). After successful execution, DeductCredits
// is called exactly once with amount=1 and the DTO reports CreditsUsed=1.
func TestExecuteWorkflow_CreditDeduction(t *testing.T) {
	testutil.NewTestDB(t)
	fb, srv := newFakeBackend(t, 5)
	svc := newWiredService(srv.URL)

	nodes, edges := haikuAgentWorkflow()
	seedWorkflow(t, "0xabc", "wf-pay", "Pay", nodes, edges)

	dto, err := svc.ExecuteWorkflow("0xabc",
		ExecuteWorkflowInput{InputMessage: "ping", Engine: "claude"}, "wf-pay")
	require.NoError(t, err)
	require.NotNil(t, dto)
	assert.Equal(t, "completed", dto.Status)
	assert.EqualValues(t, 1, dto.CreditsUsed, "haiku agent node = 1 credit")

	assert.EqualValues(t, 1, atomic.LoadInt32(&fb.deductCalls),
		"DeductCredits should be called exactly once on success")
	// Fake backend tracks remaining credits — should be 5 - 1 = 4.
	assert.EqualValues(t, 4, atomic.LoadInt64(&fb.credits))
}

// ─── 6. Node checkpoints written ────────────────────────────────────────────

// TestExecuteWorkflow_NodeCheckpointWritten — after a successful run, the
// row's NodeStates column must be a non-empty JSON object keyed by node id
// and every node must show status="completed". This is the v3.11.3 resume
// pre-condition: without checkpoints, ResumeExecution can't reuse work.
func TestExecuteWorkflow_NodeCheckpointWritten(t *testing.T) {
	testutil.NewTestDB(t)
	_, srv := newFakeBackend(t, 5)
	svc := newWiredService(srv.URL)

	nodes, edges := haikuAgentWorkflow()
	seedWorkflow(t, "0xabc", "wf-cp", "Checkpointed", nodes, edges)

	dto, err := svc.ExecuteWorkflow("0xabc",
		ExecuteWorkflowInput{InputMessage: "ping", Engine: "claude"}, "wf-cp")
	require.NoError(t, err)
	require.NotNil(t, dto)

	var row models.WorkflowExecution
	require.NoError(t, database.DB.First(&row, dto.ID).Error)
	require.NotEmpty(t, row.NodeStates, "NodeStates must be persisted for resume support")

	cps := loadNodeStates(row.NodeStates)
	require.Len(t, cps, 3, "all 3 nodes (start, agent, end) must be checkpointed")
	for id, cp := range cps {
		assert.Equal(t, "completed", cp.Status,
			"node %s must be marked completed in checkpoints (got %q)", id, cp.Status)
	}
}

// ─── 7. Status = completed on success ──────────────────────────────────────

// TestExecuteWorkflow_StatusCompleted — explicit assertion on the persisted
// status column (not just the DTO). Belt-and-braces against a future bug
// where the DTO is computed from in-memory state but the DB row is stale.
func TestExecuteWorkflow_StatusCompleted(t *testing.T) {
	testutil.NewTestDB(t)
	_, srv := newFakeBackend(t, 5)
	svc := newWiredService(srv.URL)

	nodes, edges := startEndOnlyNodes()
	seedWorkflow(t, "0xabc", "wf-ok", "OK", nodes, edges)

	dto, err := svc.ExecuteWorkflow("0xabc",
		ExecuteWorkflowInput{InputMessage: "x"}, "wf-ok")
	require.NoError(t, err)
	require.NotNil(t, dto)

	var row models.WorkflowExecution
	require.NoError(t, database.DB.First(&row, dto.ID).Error)
	assert.Equal(t, "completed", row.Status, "DB row status must be 'completed'")
	assert.NotNil(t, row.FinishedAt, "FinishedAt must be set on completion")
}

// ─── 8. Status = failed when a node errors ─────────────────────────────────

// TestExecuteWorkflow_StatusFailed — flip the AI pipeline stub to return
// 500 on /internal/chat. The agent node fails, ExecuteWorkflow stops the
// walk, persists status="failed" + the node's error, and crucially does
// NOT deduct credits (failure path skips the DeductCredits call).
func TestExecuteWorkflow_StatusFailed(t *testing.T) {
	testutil.NewTestDB(t)
	fb, srv := newFakeBackend(t, 5)
	fb.chatFail = true // any AI call → 500
	svc := newWiredService(srv.URL)

	nodes, edges := haikuAgentWorkflow()
	seedWorkflow(t, "0xabc", "wf-bad", "Bad", nodes, edges)

	dto, err := svc.ExecuteWorkflow("0xabc",
		ExecuteWorkflowInput{InputMessage: "ping", Engine: "claude"}, "wf-bad")
	// ExecuteWorkflow returns the failure DTO *without* a Go-level error —
	// the failure is encoded in DTO.Status + ErrorMessage so the handler
	// can render it as a 200 with body{status:"failed",...}.
	require.NoError(t, err)
	require.NotNil(t, dto)
	assert.Equal(t, "failed", dto.Status)
	assert.NotEmpty(t, dto.ErrorMessage, "failed run must record an error message")

	// Critical: NO credits charged on failure.
	assert.EqualValues(t, 0, atomic.LoadInt32(&fb.deductCalls),
		"a failed run must not deduct credits (deduction only on success)")
	assert.EqualValues(t, 0, dto.CreditsUsed)

	// The failed checkpoint must show up in NodeStates so a resume can
	// re-run only the failed node.
	var row models.WorkflowExecution
	require.NoError(t, database.DB.First(&row, dto.ID).Error)
	cps := loadNodeStates(row.NodeStates)
	foundFailed := false
	for _, cp := range cps {
		if cp.Status == "failed" {
			foundFailed = true
			assert.NotEmpty(t, cp.Error, "failed checkpoint must carry an error string")
		}
	}
	assert.True(t, foundFailed, "expected at least one node checkpoint with status='failed'")
}

// ─── 9. Resume: not found ───────────────────────────────────────────────────

// TestResumeExecution_NotFound — already covered by an existing test in
// legend_resume_test.go, but pinned here per the regression suite spec
// using a different exec ID space so the two coexist cleanly.
func TestResumeExecution_NotFound(t *testing.T) {
	testutil.NewTestDB(t)
	svc := &LegendService{}

	dto, err := svc.ResumeExecution("0xabc", 424242)
	require.Error(t, err)
	assert.Nil(t, dto)
	assert.Contains(t, err.Error(), "execution not found")
}

// ─── 10. Resume: already completed ─────────────────────────────────────────

// TestResumeExecution_AlreadyCompleted — resuming a completed run is a no-op:
// it returns the current DTO, doesn't bump resume_attempts, and doesn't
// touch credits. Validates that the early return at the top of
// ResumeExecution fires before any credit / DAG work.
func TestResumeExecution_AlreadyCompleted(t *testing.T) {
	testutil.NewTestDB(t)
	fb, srv := newFakeBackend(t, 100)
	svc := newWiredService(srv.URL)

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
	assert.Equal(t, "completed", dto.Status, "no-op must return current state unchanged")
	assert.Equal(t, "y", dto.FinalOutput)

	// No credit calls, no AI calls, no resume-counter bump.
	assert.EqualValues(t, 0, atomic.LoadInt32(&fb.deductCalls))
	assert.EqualValues(t, 0, atomic.LoadInt32(&fb.chatCalls))

	var row models.WorkflowExecution
	require.NoError(t, database.DB.First(&row, exec.ID).Error)
	assert.Equal(t, 0, row.ResumeAttempts,
		"completed-no-op must not bump resume_attempts")
}

// ─── 11. Resume: skips completed nodes ─────────────────────────────────────

// TestResumeExecution_SkipsCompletedNodes — three-node workflow where the
// first agent node is already checkpointed as completed. On resume, the
// AI pipeline must be called exactly ONCE (for the second agent node only).
// If the resume code re-ran the cached node, chatCalls would be 2 and the
// user would be charged for both nodes.
//
// We also verify the credit charge equals the FULL workflow cost — that's
// a deliberate v3.12 P1-5 contract: resume re-bills the whole graph on
// success because the partial spend on the original failed run is kept.
// What we're asserting here is *just one AI invocation*, not *one credit
// charge*; the no-double-call guarantee is the load-bearing part of
// "skips completed nodes."
func TestResumeExecution_SkipsCompletedNodes(t *testing.T) {
	testutil.NewTestDB(t)
	fb, srv := newFakeBackend(t, 100)
	svc := newWiredService(srv.URL)

	wallet := strings.ToLower("0xabc")

	// Two haiku-agent nodes in series so we can verify "1 of 2 was reused."
	nodesJSON := `[
		{"id":"n1","type":"start","label":"Start","x":0,"y":0,"ref_id":""},
		{"id":"n2","type":"agent","label":"A1","x":1,"y":0,"ref_id":"1","metadata":{"engine":"claude","model":"haiku","prompt":"p1"}},
		{"id":"n3","type":"agent","label":"A2","x":2,"y":0,"ref_id":"1","metadata":{"engine":"claude","model":"haiku","prompt":"p2"}},
		{"id":"n4","type":"end","label":"End","x":3,"y":0,"ref_id":""}
	]`
	edgesJSON := `[
		{"id":"e1","from":"n1","to":"n2"},
		{"id":"e2","from":"n2","to":"n3"},
		{"id":"e3","from":"n3","to":"n4"}
	]`
	seedWorkflow(t, wallet, "wf-skip", "SkipReuse", nodesJSON, edgesJSON)

	// Pre-seed checkpoints: n1 (start) and n2 (first agent) already done.
	// n3 and n4 still pending.
	checkpoints := map[string]nodeCheckpoint{
		"n1": {Status: "completed", Output: "stub-input", DurationMs: 1},
		"n2": {Status: "completed", Output: "first-output", DurationMs: 10},
	}
	statesBlob, _ := json.Marshal(checkpoints)
	exec := &models.WorkflowExecution{
		UserWallet:     wallet,
		WorkflowID:     "wf-skip",
		WorkflowName:   "SkipReuse",
		Status:         "failed",
		InputMessage:   "stub-input",
		TotalNodes:     4,
		CompletedNodes: 2,
		NodeStates:     string(statesBlob),
		NodeResults:    `[]`,
	}
	require.NoError(t, database.DB.Create(exec).Error)

	dto, err := svc.ResumeExecution(wallet, exec.ID)
	require.NoError(t, err)
	require.NotNil(t, dto)
	assert.Equal(t, "completed", dto.Status, "resume should drive run to completed")

	// THE assertion: only one AI call on the resume path, for n3.
	// n2's cached output must be reused without re-calling the pipeline.
	assert.EqualValues(t, 1, atomic.LoadInt32(&fb.chatCalls),
		"resume must skip the cached agent node — expected 1 AI call (n3 only), got %d",
		atomic.LoadInt32(&fb.chatCalls))

	// All four checkpoints should now be present and completed.
	var row models.WorkflowExecution
	require.NoError(t, database.DB.First(&row, exec.ID).Error)
	cps := loadNodeStates(row.NodeStates)
	require.Len(t, cps, 4, "all four nodes must now have checkpoints")
	for id, cp := range cps {
		assert.Equal(t, "completed", cp.Status,
			"node %s must be completed after successful resume", id)
	}
}

// ─── Bonus: resume cost = full graph cost (regression for v3.12 P1-5) ──────

// TestResumeExecution_RebillsFullGraphOnSuccess — companion to
// SkipsCompletedNodes. We confirm the deduct call still goes through with
// the full per-graph cost (2 haiku = 2 credits) even though only one node
// actually re-ran. This pins the "no refund of original spend" decision so
// a future refactor doesn't accidentally start refunding partial spends.
func TestResumeExecution_RebillsFullGraphOnSuccess(t *testing.T) {
	testutil.NewTestDB(t)
	fb, srv := newFakeBackend(t, 100)
	svc := newWiredService(srv.URL)

	nodesJSON := `[
		{"id":"n1","type":"start","label":"Start","x":0,"y":0,"ref_id":""},
		{"id":"n2","type":"agent","label":"A1","x":1,"y":0,"ref_id":"1","metadata":{"engine":"claude","model":"haiku","prompt":"p1"}},
		{"id":"n3","type":"agent","label":"A2","x":2,"y":0,"ref_id":"1","metadata":{"engine":"claude","model":"haiku","prompt":"p2"}},
		{"id":"n4","type":"end","label":"End","x":3,"y":0,"ref_id":""}
	]`
	edgesJSON := `[
		{"id":"e1","from":"n1","to":"n2"},
		{"id":"e2","from":"n2","to":"n3"},
		{"id":"e3","from":"n3","to":"n4"}
	]`
	seedWorkflow(t, "0xabc", "wf-rebill", "Rebill", nodesJSON, edgesJSON)

	checkpoints := map[string]nodeCheckpoint{
		"n1": {Status: "completed", Output: "stub-input", DurationMs: 1},
		"n2": {Status: "completed", Output: "first-output", DurationMs: 10},
	}
	statesBlob, _ := json.Marshal(checkpoints)
	exec := &models.WorkflowExecution{
		UserWallet:     "0xabc",
		WorkflowID:     "wf-rebill",
		WorkflowName:   "Rebill",
		Status:         "failed",
		InputMessage:   "stub-input",
		TotalNodes:     4,
		CompletedNodes: 2,
		NodeStates:     string(statesBlob),
		NodeResults:    `[]`,
	}
	require.NoError(t, database.DB.Create(exec).Error)

	dto, err := svc.ResumeExecution("0xabc", exec.ID)
	require.NoError(t, err)
	require.NotNil(t, dto)
	assert.Equal(t, "completed", dto.Status)

	assert.EqualValues(t, 1, atomic.LoadInt32(&fb.deductCalls),
		"successful resume must call DeductCredits exactly once")
	assert.EqualValues(t, 2, dto.CreditsUsed,
		"resume rebills the whole graph: 2 haiku agents = 2 credits")
}

// Compile-time check: avoid an unused-import false positive if a future
// edit removes all usages of fmt. (The verbose error-message comparisons
// above exercise it, but a defensive guard is cheap.)
var _ = fmt.Sprintf

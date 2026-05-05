package workspace

// reflection_autorecord_test.go — covers v3.11.5 GuildMaster reflection
// auto-record on Legend execution completion.

import (
	"errors"
	"testing"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// stubReflectionTarget captures calls so the test can verify the right
// (wallet, sessionID, executionID) tuple was forwarded.
type stubReflectionTarget struct {
	calls []reflectionCall
	err   error
}

type reflectionCall struct {
	wallet      string
	sessionID   uint
	executionID uint
	summary     string
}

func (s *stubReflectionTarget) RecordReflection(wallet string, sessionID, executionID uint, summary string) error {
	s.calls = append(s.calls, reflectionCall{wallet, sessionID, executionID, summary})
	return s.err
}

func TestExtractGuildMasterSessionID(t *testing.T) {
	cases := map[string]uint{
		"guildmaster:42":         42,
		"guildmaster:7:extra":    7,
		"mission-1-2026":         0,
		"":                       0,
		"guildmaster:":           0,
		"guildmaster:not-a-num":  0,
	}
	for in, want := range cases {
		assert.Equalf(t, want, extractGuildMasterSessionID(in),
			"extractGuildMasterSessionID(%q)", in)
	}
}

func TestNotifyExecutionResult_AutoRecordsReflectionForGMWorkflow(t *testing.T) {
	testutil.NewTestDB(t)
	stub := &stubReflectionTarget{}
	SetReflectionTarget(stub)
	t.Cleanup(func() { SetReflectionTarget(nil) })

	// Seed a workflow with a GuildMaster-prefixed clientID + an execution
	// row whose workflow_id matches.
	wf := models.UserLegendWorkflow{
		UserWallet: "0xowner",
		ClientID:   "guildmaster:42",
		Name:       "Plan workflow",
	}
	require.NoError(t, database.DB.Create(&wf).Error)
	exec := models.WorkflowExecution{
		UserWallet: "0xowner", WorkflowID: wf.ClientID, Status: "completed",
	}
	require.NoError(t, database.DB.Create(&exec).Error)

	notifyExecutionResult("0xowner", "Plan workflow", "completed", exec.ID)

	require.Len(t, stub.calls, 1, "exactly one reflection should have been recorded")
	got := stub.calls[0]
	assert.Equal(t, "0xowner", got.wallet)
	assert.EqualValues(t, 42, got.sessionID)
	assert.EqualValues(t, exec.ID, got.executionID)
	assert.Contains(t, got.summary, "Plan workflow")
}

func TestNotifyExecutionResult_NoAutoRecordWhenNotFromGM(t *testing.T) {
	testutil.NewTestDB(t)
	stub := &stubReflectionTarget{}
	SetReflectionTarget(stub)
	t.Cleanup(func() { SetReflectionTarget(nil) })

	wf := models.UserLegendWorkflow{
		UserWallet: "0xowner",
		ClientID:   "manual-12345", // not a guildmaster session
		Name:       "Manual workflow",
	}
	require.NoError(t, database.DB.Create(&wf).Error)
	exec := models.WorkflowExecution{
		UserWallet: "0xowner", WorkflowID: wf.ClientID, Status: "completed",
	}
	require.NoError(t, database.DB.Create(&exec).Error)

	notifyExecutionResult("0xowner", "Manual workflow", "completed", exec.ID)
	assert.Empty(t, stub.calls, "non-GM workflow must not trigger auto-record")
}

func TestNotifyExecutionResult_NoAutoRecordWhenStatusFailed(t *testing.T) {
	testutil.NewTestDB(t)
	stub := &stubReflectionTarget{}
	SetReflectionTarget(stub)
	t.Cleanup(func() { SetReflectionTarget(nil) })

	wf := models.UserLegendWorkflow{
		UserWallet: "0xowner", ClientID: "guildmaster:7", Name: "X",
	}
	require.NoError(t, database.DB.Create(&wf).Error)
	exec := models.WorkflowExecution{
		UserWallet: "0xowner", WorkflowID: wf.ClientID, Status: "failed",
	}
	require.NoError(t, database.DB.Create(&exec).Error)

	notifyExecutionResult("0xowner", "X", "failed", exec.ID)
	assert.Empty(t, stub.calls, "failed runs are not useful reflection seeds")
}

func TestNotifyExecutionResult_SilentlyIgnoresAdapterErrors(t *testing.T) {
	testutil.NewTestDB(t)
	stub := &stubReflectionTarget{err: errors.New("session not found")}
	SetReflectionTarget(stub)
	t.Cleanup(func() { SetReflectionTarget(nil) })

	wf := models.UserLegendWorkflow{
		UserWallet: "0xowner", ClientID: "guildmaster:99", Name: "X",
	}
	require.NoError(t, database.DB.Create(&wf).Error)
	exec := models.WorkflowExecution{
		UserWallet: "0xowner", WorkflowID: wf.ClientID, Status: "completed",
	}
	require.NoError(t, database.DB.Create(&exec).Error)

	// Should not panic / surface — best-effort by design.
	notifyExecutionResult("0xowner", "X", "completed", exec.ID)
	assert.Len(t, stub.calls, 1, "adapter still called even when it returns an error")
}

package workspace

// legend_resume_rate_limit_test.go — v3.12 P1-5 + P1-6.
//
// P1-5 covers the per-execution attempt cap so a user can't burn opus credits
// indefinitely by re-resuming a failed run. P1-6 covers the status-flip CAS so
// two parallel resume calls don't both write to NodeStates.

import (
	"errors"
	"strings"
	"testing"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/agentstore/backend/services/workspace/client"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestResumeExecution_AttemptsCappedAtMax — fire ResumeExecution
// MaxResumeAttempts+1 times against a perpetually-failing run; only the
// first MaxResumeAttempts increments succeed, then we get
// ErrResumeAttemptsExceeded.
//
// We simulate "perpetually failing" by manually putting the row back into
// "failed" status between attempts so the next call has something to
// flip. Real-world: the failure is what bumped the counter; the user
// retries; eventually the cap kicks in.
func TestResumeExecution_AttemptsCappedAtMax(t *testing.T) {
	testutil.NewTestDB(t)

	// Stand up a fake agent backend so credit calls succeed.
	_, srv := newFakeAgentBackend(t, 1000)
	svc := &LegendService{
		agentClient: client.NewAgentClient(srv.URL),
	}

	makeFailedExecution(t, "0xabc")
	var exec models.WorkflowExecution
	require.NoError(t, database.DB.Where("user_wallet = ?", "0xabc").First(&exec).Error)

	// Walk up to (and one past) the cap. The fixture has a passing path —
	// resume drives status to "completed". Manually demote it back to
	// "failed" so the next attempt has something to flip.
	for i := 0; i < MaxResumeAttempts; i++ {
		dto, err := svc.ResumeExecution("0xabc", exec.ID)
		require.NoError(t, err, "attempt %d should succeed", i+1)
		require.NotNil(t, dto)

		// Demote so the next attempt can flip from "failed" → "running".
		require.NoError(t, database.DB.Model(&models.WorkflowExecution{}).
			Where("id = ?", exec.ID).
			Update("status", "failed").Error)
	}

	// Now we're at the cap. The next call must reject.
	_, err := svc.ResumeExecution("0xabc", exec.ID)
	require.Error(t, err)
	require.True(t, errors.Is(err, ErrResumeAttemptsExceeded),
		"expected ErrResumeAttemptsExceeded, got %v", err)

	// Verify the counter on disk matches the cap (no extra increment after rejection).
	var refreshed models.WorkflowExecution
	require.NoError(t, database.DB.First(&refreshed, exec.ID).Error)
	assert.Equal(t, MaxResumeAttempts, refreshed.ResumeAttempts,
		"resume_attempts must equal the cap, not exceed it")
}

// TestResumeExecution_StatusGuardBlocksDoubleResume — manually flip the row
// to "running" (simulating an in-flight resume from another worker), then
// call ResumeExecution. The CAS WHERE status='failed' must miss, the
// re-read must show status='running', and the call must return
// ErrResumeAlreadyRunning.
func TestResumeExecution_StatusGuardBlocksDoubleResume(t *testing.T) {
	testutil.NewTestDB(t)

	_, srv := newFakeAgentBackend(t, 100)
	svc := &LegendService{agentClient: client.NewAgentClient(srv.URL)}

	makeFailedExecution(t, "0xabc")
	var exec models.WorkflowExecution
	require.NoError(t, database.DB.Where("user_wallet = ?", "0xabc").First(&exec).Error)

	// Pretend another worker already started resuming.
	require.NoError(t, database.DB.Model(&models.WorkflowExecution{}).
		Where("id = ?", exec.ID).
		Update("status", "running").Error)

	_, err := svc.ResumeExecution("0xabc", exec.ID)
	require.Error(t, err)
	require.True(t, errors.Is(err, ErrResumeAlreadyRunning),
		"expected ErrResumeAlreadyRunning, got %v", err)

	// Counter must NOT have been bumped — the CAS missed before the increment.
	var refreshed models.WorkflowExecution
	require.NoError(t, database.DB.First(&refreshed, exec.ID).Error)
	assert.Equal(t, 0, refreshed.ResumeAttempts,
		"failed CAS must not increment resume_attempts")
}

// TestResumeExecution_AttemptCounterPersistsAcrossCalls — two consecutive
// successful resumes leave resume_attempts == 2.
func TestResumeExecution_AttemptCounterPersistsAcrossCalls(t *testing.T) {
	testutil.NewTestDB(t)

	_, srv := newFakeAgentBackend(t, 100)
	svc := &LegendService{agentClient: client.NewAgentClient(srv.URL)}

	makeFailedExecution(t, "0xabc")
	var exec models.WorkflowExecution
	require.NoError(t, database.DB.Where("user_wallet = ?", "0xabc").First(&exec).Error)

	for i := 1; i <= 2; i++ {
		_, err := svc.ResumeExecution("0xabc", exec.ID)
		require.NoError(t, err)
		require.NoError(t, database.DB.Model(&models.WorkflowExecution{}).
			Where("id = ?", exec.ID).
			Update("status", "failed").Error)
	}

	var refreshed models.WorkflowExecution
	require.NoError(t, database.DB.First(&refreshed, exec.ID).Error)
	assert.Equal(t, 2, refreshed.ResumeAttempts)
}

// TestResumeExecution_ExceededReturnsBeforeWorkflowLoad — at the cap, the
// rejection happens before parseWorkflow / DAG validation, so we don't pay
// CPU on a doomed call.
func TestResumeExecution_ExceededReturnsBeforeWorkflowLoad(t *testing.T) {
	testutil.NewTestDB(t)
	svc := &LegendService{}

	exec := makeFailedExecution(t, "0xabc")

	// Bump the counter to the cap directly.
	require.NoError(t, database.DB.Model(&models.WorkflowExecution{}).
		Where("id = ?", exec.ID).
		Update("resume_attempts", MaxResumeAttempts).Error)

	// AgentClient is nil — if ResumeExecution tried to walk past the
	// rate-limit guard it would nil-panic on credit checks. The test
	// passing means the guard fired first.
	_, err := svc.ResumeExecution("0xabc", exec.ID)
	require.Error(t, err)
	assert.True(t, errors.Is(err, ErrResumeAttemptsExceeded))
	// Sanity: the message is the one we expect, not a panic recovery.
	assert.True(t, strings.Contains(err.Error(), "resume attempts exceeded"))
}

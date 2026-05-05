package aipipeline

// run_stages_test.go — covers v3.11.4 stage orchestrator helpers without
// touching the real Gemini / Imagen / BgRemover dependencies.

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestStagesSubset_EmptyReturnsAll(t *testing.T) {
	out := StagesSubset(nil)
	assert.Equal(t, []string{StageAnalyze, StageProfile, StageAvatar}, out)
}

func TestStagesSubset_FiltersAndPreservesCanonicalOrder(t *testing.T) {
	out := StagesSubset([]string{StageAvatar, StageAnalyze, StageAvatar})
	// Canonical order is analyze→profile→avatar, dedup at request layer
	assert.Equal(t, []string{StageAnalyze, StageAvatar}, out)
}

func TestRunStageWithRetry_PassesThroughOnFirstSuccess(t *testing.T) {
	var calls int
	out, err := runStageWithRetry(context.Background(), "x", time.Second, func(_ context.Context) (any, error) {
		calls++
		return "ok", nil
	})
	assert.NoError(t, err)
	assert.Equal(t, "ok", out)
	assert.Equal(t, 1, calls, "no retry on success")
}

func TestRunStageWithRetry_RetriesOnDeadlineExceeded(t *testing.T) {
	var calls int
	_, err := runStageWithRetry(context.Background(), "x", 20*time.Millisecond, func(ctx context.Context) (any, error) {
		calls++
		// Always slower than the timeout — both attempts should hit deadline.
		select {
		case <-time.After(200 * time.Millisecond):
			return "never", nil
		case <-ctx.Done():
			return nil, ctx.Err()
		}
	})
	assert.ErrorIs(t, err, ErrStageTimeout)
	assert.Equal(t, 2, calls, "exactly one retry on timeout")
}

func TestRunStageWithRetry_DoesNotRetryHardErrors(t *testing.T) {
	var calls int
	hard := errors.New("validation failed")
	_, err := runStageWithRetry(context.Background(), "x", time.Second, func(_ context.Context) (any, error) {
		calls++
		return nil, hard
	})
	assert.Equal(t, hard, err)
	assert.Equal(t, 1, calls, "no retry on non-timeout errors")
}

func TestSetStageTimeoutsForTest_RestoresOnCleanup(t *testing.T) {
	prevAnalyze := AnalyzeTimeout
	cleanup := SetStageTimeoutsForTest(1*time.Millisecond, 2*time.Millisecond, 3*time.Millisecond)
	assert.Equal(t, 1*time.Millisecond, AnalyzeTimeout)
	cleanup()
	assert.Equal(t, prevAnalyze, AnalyzeTimeout)
}

// v3.12 P1-1 regression: when parent ctx is canceled, runOnce returns
// ctx.Err() promptly rather than waiting for the (potentially long-running)
// stage worker. The stage closure receives a derived ctx that already carries
// the cancellation, so a well-behaved closure exits without paying full
// LLM latency.
func TestRunOnce_ParentCancellationReturnsPromptly(t *testing.T) {
	parent, cancel := context.WithCancel(context.Background())
	cancel() // already canceled

	start := time.Now()
	_, err := runOnce(parent, time.Second, func(ctx context.Context) (any, error) {
		// Closure should observe the cancel.
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(500 * time.Millisecond):
			return "should-not-reach", nil
		}
	})
	elapsed := time.Since(start)
	assert.Error(t, err)
	assert.Less(t, elapsed, 200*time.Millisecond, "must return promptly on parent cancel, not wait for stage timeout")
}

// v3.12 P1-1 regression: the stage closure receives a ctx that is canceled
// when the parent times out — caller can hook this into HTTP requests via
// http.NewRequestWithContext to tear down in-flight LLM calls.
func TestRunOnce_StageReceivesContextWithDeadline(t *testing.T) {
	parent := context.Background()
	var deadline time.Time
	var hasDeadline bool

	_, _ = runOnce(parent, 50*time.Millisecond, func(ctx context.Context) (any, error) {
		deadline, hasDeadline = ctx.Deadline()
		return "ok", nil
	})

	assert.True(t, hasDeadline, "stage closure must receive ctx with deadline")
	assert.WithinDuration(t, time.Now().Add(50*time.Millisecond), deadline, 100*time.Millisecond)
}

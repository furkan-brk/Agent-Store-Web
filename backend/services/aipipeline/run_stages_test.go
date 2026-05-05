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

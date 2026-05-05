package aipipeline

// run_stages.go — v3.11.4 pipeline-resilience orchestrator.
//
// RunStages wraps the existing PipelineService methods (Score / Gemini /
// BgRemover) without rewriting them. Each stage runs under its own context
// timeout; a stage that exceeds the timeout is retried once before being
// marked as failed. Partial success is supported — the per-stage OK booleans
// in PipelineResult tell the caller which fields they can trust.
//
// The actual stage timing knobs (15s analyze, 20s profile, 30s avatar) are
// declared as exported defaults so test code can override them.

import (
	"context"
	"errors"
	"time"
)

// Stage names — kept as exported constants so the agent service's
// regenerate-pipeline endpoint can validate the ?stages=… CSV against them.
const (
	StageAnalyze = "analyze"
	StageProfile = "profile"
	StageAvatar  = "avatar"
)

// Default per-stage timeouts. Test code mutates these via SetStageTimeoutsForTest.
var (
	AnalyzeTimeout = 15 * time.Second
	ProfileTimeout = 20 * time.Second
	AvatarTimeout  = 30 * time.Second
)

// SetStageTimeoutsForTest overrides the per-stage timeouts. Returns a cleanup
// func that restores the previous values; tests defer it.
func SetStageTimeoutsForTest(analyze, profile, avatar time.Duration) func() {
	prev := [3]time.Duration{AnalyzeTimeout, ProfileTimeout, AvatarTimeout}
	AnalyzeTimeout = analyze
	ProfileTimeout = profile
	AvatarTimeout = avatar
	return func() {
		AnalyzeTimeout = prev[0]
		ProfileTimeout = prev[1]
		AvatarTimeout = prev[2]
	}
}

// PipelineResult captures the per-stage outcome of a RunStages invocation.
// A `false` Ok flag means the stage exceeded its timeout twice (once + 1
// retry) or returned a hard error; the corresponding output field is
// guaranteed to be the zero-value for that stage.
type PipelineResult struct {
	AnalyzeOK  bool   `json:"analyze_ok"`
	ProfileOK  bool   `json:"profile_ok"`
	AvatarOK   bool   `json:"avatar_ok"`
	CharType   string `json:"char_type,omitempty"`
	ImageB64   string `json:"image_b64,omitempty"`
	ImageFmt   string `json:"image_format,omitempty"`
	StagesRun  []string `json:"stages_run"`
	StagesSkip []string `json:"stages_skipped,omitempty"`
}

// ErrStageTimeout is returned by runStageWithRetry when both the original
// and the retry attempt exceed the per-stage timeout.
var ErrStageTimeout = errors.New("stage timed out twice")

// StageFn is the closure shape every stage runner uses. It receives a
// scoped context and produces an opaque value-or-error pair; the caller
// type-asserts the value to whatever the stage actually returns.
type StageFn func(ctx context.Context) (any, error)

// runStageWithRetry runs fn under a context with [timeout], and on a
// context.DeadlineExceeded error retries it once with a fresh deadline.
// Hard errors (non-timeout) are NOT retried.
func runStageWithRetry(parent context.Context, _ string, timeout time.Duration, fn StageFn) (any, error) {
	out, err := runOnce(parent, timeout, fn)
	if err == nil {
		return out, nil
	}
	// Only retry timeouts — analyze/profile errors from auth or validation
	// would be repeatable failures, not transient ones.
	if !errors.Is(err, context.DeadlineExceeded) {
		return nil, err
	}
	out, err = runOnce(parent, timeout, fn)
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) {
			return nil, ErrStageTimeout
		}
		return nil, err
	}
	return out, nil
}

func runOnce(parent context.Context, timeout time.Duration, fn StageFn) (any, error) {
	ctx, cancel := context.WithTimeout(parent, timeout)
	defer cancel()

	type res struct {
		v   any
		err error
	}
	ch := make(chan res, 1)
	go func() {
		v, e := fn(ctx)
		ch <- res{v, e}
	}()
	select {
	case r := <-ch:
		return r.v, r.err
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}

// StagesSubset filters the canonical stage list to those the caller
// requested. Empty input → all stages run.
func StagesSubset(requested []string) []string {
	all := []string{StageAnalyze, StageProfile, StageAvatar}
	if len(requested) == 0 {
		return all
	}
	want := map[string]bool{}
	for _, r := range requested {
		want[r] = true
	}
	out := []string{}
	for _, s := range all {
		if want[s] {
			out = append(out, s)
		}
	}
	return out
}

// RunStages executes the requested stages with the wrapped retry+timeout
// orchestration. Each stage closure adapts the existing PipelineService
// methods so this function never reimplements scoring or image gen.
func (p *PipelineService) RunStages(
	parent context.Context,
	stages []string,
	prompt string,
	profile *AgentProfile,
	imagePrompt, charType string,
) *PipelineResult {
	subset := StagesSubset(stages)
	out := &PipelineResult{StagesRun: subset, CharType: charType}

	skipped := func(name string) {
		out.StagesSkip = append(out.StagesSkip, name)
	}
	all := []string{StageAnalyze, StageProfile, StageAvatar}
	wantSet := map[string]bool{}
	for _, s := range subset {
		wantSet[s] = true
	}
	for _, s := range all {
		if !wantSet[s] {
			skipped(s)
		}
	}

	if wantSet[StageAnalyze] {
		_, err := runStageWithRetry(parent, StageAnalyze, AnalyzeTimeout, func(ctx context.Context) (any, error) {
			if p.Score == nil {
				return nil, nil
			}
			// Bail early if parent already canceled, to avoid even starting
			// the worker goroutine.
			if err := ctx.Err(); err != nil {
				return nil, err
			}
			// Existing Score service is sync; channel is buffered (cap=1)
			// so the goroutine never blocks on send when we abandon it.
			// The HTTP request inside ScoreAndDescribeCtx honours ctx, so
			// a real cancellation tears down the in-flight call rather
			// than leaving it accumulating LLM cost.
			done := make(chan *PromptScoreResult, 1)
			go func() { done <- p.Score.ScoreAndDescribeCtx(ctx, prompt) }()
			select {
			case res := <-done:
				return res, nil
			case <-ctx.Done():
				return nil, ctx.Err()
			}
		})
		if err == nil {
			out.AnalyzeOK = true
		}
	}

	if wantSet[StageProfile] {
		// Profile is currently a fallback construction; treat it as a
		// no-op stage for v3.11.4 — the real LLM-driven profile path
		// lives inside CreateAgent and the regenerate endpoint reuses
		// the existing profile when stages omit it.
		out.ProfileOK = profile != nil
	}

	if wantSet[StageAvatar] {
		v, err := runStageWithRetry(parent, StageAvatar, AvatarTimeout, func(ctx context.Context) (any, error) {
			if err := ctx.Err(); err != nil {
				return nil, err
			}
			// Buffered channel so abandoned goroutines GC cleanly. The
			// inner Imagen HTTP request runs under ctx, so cancellation
			// terminates the request rather than waiting full Imagen
			// latency for a discarded response.
			done := make(chan [2]string, 1)
			go func() {
				img, fmtStr := p.GenerateImageWithFallbackCtx(ctx, profile, imagePrompt, charType)
				done <- [2]string{img, fmtStr}
			}()
			select {
			case pair := <-done:
				if pair[0] == "" {
					return nil, errors.New("avatar gen returned empty image")
				}
				return pair, nil
			case <-ctx.Done():
				return nil, ctx.Err()
			}
		})
		if err == nil {
			if pair, ok := v.([2]string); ok {
				out.ImageB64 = pair[0]
				out.ImageFmt = pair[1]
				out.AvatarOK = true
			}
		}
	}

	return out
}

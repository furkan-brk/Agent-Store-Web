package agent

// regenerate_pipeline.go — v3.11.4 user-facing endpoint that re-runs only
// the requested AI pipeline stages for an agent the caller owns.
//
// The actual stage orchestration (timeout, retry, partial-success result)
// lives in services/aipipeline/run_stages.go. This file is the agent-side
// glue: ownership check, stages-CSV parse, and AgentService method that
// hands the existing AI dependencies to RunStages.

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/agentstore/backend/services/aipipeline"
	"gorm.io/gorm"
)

// ErrRegeneratePipelineNotOwner is returned when the caller doesn't own the agent.
var ErrRegeneratePipelineNotOwner = errors.New("agent not owned by caller")

// RegeneratePipelineForAgent fetches [agentID] (must belong to [wallet]),
// then runs the requested [stages] subset via the aipipeline orchestrator.
// Empty stages → all stages run. Returns the per-stage success result so
// the handler can echo it back to the caller.
//
// Note: this method requires p.aiClient to be a *aipipeline.PipelineService
// (the v3.11.4 AI orchestrator). Production wires it that way; in tests we
// pass nil and stub stages run with skipped=true.
func (s *AgentService) RegeneratePipelineForAgent(ctx context.Context, wallet string, agentID uint, stages []string, pipeline *aipipeline.PipelineService) (*aipipeline.PipelineResult, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" || agentID == 0 {
		return nil, fmt.Errorf("wallet and agentID required")
	}

	var agent models.Agent
	err := database.DB.Where("id = ?", agentID).First(&agent).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("agent %d not found", agentID)
		}
		return nil, err
	}
	if !strings.EqualFold(agent.CreatorWallet, wallet) {
		return nil, ErrRegeneratePipelineNotOwner
	}

	if pipeline == nil {
		// No AI deps wired — return a result that flags every requested stage
		// as skipped so the caller still gets a deterministic response.
		out := &aipipeline.PipelineResult{
			StagesRun: aipipeline.StagesSubset(stages),
		}
		out.StagesSkip = out.StagesRun
		out.StagesRun = nil
		return out, nil
	}

	profile := &aipipeline.AgentProfile{
		Name:        agent.Title,
		RolePurpose: agent.Description,
	}
	return pipeline.RunStages(ctx, stages, agent.Prompt, profile, agent.Description, agent.CharacterType), nil
}

// ParseStagesCSV converts the ?stages= query param into a deduped slice
// of canonical stage names. Unknown tokens are silently dropped.
func ParseStagesCSV(csv string) []string {
	if strings.TrimSpace(csv) == "" {
		return nil
	}
	known := map[string]bool{
		aipipeline.StageAnalyze: true,
		aipipeline.StageProfile: true,
		aipipeline.StageAvatar:  true,
	}
	seen := map[string]bool{}
	out := []string{}
	for _, raw := range strings.Split(csv, ",") {
		t := strings.ToLower(strings.TrimSpace(raw))
		if !known[t] || seen[t] {
			continue
		}
		seen[t] = true
		out = append(out, t)
	}
	return out
}

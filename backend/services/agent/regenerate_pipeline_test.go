package agent

// regenerate_pipeline_test.go — covers v3.11.4 stage CSV parsing,
// ownership check, and the nil-pipeline stub branch.

import (
	"context"
	"testing"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/cache"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/agentstore/backend/services/aipipeline"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func newRegenerateSvc(t *testing.T) *AgentService {
	t.Helper()
	testutil.NewTestDB(t)
	return NewAgentService(nil, nil, cache.NewStore(), "", "")
}

func seedAgentForRegen(t *testing.T, wallet string) uint {
	t.Helper()
	a := &models.Agent{
		Title: "X", CreatorWallet: wallet, Prompt: "p",
		Description: "d", CharacterType: "wizard",
	}
	require.NoError(t, database.DB.Create(a).Error)
	return a.ID
}

func TestParseStagesCSV_DropsUnknownAndDedups(t *testing.T) {
	out := ParseStagesCSV("analyze,unknown,avatar,analyze,profile")
	assert.Equal(t, []string{"analyze", "avatar", "profile"}, out)
}

func TestParseStagesCSV_EmptyReturnsNil(t *testing.T) {
	assert.Nil(t, ParseStagesCSV(""))
	assert.Nil(t, ParseStagesCSV("   "))
}

func TestRegeneratePipeline_RejectsNonOwner(t *testing.T) {
	svc := newRegenerateSvc(t)
	id := seedAgentForRegen(t, "0xowner")

	_, err := svc.RegeneratePipelineForAgent(context.Background(), "0xstranger", id, nil, nil)
	require.Error(t, err)
	assert.ErrorIs(t, err, ErrRegeneratePipelineNotOwner)
}

func TestRegeneratePipeline_NilPipelineReturnsAllSkipped(t *testing.T) {
	svc := newRegenerateSvc(t)
	id := seedAgentForRegen(t, "0xowner")

	res, err := svc.RegeneratePipelineForAgent(
		context.Background(), "0xowner", id,
		[]string{aipipeline.StageAnalyze, aipipeline.StageAvatar},
		nil, // no pipeline service wired
	)
	require.NoError(t, err)
	require.NotNil(t, res)
	assert.Empty(t, res.StagesRun, "no pipeline → nothing runs")
	assert.ElementsMatch(t,
		[]string{aipipeline.StageAnalyze, aipipeline.StageAvatar},
		res.StagesSkip,
	)
}

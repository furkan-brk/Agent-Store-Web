package workspace

// template_metrics_test.go — covers v3.11.4 template usage tracking.

import (
	"testing"
	"time"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func newTemplateSvc(t *testing.T) *LegendService {
	t.Helper()
	testutil.NewTestDB(t)
	// AI deps not needed for these template-metrics tests; pass nils.
	return NewLegendService(nil, nil, nil, nil)
}

func TestRecordTemplateUse_InsertsRow(t *testing.T) {
	svc := newTemplateSvc(t)
	require.NoError(t, svc.RecordTemplateUse("0xowner", "research-pipeline"))

	var rows []models.LegendTemplateUsage
	require.NoError(t, database.DB.Find(&rows).Error)
	require.Len(t, rows, 1)
	assert.Equal(t, "research-pipeline", rows[0].TemplateID)
	assert.Equal(t, "0xowner", rows[0].Wallet)
	assert.Nil(t, rows[0].ExecutionSucceeded, "outcome should start nil")
}

func TestRecordTemplateExecution_PatchesRecentUsage(t *testing.T) {
	svc := newTemplateSvc(t)
	require.NoError(t, svc.RecordTemplateUse("0xowner", "code-review"))

	require.NoError(t, svc.RecordTemplateExecution("0xowner", "code-review", true))

	var row models.LegendTemplateUsage
	require.NoError(t, database.DB.First(&row).Error)
	require.NotNil(t, row.ExecutionSucceeded, "outcome should be patched")
	assert.True(t, *row.ExecutionSucceeded)
}

func TestGetTemplateMetrics_AggregatesByTemplateIDOrderedByUsage(t *testing.T) {
	svc := newTemplateSvc(t)
	// research-pipeline: 3 uses (2 success, 1 fail) → success_rate 0.667
	for i := range 3 {
		require.NoError(t, database.DB.Create(&models.LegendTemplateUsage{
			Wallet: "0xowner", TemplateID: "research-pipeline", UsedAt: time.Now(),
			ExecutionSucceeded: ptrBool(i < 2),
		}).Error)
	}
	// code-review: 1 use (still pending) → success_rate -1
	require.NoError(t, database.DB.Create(&models.LegendTemplateUsage{
		Wallet: "0xowner", TemplateID: "code-review", UsedAt: time.Now(),
	}).Error)

	metrics, err := svc.GetTemplateMetrics(20)
	require.NoError(t, err)
	require.Len(t, metrics, 2)
	// Top by usage_count
	assert.Equal(t, "research-pipeline", metrics[0].TemplateID)
	assert.EqualValues(t, 3, metrics[0].UsageCount)
	assert.InDelta(t, 0.667, metrics[0].SuccessRate, 0.01)
	// Pending row → no completed runs → -1 sentinel
	assert.Equal(t, "code-review", metrics[1].TemplateID)
	assert.EqualValues(t, -1, metrics[1].SuccessRate)
}

func ptrBool(b bool) *bool { return &b }

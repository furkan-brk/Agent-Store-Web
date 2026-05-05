package workspace

// template_metrics.go — Legend template usage + outcome tracking.
//
// RecordTemplateUse is called when a user instantiates a template into a new
// workflow. RecordTemplateExecution patches the most-recent matching usage
// row (within 1h) with the outcome bool — best-effort. GetTemplateMetrics
// aggregates by TemplateID for the gallery's "trending templates" badge.

import (
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
)

// TemplateMetric is one row of the aggregated metrics response.
type TemplateMetric struct {
	TemplateID   string  `json:"template_id"`
	UsageCount   int64   `json:"usage_count"`
	SuccessCount int64   `json:"success_count"`
	FailureCount int64   `json:"failure_count"`
	SuccessRate  float64 `json:"success_rate"` // -1 when no completed runs yet
}

// RecordTemplateUse appends a new "applied" row for the (wallet, template_id)
// pair. Always inserts; idempotency would defeat usage-count semantics.
func (s *LegendService) RecordTemplateUse(wallet, templateID string) error {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	templateID = strings.TrimSpace(templateID)
	if wallet == "" || templateID == "" || database.DB == nil {
		return nil
	}
	row := models.LegendTemplateUsage{
		Wallet:     wallet,
		TemplateID: templateID,
		UsedAt:     time.Now(),
	}
	return database.DB.Create(&row).Error
}

// RecordTemplateExecution stamps the outcome on the most-recent matching
// usage row — within the last hour — for the wallet+template pair. If no
// recent row exists, this is a no-op (the user instantiated the template
// long enough ago that the gap is meaningless).
func (s *LegendService) RecordTemplateExecution(wallet, templateID string, success bool) error {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	templateID = strings.TrimSpace(templateID)
	if wallet == "" || templateID == "" || database.DB == nil {
		return nil
	}
	cutoff := time.Now().Add(-time.Hour)
	var latest models.LegendTemplateUsage
	err := database.DB.
		Where("wallet = ? AND template_id = ? AND used_at >= ? AND execution_succeeded IS NULL",
			wallet, templateID, cutoff).
		Order("used_at DESC").First(&latest).Error
	if err != nil {
		return nil // no eligible usage row, drop the signal silently
	}
	return database.DB.Model(&latest).Update("execution_succeeded", success).Error
}

// GetTemplateMetrics returns the leaderboard view: usage + success counts per
// template, ordered by usage_count DESC. limit caps at 50; pass 0 for the
// default of 20.
func (s *LegendService) GetTemplateMetrics(limit int) ([]TemplateMetric, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	type row struct {
		TemplateID   string
		UsageCount   int64
		SuccessCount int64
		FailureCount int64
	}
	var rows []row
	// COUNT-WHEN aggregations are dialect-neutral when expressed as
	// SUM(CASE WHEN ... THEN 1 ELSE 0 END) — works on sqlite + postgres.
	err := database.DB.Raw(`
		SELECT
		  template_id,
		  COUNT(*) AS usage_count,
		  COALESCE(SUM(CASE WHEN execution_succeeded = 1 THEN 1 ELSE 0 END), 0) AS success_count,
		  COALESCE(SUM(CASE WHEN execution_succeeded = 0 THEN 1 ELSE 0 END), 0) AS failure_count
		FROM legend_template_usages
		GROUP BY template_id
		ORDER BY usage_count DESC
		LIMIT ?`, limit).Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	out := make([]TemplateMetric, len(rows))
	for i, r := range rows {
		m := TemplateMetric{
			TemplateID:   r.TemplateID,
			UsageCount:   r.UsageCount,
			SuccessCount: r.SuccessCount,
			FailureCount: r.FailureCount,
			SuccessRate:  -1,
		}
		// Success rate denominator = completed runs (success + failure). NULL
		// outcomes (still pending) don't count.
		completed := r.SuccessCount + r.FailureCount
		if completed > 0 {
			m.SuccessRate = float64(r.SuccessCount) / float64(completed)
		}
		out[i] = m
	}
	return out, nil
}

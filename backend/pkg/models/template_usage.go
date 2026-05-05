package models

import "time"

// LegendTemplateUsage tracks one application of a Legend workflow template.
//
// When the user picks a template from the gallery, RecordTemplateUse inserts
// a row with ExecutionSucceeded=nil. After the resulting workflow runs,
// RecordTemplateExecution updates the most-recent matching row (within the
// last hour) with the outcome.
//
// Surfacing: GetTemplateMetrics groups by TemplateID to compute usage_count
// and success_rate so the gallery UI can highlight top templates.
type LegendTemplateUsage struct {
	ID                  uint       `gorm:"primaryKey;autoIncrement" json:"id"`
	TemplateID          string     `gorm:"column:template_id;not null;size:100;index:idx_template_usage_tid_time,priority:1" json:"template_id"`
	Wallet              string     `gorm:"column:wallet;not null;size:64" json:"wallet"`
	UsedAt              time.Time  `gorm:"column:used_at;autoCreateTime;index:idx_template_usage_tid_time,priority:2" json:"used_at"`
	ExecutionSucceeded  *bool      `gorm:"column:execution_succeeded" json:"execution_succeeded,omitempty"`
}

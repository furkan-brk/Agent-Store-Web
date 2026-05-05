package models

import "time"

// MissionRun records one cron-driven mission firing — capturing the
// expanded prompt so the user can audit what the schedule produced.
//
// v3.11.5 elevation of v3.11.4's UserActivity-marker approach: the activity
// row is still written for funnel counting, but a MissionRun row carries
// the full expanded prompt (after #slug resolution) and any error from
// ExpandMissionTags. FE surfaces these as a per-schedule history list.
type MissionRun struct {
	ID            uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	MissionID     uint      `gorm:"column:mission_id;not null;index:idx_mission_run_mission_time,priority:1" json:"mission_id"`
	Wallet        string    `gorm:"column:wallet;not null;size:64;index" json:"wallet"`
	Source        string    `gorm:"column:source;not null;size:32" json:"source"` // "schedule" | "manual"
	ExpandedPrompt string   `gorm:"column:expanded_prompt;type:text" json:"expanded_prompt"`
	Error         string    `gorm:"column:error;size:500" json:"error,omitempty"`
	CreatedAt     time.Time `gorm:"column:created_at;autoCreateTime;index:idx_mission_run_mission_time,priority:2" json:"created_at"`
}

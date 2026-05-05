package models

import "time"

// MissionSchedule pins a cron expression to a UserMission so a background
// scheduler can fire it on a recurring cadence.
//
// Composite unique on (mission_id, wallet) prevents duplicate schedules.
// Enabled defaults to true; "disable but keep" lets the user turn a schedule
// off without losing the cron expression they tuned.
//
// v3.11.4 scope: "fires" = a UserActivity marker insert. Real Mission
// execution requires the Mission→Legend→Execute chain wiring, deferred
// to v3.11.5.
type MissionSchedule struct {
	ID          uint       `gorm:"primaryKey;autoIncrement" json:"id"`
	MissionID   uint       `gorm:"column:mission_id;not null;uniqueIndex:idx_mission_schedule_unique,priority:1" json:"mission_id"`
	Wallet      string     `gorm:"column:wallet;not null;size:64;uniqueIndex:idx_mission_schedule_unique,priority:2;index:idx_mission_schedule_wallet" json:"wallet"`
	CronExpr    string     `gorm:"column:cron_expr;not null;size:200" json:"cron_expr"`
	LastRunAt   *time.Time `gorm:"column:last_run_at" json:"last_run_at,omitempty"`
	NextRunAt   time.Time  `gorm:"column:next_run_at;not null;index:idx_mission_schedule_next_run" json:"next_run_at"`
	Enabled     bool       `gorm:"column:enabled;not null;default:true" json:"enabled"`
	CreatedAt   time.Time  `gorm:"column:created_at;autoCreateTime" json:"created_at"`
	UpdatedAt   time.Time  `gorm:"column:updated_at;autoUpdateTime" json:"updated_at"`
}

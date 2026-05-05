package models

import "time"

// GuildMasterReflection records a post-execution reflection note tied back to
// a Guild Master session. The user kicks one off explicitly via the
// reflect-on-execution endpoint after watching a Legend run finish.
//
// Composite index on (session_id, created_at) lets the FE query
// "all reflections for this session, newest first" cheaply.
type GuildMasterReflection struct {
	ID          uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	SessionID   uint      `gorm:"column:session_id;not null;index:idx_gm_reflection_session_time,priority:1" json:"session_id"`
	ExecutionID uint      `gorm:"column:execution_id;not null;index" json:"execution_id"`
	Summary     string    `gorm:"column:summary;type:text" json:"summary"`
	CreatedAt   time.Time `gorm:"column:created_at;autoCreateTime;index:idx_gm_reflection_session_time,priority:2" json:"created_at"`
}

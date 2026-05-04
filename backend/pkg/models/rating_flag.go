package models

import "time"

// RatingFlag is one user's report against an AgentRating. The composite
// uniqueness on (rating_id, reporter_wallet) prevents the same wallet from
// double-flagging the same rating.
//
// At ≥3 distinct flags the rating is auto-hidden by FlagRating in the agent
// service; this counter is the trigger.
type RatingFlag struct {
	ID             uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	RatingID       uint      `gorm:"column:rating_id;not null;index;uniqueIndex:idx_rating_flag_unique,priority:1" json:"rating_id"`
	ReporterWallet string    `gorm:"column:reporter_wallet;not null;size:64;uniqueIndex:idx_rating_flag_unique,priority:2" json:"reporter_wallet"`
	Reason         string    `gorm:"column:reason;size:500" json:"reason"`
	CreatedAt      time.Time `gorm:"column:created_at;autoCreateTime;index" json:"created_at"`
}

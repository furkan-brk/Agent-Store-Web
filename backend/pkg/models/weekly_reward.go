package models

import "time"

// WeeklyLeaderReward records a weekly credit bonus paid to a top-N creator.
//
// Composite uniqueness on (week, wallet) is what makes RecordWeeklyLeaderReward
// idempotent: if the cron fires twice in the same ISO week, the second insert
// becomes a no-op via clause.OnConflict-DoNothing.
//
// Week is formatted ISO-style "YYYY-Www" (e.g. "2026-W18") so admin queries
// like "show me last 4 weeks" are straightforward string comparisons.
type WeeklyLeaderReward struct {
	ID         uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Week       string    `gorm:"column:week;not null;size:10;uniqueIndex:idx_weekly_reward_unique,priority:1;index:idx_weekly_reward_week" json:"week"`
	Wallet     string    `gorm:"column:wallet;not null;size:64;uniqueIndex:idx_weekly_reward_unique,priority:2" json:"wallet"`
	Rank       int       `gorm:"column:rank;not null" json:"rank"`
	Credits    int       `gorm:"column:credits;not null" json:"credits"`
	AwardedAt  time.Time `gorm:"column:awarded_at;autoCreateTime" json:"awarded_at"`
}

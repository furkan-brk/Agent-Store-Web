package models

import "time"

// Achievement constants — closed set of badge types a wallet can earn.
const (
	AchievementFirstAgent    = "first_agent"     // wallet created at least 1 agent
	AchievementFirstSale     = "first_sale"      // wallet's agent was purchased once
	AchievementFirstFork     = "first_fork"      // wallet forked at least 1 agent
	AchievementHundredSaves  = "hundred_saves"   // wallet's agents accumulated >=100 saves total
	AchievementTopCreator    = "top_creator"     // wallet appeared in any leaderboard top-10 window
)

// Achievement is a wallet-scoped badge earned by hitting a milestone.
// Composite uniqueness on (wallet, type) ensures idempotency: the awarder
// service uses OnConflict-DoNothing so repeat checks are no-ops.
type Achievement struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Wallet    string    `gorm:"column:wallet;not null;size:64;uniqueIndex:idx_achievement_unique,priority:1;index:idx_achievement_wallet" json:"wallet"`
	Type      string    `gorm:"column:type;not null;size:32;uniqueIndex:idx_achievement_unique,priority:2" json:"type"`
	EarnedAt  time.Time `gorm:"column:earned_at;autoCreateTime" json:"earned_at"`
}

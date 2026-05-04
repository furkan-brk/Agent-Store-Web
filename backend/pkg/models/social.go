package models

import "time"

// UserFollow records a one-directional follow relationship between two wallets.
// The uniqueIndex on (follower_wallet, followee_wallet) prevents duplicate rows.
type UserFollow struct {
	ID             uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	FollowerWallet string    `gorm:"column:follower_wallet;not null;uniqueIndex:idx_follow_pair,priority:1;index:idx_follow_follower" json:"follower_wallet"`
	FolloweeWallet string    `gorm:"column:followee_wallet;not null;uniqueIndex:idx_follow_pair,priority:2;index:idx_follow_followee" json:"followee_wallet"`
	CreatedAt      time.Time `json:"created_at"`
}

// ActivityType constants for UserActivity.Type.
const (
	ActivityAgentCreated = "agent_created"
	ActivityAgentForked  = "agent_forked"
	ActivityAgentSaved   = "agent_saved"
)

// UserActivity is an append-only event log: one row per notable action.
// Wallet is the actor, Type identifies the event kind, RefID is the agent
// involved. Metadata holds extra JSON context (e.g. forked-from agent title).
// Index on (wallet, created_at) covers the common "feed for wallet, newest
// first" query.
type UserActivity struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Wallet    string    `gorm:"column:wallet;not null;index:idx_activity_wallet_time,priority:1" json:"wallet"`
	Type      string    `gorm:"column:type;not null" json:"type"`
	RefID     uint      `gorm:"column:ref_id" json:"ref_id"`
	Metadata  string    `gorm:"column:metadata;type:text" json:"metadata,omitempty"`
	CreatedAt time.Time `gorm:"column:created_at;autoCreateTime;index:idx_activity_wallet_time,priority:2" json:"created_at"`
}

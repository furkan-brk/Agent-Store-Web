package models

import "time"

// GuildMemberEvent constants — closed set of audit-log event types.
const (
	GuildEventJoined           = "joined"
	GuildEventLeft             = "left"
	GuildEventRoleChanged      = "role_changed"
	GuildEventPermissionChanged = "permission_changed"
)

// GuildMemberEvent is one row of the guild's append-only activity log.
// Surfaces in the UI as "Activity" — joins, leaves, role and permission
// changes. Wallet is the actor (or affected member where applicable);
// Payload is free-form JSON (e.g. {"old": "leader", "new": "shield"}).
type GuildMemberEvent struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	GuildID   uint      `gorm:"column:guild_id;not null;index:idx_guild_event_guild_time,priority:1" json:"guild_id"`
	Wallet    string    `gorm:"column:wallet;not null;size:64" json:"wallet"`
	EventType string    `gorm:"column:event_type;not null;size:32" json:"event_type"`
	Payload   string    `gorm:"column:payload;type:text" json:"payload,omitempty"`
	CreatedAt time.Time `gorm:"column:created_at;autoCreateTime;index:idx_guild_event_guild_time,priority:2" json:"created_at"`
}

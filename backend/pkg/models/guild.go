package models

import "time"

type Guild struct {
	ID            uint          `gorm:"primaryKey;autoIncrement" json:"id"`
	Name          string        `gorm:"column:name;not null" json:"name"`
	CreatorWallet string        `gorm:"column:creator_wallet" json:"creator_wallet"`
	Rarity        string        `gorm:"column:rarity;default:'common'" json:"rarity"`
	Members       []GuildMember `gorm:"foreignKey:GuildID" json:"members,omitempty"`
	CreatedAt     time.Time     `json:"created_at"`
}

// GuildMember rows are uniquely identified by (guild_id, agent_id). The
// uniqueIndex:idx_guild_member_pair tag on both fields creates a single
// composite unique index — required for INSERT ... ON CONFLICT (guild_id,
// agent_id) DO NOTHING in AcceptInvite.
//
// v3.12-P1-13: production DBs may carry duplicate rows from before this
// constraint existed. services/guild/migrate.go calls dedupeGuildMembers()
// before AutoMigrate to prune duplicates, otherwise the index creation fails.
type GuildMember struct {
	ID      uint  `gorm:"primaryKey;autoIncrement" json:"id"`
	GuildID uint  `gorm:"column:guild_id;not null;uniqueIndex:idx_guild_member_pair" json:"guild_id"`
	AgentID uint  `gorm:"column:agent_id;not null;uniqueIndex:idx_guild_member_pair" json:"agent_id"`
	Agent   Agent `gorm:"foreignKey:AgentID" json:"agent,omitempty"`
	Role    string `gorm:"column:role" json:"role"`
	// Permissions is a JSON array of permission keys, e.g. ["edit_agents","invite_members"].
	// Null/empty means default role permissions apply.
	Permissions string    `gorm:"column:permissions;type:text;default:'[]'" json:"permissions"`
	JoinedAt    time.Time `gorm:"column:joined_at;autoCreateTime" json:"joined_at"`
}

// GuildInvite is a time-limited invite link for a guild.
type GuildInvite struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	GuildID   uint      `gorm:"column:guild_id;not null;index" json:"guild_id"`
	Token     string    `gorm:"column:token;not null;uniqueIndex;size:32" json:"token"`
	ExpiresAt time.Time `gorm:"column:expires_at" json:"expires_at"`
	MaxUses   int       `gorm:"column:max_uses;default:0" json:"max_uses"`  // 0 = unlimited
	UsesCount int       `gorm:"column:uses_count;default:0" json:"uses_count"`
	CreatedAt time.Time `gorm:"column:created_at;autoCreateTime" json:"created_at"`
}

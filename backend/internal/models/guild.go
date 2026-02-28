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

type GuildMember struct {
	ID       uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	GuildID  uint      `gorm:"column:guild_id;not null" json:"guild_id"`
	AgentID  uint      `gorm:"column:agent_id;not null" json:"agent_id"`
	Agent    Agent     `gorm:"foreignKey:AgentID" json:"agent,omitempty"`
	Role     string    `gorm:"column:role" json:"role"`
	JoinedAt time.Time `gorm:"column:joined_at;autoCreateTime" json:"joined_at"`
}

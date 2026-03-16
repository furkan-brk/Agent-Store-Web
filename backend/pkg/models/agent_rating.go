package models

import "time"

type AgentRating struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	AgentID   uint      `gorm:"column:agent_id;not null;index" json:"agent_id"`
	Wallet    string    `gorm:"column:wallet;not null;index" json:"wallet"`
	Rating    int       `gorm:"column:rating;not null" json:"rating"`
	Comment   string    `gorm:"column:comment;type:text" json:"comment"`
	CreatedAt time.Time `json:"created_at"`
}

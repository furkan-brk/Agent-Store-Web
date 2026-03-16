package models

import "time"

type UserMission struct {
	ID         uint      `gorm:"primaryKey;autoIncrement" json:"-"`
	UserWallet string    `gorm:"column:user_wallet;not null;index;uniqueIndex:idx_user_mission_client" json:"-"`
	ClientID   string    `gorm:"column:client_id;not null;uniqueIndex:idx_user_mission_client" json:"id"`
	Title      string    `gorm:"column:title;not null" json:"title"`
	Slug       string    `gorm:"column:slug;not null;index" json:"slug"`
	Prompt     string    `gorm:"column:prompt;type:text;not null" json:"prompt"`
	UseCount   int64     `gorm:"column:use_count;default:0" json:"use_count"`
	CreatedAt  time.Time `gorm:"column:created_at;autoCreateTime" json:"created_at"`
	UpdatedAt  time.Time `gorm:"column:updated_at;autoUpdateTime" json:"updated_at"`
}

type UserLegendWorkflow struct {
	ID         uint      `gorm:"primaryKey;autoIncrement" json:"-"`
	UserWallet string    `gorm:"column:user_wallet;not null;index;uniqueIndex:idx_user_workflow_client" json:"-"`
	ClientID   string    `gorm:"column:client_id;not null;uniqueIndex:idx_user_workflow_client" json:"id"`
	Name       string    `gorm:"column:name;not null" json:"name"`
	NodesJSON  string    `gorm:"column:nodes_json;type:jsonb;not null;default:'[]'" json:"-"`
	EdgesJSON  string    `gorm:"column:edges_json;type:jsonb;not null;default:'[]'" json:"-"`
	CreatedAt  time.Time `gorm:"column:created_at;autoCreateTime" json:"created_at"`
	UpdatedAt  time.Time `gorm:"column:updated_at;autoUpdateTime" json:"updated_at"`
}

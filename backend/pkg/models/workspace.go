package models

import (
	"time"

	"gorm.io/gorm"
)

type UserMission struct {
	ID         uint      `gorm:"primaryKey;autoIncrement" json:"-"`
	UserWallet string    `gorm:"column:user_wallet;not null;index;uniqueIndex:idx_user_mission_client" json:"-"`
	ClientID   string    `gorm:"column:client_id;not null;uniqueIndex:idx_user_mission_client" json:"id"`
	Title      string    `gorm:"column:title;not null" json:"title"`
	Slug       string    `gorm:"column:slug;not null;index" json:"slug"`
	Prompt     string    `gorm:"column:prompt;type:text;not null" json:"prompt"`
	UseCount   int64     `gorm:"column:use_count;default:0" json:"use_count"`
	// RevisionID supports optimistic concurrency control via If-Match header.
	// Bumped on every successful update by the BeforeUpdate hook.
	RevisionID uint64    `gorm:"column:revision_id;not null;default:1" json:"revision_id"`
	CreatedAt  time.Time `gorm:"column:created_at;autoCreateTime" json:"created_at"`
	UpdatedAt  time.Time `gorm:"column:updated_at;autoUpdateTime" json:"updated_at"`
}

// BeforeUpdate increments the revision id on every update so optimistic-locking
// PATCH callers can detect concurrent writes. Uses Statement.SetColumn so the
// bump is applied for both struct-based and map-based GORM updates.
func (m *UserMission) BeforeUpdate(tx *gorm.DB) error {
	m.RevisionID++
	tx.Statement.SetColumn("revision_id", m.RevisionID)
	return nil
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

// WorkflowExecution records a single run of a legend workflow.
type WorkflowExecution struct {
	ID             uint       `gorm:"primaryKey;autoIncrement" json:"id"`
	UserWallet     string     `gorm:"column:user_wallet;not null;index" json:"user_wallet"`
	WorkflowID     string     `gorm:"column:workflow_id;not null;index" json:"workflow_id"`
	WorkflowName   string     `gorm:"column:workflow_name;not null" json:"workflow_name"`
	Status         string     `gorm:"column:status;not null;default:'running'" json:"status"`
	InputMessage   string     `gorm:"column:input_message;type:text" json:"input_message"`
	FinalOutput    string     `gorm:"column:final_output;type:text" json:"final_output"`
	NodeResults    string     `gorm:"column:node_results;type:jsonb;not null;default:'[]'" json:"-"`
	TotalNodes     int        `gorm:"column:total_nodes;default:0" json:"total_nodes"`
	CompletedNodes int        `gorm:"column:completed_nodes;default:0" json:"completed_nodes"`
	CreditsUsed    int64      `gorm:"column:credits_used;default:0" json:"credits_used"`
	ErrorMessage   string     `gorm:"column:error_message;type:text" json:"error_message,omitempty"`
	StartedAt      time.Time  `gorm:"column:started_at;autoCreateTime" json:"started_at"`
	FinishedAt     *time.Time `gorm:"column:finished_at" json:"finished_at,omitempty"`
}

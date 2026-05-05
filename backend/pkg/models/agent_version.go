package models

import "time"

// AgentVersion is a point-in-time snapshot of an agent's editable fields,
// captured after every successful UpdateAgent. The (AgentID, Version) pair
// is unique — Version is sequential per agent (1-based, max + 1).
//
// FieldsJSON holds a JSON object with the snapshotted columns
// (title, prompt, description, tags, character_data, traits, profile_mood,
// profile_role_purpose, stats). Schema-flexible so future fields don't
// require a model migration.
//
// Storage discipline: max 20 versions per agent (LRU evict oldest) — bounds
// growth on agents that get edited heavily.
type AgentVersion struct {
	ID         uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	AgentID    uint      `gorm:"column:agent_id;not null;uniqueIndex:idx_agent_version_pair,priority:1;index:idx_agent_version_agent" json:"agent_id"`
	Version    int       `gorm:"column:version;not null;uniqueIndex:idx_agent_version_pair,priority:2" json:"version"`
	FieldsJSON string    `gorm:"column:fields_json;type:text;not null" json:"fields_json"`
	CreatedAt  time.Time `gorm:"column:created_at;autoCreateTime" json:"created_at"`
}

package models

import "time"

// GuildMasterSession persists a Guild Master conversation so it survives
// page reloads and follows the user across devices. Pre-v3.8 sessions
// were SharedPreferences-only; this model is the authoritative store.
//
// MessagesJSON holds an opaque list of {role, agent_id?, agent_title?,
// content, sent_at} envelopes. The frontend produces and consumes the
// payload, so the backend treats it as a string blob — no need to
// version per-message schema in Go.
//
// SuggestionJSON is the most recent SuggestGuild output for the session.
// The action-bridge endpoints (to-mission, to-legend) read it to derive
// Mission / Legend drafts without re-running the AI.
type GuildMasterSession struct {
	ID             uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Wallet         string    `gorm:"column:wallet;not null;index" json:"-"`
	Title          string    `gorm:"column:title;not null;default:'Untitled session'" json:"title"`
	Problem        string    `gorm:"column:problem;type:text" json:"problem"`
	MessagesJSON   string    `gorm:"column:messages_json;type:jsonb;not null;default:'[]'" json:"-"`
	SuggestionJSON string    `gorm:"column:suggestion_json;type:jsonb" json:"-"`
	MessageCount   int       `gorm:"column:message_count;not null;default:0" json:"message_count"`
	CreatedAt      time.Time `gorm:"autoCreateTime" json:"created_at"`
	UpdatedAt      time.Time `gorm:"autoUpdateTime" json:"updated_at"`
}

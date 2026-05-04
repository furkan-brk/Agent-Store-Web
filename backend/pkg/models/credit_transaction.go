package models

import "time"

// CreditTransaction records every credit deduction or grant for a wallet.
//
// Action and Metadata (v3.11.2) provide a normalised, UI-facing per-action
// breakdown alongside the legacy free-form `Type` column:
//   - Action is one of a small, stable set: "agent_purchase", "legend_node",
//     "image_regen", "topup", "agent_create", "agent_fork", "dev_grant", "".
//     Empty string is the backward-compat default for rows written before
//     v3.11.2 — UI falls back to a generic icon.
//   - Metadata is a TEXT-stored JSON blob (object). PostgreSQL stores it as
//     TEXT (not jsonb) for SQLite compatibility; clients deserialise it
//     themselves. Common keys: agent_id, price, node_id, model, cost, tx_hash.
type CreditTransaction struct {
	ID         uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Wallet     string    `gorm:"column:wallet;not null;index" json:"wallet"`
	Type       string    `gorm:"column:type;not null" json:"type"`
	Amount     int64     `gorm:"column:amount;not null" json:"amount"`
	AgentID    *uint     `gorm:"column:agent_id" json:"agent_id,omitempty"`
	TxHash     *string   `gorm:"column:tx_hash;uniqueIndex" json:"tx_hash,omitempty"`
	Action     string    `gorm:"column:action;size:32" json:"action,omitempty"`
	Metadata   string    `gorm:"column:metadata;type:text" json:"metadata,omitempty"`
	AgentTitle string    `gorm:"-" json:"agent_title,omitempty"`
	CreatedAt  time.Time `json:"created_at"`
}

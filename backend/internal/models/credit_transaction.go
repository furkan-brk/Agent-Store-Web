package models

import "time"

// CreditTransaction records every credit deduction or grant for a wallet.
type CreditTransaction struct {
	ID         uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Wallet     string    `gorm:"column:wallet;not null;index" json:"wallet"`
	Type       string    `gorm:"column:type;not null" json:"type"` // "create", "fork", "initial"
	Amount     int64     `gorm:"column:amount;not null" json:"amount"` // negative = deduction
	AgentID    *uint     `gorm:"column:agent_id" json:"agent_id,omitempty"`
	AgentTitle string    `gorm:"-" json:"agent_title,omitempty"`
	CreatedAt  time.Time `json:"created_at"`
}

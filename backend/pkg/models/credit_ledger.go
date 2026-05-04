package models

import "time"

// CreditLedgerEntry is the per-action credit history for a wallet. Frontend
// (Sprint v3.7-8.1) renders structured rows: action label, amount delta,
// running balance, optional Legend node link, and optional cost breakdown.
//
// Delta is signed: negative for spend, positive for top-up / grant.
// CostBreakdown is a JSON blob (rendered as a string column for portability —
// PostgreSQL stores it as TEXT, sqlite stores it as TEXT; queries use it as
// opaque JSON via json.Marshal/Unmarshal, not jsonb operators).
type CreditLedgerEntry struct {
	ID            uint64    `gorm:"primaryKey;autoIncrement" json:"id"`
	UserWallet    string    `gorm:"column:user_wallet;not null;index" json:"user_wallet"`
	Delta         int64     `gorm:"column:delta;not null" json:"delta"`
	BalanceAfter  int64     `gorm:"column:balance_after;not null" json:"balance_after"`
	ActionType    string    `gorm:"column:action_type;not null;size:64" json:"action_type"`
	NodeRef       *string   `gorm:"column:node_ref;size:128" json:"node_ref,omitempty"`
	CostBreakdown string    `gorm:"column:cost_breakdown;type:text" json:"cost_breakdown,omitempty"`
	CreatedAt     time.Time `gorm:"column:created_at;autoCreateTime;index" json:"created_at"`
}

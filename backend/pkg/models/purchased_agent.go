package models

import "time"

// PurchasedAgent records when a user buys an agent with MON tokens.
type PurchasedAgent struct {
	ID          uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	BuyerWallet string    `gorm:"column:buyer_wallet;not null;index" json:"buyer_wallet"`
	AgentID     uint      `gorm:"column:agent_id;not null;index" json:"agent_id"`
	TxHash      string    `gorm:"column:tx_hash;uniqueIndex" json:"tx_hash"`
	AmountMon   float64   `gorm:"column:amount_mon" json:"amount_mon"`
	PurchasedAt time.Time `gorm:"column:purchased_at;autoCreateTime" json:"purchased_at"`
}

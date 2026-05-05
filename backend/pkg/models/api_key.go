package models

import "time"

// APIKey is a developer-issued credential bound to a wallet. The plaintext key
// is shown to the user *once* at creation time and never persisted — KeyHash
// is bcrypt(plaintext).
//
// Prefix is the first 8 characters of the plaintext (after the "agst_" namespace
// prefix), used as a stable display token in lists. Scopes is a comma-separated
// CSV of permissions; the closed set is enforced in agent.validateScopes.
//
// RevokedAt is nil for active keys; setting it tombstones the row.
type APIKey struct {
	ID         uint       `gorm:"primaryKey;autoIncrement" json:"id"`
	Wallet     string     `gorm:"column:wallet;not null;index;size:64" json:"wallet"`
	Name       string     `gorm:"column:name;size:100" json:"name"`
	KeyHash    string     `gorm:"column:key_hash;not null;size:200" json:"-"` // bcrypt — never serialise
	Prefix     string     `gorm:"column:prefix;size:32;index:idx_api_key_prefix" json:"prefix"`
	Scopes     string     `gorm:"column:scopes;size:500" json:"scopes"`
	LastUsedAt *time.Time `gorm:"column:last_used_at" json:"last_used_at,omitempty"`
	RevokedAt  *time.Time `gorm:"column:revoked_at" json:"revoked_at,omitempty"`
	CreatedAt  time.Time  `gorm:"column:created_at;autoCreateTime" json:"created_at"`
}

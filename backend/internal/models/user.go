package models

import "time"

type User struct {
	WalletAddress string    `gorm:"primaryKey;column:wallet_address" json:"wallet_address"`
	Nonce         string    `gorm:"column:nonce" json:"nonce"`
	Credits       int64     `gorm:"column:credits;default:100" json:"credits"`
	Username      string    `gorm:"column:username;default:''" json:"username"`
	Bio           string    `gorm:"column:bio;default:''" json:"bio"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

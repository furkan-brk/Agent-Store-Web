package models

import (
	"time"

	"github.com/lib/pq"
)

type CharacterRarity string

const (
	RarityCommon    CharacterRarity = "common"
	RarityUncommon  CharacterRarity = "uncommon"
	RarityRare      CharacterRarity = "rare"
	RarityEpic      CharacterRarity = "epic"
	RarityLegendary CharacterRarity = "legendary"
)

type Agent struct {
	ID             uint            `gorm:"primaryKey;autoIncrement" json:"id"`
	Title          string          `gorm:"column:title;not null" json:"title"`
	Description    string          `gorm:"column:description" json:"description"`
	Prompt         string          `gorm:"column:prompt;type:text;not null" json:"prompt"`
	Category       string          `gorm:"column:category;index" json:"category"`
	CreatorWallet  string          `gorm:"column:creator_wallet;index" json:"creator_wallet"`
	CharacterType  string          `gorm:"column:character_type" json:"character_type"`
	Subclass       string          `gorm:"column:subclass" json:"subclass"`
	CharacterData  string          `gorm:"column:character_data;type:jsonb" json:"character_data"`
	Rarity         CharacterRarity `gorm:"column:rarity;default:'common'" json:"rarity"`
	Tags           pq.StringArray  `gorm:"column:tags;type:text[]" json:"tags"`
	GeneratedImage     string          `gorm:"column:generated_image;type:text" json:"generated_image"`
	UseCount           int64           `gorm:"column:use_count;default:0" json:"use_count"`
	SaveCount          int64           `gorm:"column:save_count;index;default:0" json:"save_count"`
	Price              float64         `gorm:"column:price;default:0" json:"price"`
	PromptScore        int             `gorm:"column:prompt_score;default:0" json:"prompt_score"`
	ServiceDescription string          `gorm:"column:service_description;type:text" json:"service_description"`
	CreatedAt      time.Time       `json:"created_at"`
	UpdatedAt      time.Time       `json:"updated_at"`
}

type LibraryEntry struct {
	ID         uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserWallet string    `gorm:"column:user_wallet;not null" json:"user_wallet"`
	AgentID    uint      `gorm:"column:agent_id;not null" json:"agent_id"`
	Agent      Agent     `gorm:"foreignKey:AgentID" json:"agent,omitempty"`
	SavedAt    time.Time `gorm:"column:saved_at;autoCreateTime" json:"saved_at"`
}

package models

import "time"

type AgentRating struct {
	ID      uint   `gorm:"primaryKey;autoIncrement" json:"id"`
	AgentID uint   `gorm:"column:agent_id;not null;index" json:"agent_id"`
	Wallet  string `gorm:"column:wallet;not null;index" json:"wallet"`
	Rating  int    `gorm:"column:rating;not null" json:"rating"`
	Comment string `gorm:"column:comment;type:text" json:"comment"`
	// Helpful is a community moderation signal: each unique wallet may
	// upvote a rating once via POST /agents/:id/ratings/:ratingID/helpful.
	// Anti-spam dedup is enforced at the handler level (atomic check-then-
	// increment) so the counter cannot drift past the true unique vote count.
	Helpful   int64     `gorm:"column:helpful;not null;default:0" json:"helpful"`
	CreatedAt time.Time `json:"created_at"`
}

// RatingHelpfulVote records that a wallet has voted "helpful" on a specific
// rating. Composite uniqueness on (rating_id, wallet) prevents double-counting
// even under concurrent requests; the handler queries this table before
// bumping the counter on AgentRating.
type RatingHelpfulVote struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	RatingID  uint      `gorm:"column:rating_id;not null;uniqueIndex:idx_rating_helpful_unique,priority:1" json:"rating_id"`
	Wallet    string    `gorm:"column:wallet;not null;uniqueIndex:idx_rating_helpful_unique,priority:2" json:"wallet"`
	CreatedAt time.Time `gorm:"column:created_at;autoCreateTime" json:"created_at"`
}

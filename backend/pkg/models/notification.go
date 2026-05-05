package models

import "time"

// NotificationPref captures a single per-channel preference for a wallet.
//
// The (wallet, channel, type) tuple is the natural unique key — enforced via a
// composite unique index so upserts can rely on ON CONFLICT semantics. Defaults
// are seeded lazily when ListPrefs first runs for a wallet (3 type × 2 channel
// = 6 rows, all enabled).
type NotificationPref struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Wallet    string    `gorm:"column:wallet;not null;size:64;uniqueIndex:idx_notif_pref_unique,priority:1" json:"wallet"`
	Channel   string    `gorm:"column:channel;not null;size:16;uniqueIndex:idx_notif_pref_unique,priority:2" json:"channel"`
	Type      string    `gorm:"column:type;not null;size:32;uniqueIndex:idx_notif_pref_unique,priority:3" json:"type"`
	Enabled   bool      `gorm:"column:enabled;not null;default:true" json:"enabled"`
	CreatedAt time.Time `gorm:"column:created_at;autoCreateTime" json:"created_at"`
	UpdatedAt time.Time `gorm:"column:updated_at;autoUpdateTime" json:"updated_at"`
}

// NotificationEvent is one inbox row for a wallet. ReadAt being nil means the
// row is unread; setting it via MarkRead/MarkAllRead transitions to read state.
//
// Composite (wallet, id DESC) index supports the cursor-pagination query in
// ListInbox (newest first, before_id < cursor).
//
// DedupKey is a hashed bucket of (wallet, type, link, hour) used by
// notifyOnce to enforce a 1-hour dedup window at the DB level (unique
// index + ON CONFLICT DO NOTHING). Without this column the existing
// SELECT-then-INSERT path was racy under parallel triggers (e.g. a fork +
// library-add hitting the same creator simultaneously) — both checks would
// pass, both inserts would land. See v3.12 P1-2.
type NotificationEvent struct {
	ID        uint       `gorm:"primaryKey;autoIncrement" json:"id"`
	Wallet    string     `gorm:"column:wallet;not null;size:64;index:idx_notif_event_wallet_id,priority:1" json:"wallet"`
	Type      string     `gorm:"column:type;not null;size:32" json:"type"`
	Title     string     `gorm:"column:title;not null;size:200" json:"title"`
	Body      string     `gorm:"column:body;size:500" json:"body"`
	Link      string     `gorm:"column:link;size:200" json:"link,omitempty"`
	DedupKey  string     `gorm:"column:dedup_key;size:96;uniqueIndex:idx_notif_event_dedup" json:"-"`
	ReadAt    *time.Time `gorm:"column:read_at" json:"read_at,omitempty"`
	CreatedAt time.Time  `gorm:"column:created_at;autoCreateTime" json:"created_at"`
}

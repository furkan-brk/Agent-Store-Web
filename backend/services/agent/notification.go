package agent

// notification.go — wallet-scoped notification preferences and inbox events.
// Mirrors the v3.9 social.go pattern: methods hang off AgentService so they
// share the cache and DB handle, no new service type is introduced.
//
// Cursor pagination on the inbox uses ID-DESC ordering with `id < before_id`,
// matching GetActivityFeed in social.go.

import (
	"errors"
	"fmt"
	"slices"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"gorm.io/gorm"
)

// Notification channels and types are intentionally a closed set: the seed
// population (3 × 2 = 6 rows per wallet) and the validation in UpdatePref both
// rely on these slices being authoritative.
var (
	notificationChannels = []string{"web", "email"}
	notificationTypes    = []string{"social", "system", "credit"}
)

// validNotificationChannel reports whether s is a recognised channel.
func validNotificationChannel(s string) bool {
	return slices.Contains(notificationChannels, s)
}

// validNotificationType reports whether s is a recognised type.
func validNotificationType(s string) bool {
	return slices.Contains(notificationTypes, s)
}

// ErrInvalidNotificationChannel is returned when the channel is unknown.
var ErrInvalidNotificationChannel = errors.New("invalid notification channel")

// ErrInvalidNotificationType is returned when the type is unknown.
var ErrInvalidNotificationType = errors.New("invalid notification type")

// ListPrefs returns the wallet's preferences. If none exist (first call), seeds
// the default 6 rows (3 type × 2 channel, all enabled) and returns them.
//
// Seeding is idempotent: a duplicate insert raised by a concurrent caller is
// suppressed, then the read is repeated so both callers see the seeded set.
func (s *AgentService) ListPrefs(wallet string) ([]models.NotificationPref, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return nil, fmt.Errorf("wallet required")
	}
	var prefs []models.NotificationPref
	if err := database.DB.Where("wallet = ?", wallet).
		Order("type ASC, channel ASC").
		Find(&prefs).Error; err != nil {
		return nil, err
	}
	if len(prefs) > 0 {
		return prefs, nil
	}
	// Seed defaults — all enabled, 6 rows.
	rows := make([]models.NotificationPref, 0, len(notificationChannels)*len(notificationTypes))
	for _, t := range notificationTypes {
		for _, ch := range notificationChannels {
			rows = append(rows, models.NotificationPref{
				Wallet:  wallet,
				Channel: ch,
				Type:    t,
				Enabled: true,
			})
		}
	}
	// Best-effort insert; if a parallel caller seeded first the unique index
	// rejects our rows and we re-read what landed.
	if err := database.DB.Create(&rows).Error; err != nil {
		// Read back whatever the parallel caller wrote.
		var parallel []models.NotificationPref
		if rerr := database.DB.Where("wallet = ?", wallet).
			Order("type ASC, channel ASC").
			Find(&parallel).Error; rerr == nil && len(parallel) > 0 {
			return parallel, nil
		}
		return nil, err
	}
	return rows, nil
}

// UpdatePref upserts a single (wallet, channel, type) row to the given enabled
// state. Both channel and type are validated against the closed sets so a
// malformed body cannot create stray rows.
func (s *AgentService) UpdatePref(wallet, channel, ntype string, enabled bool) error {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return fmt.Errorf("wallet required")
	}
	if !validNotificationChannel(channel) {
		return ErrInvalidNotificationChannel
	}
	if !validNotificationType(ntype) {
		return ErrInvalidNotificationType
	}

	// Try update first; if no row exists, insert. We deliberately avoid GORM's
	// generic OnConflict here because sqlite + composite unique upsert via
	// AllAssign is fiddly across drivers.
	var existing models.NotificationPref
	err := database.DB.
		Where("wallet = ? AND channel = ? AND type = ?", wallet, channel, ntype).
		First(&existing).Error
	if err == nil {
		return database.DB.Model(&existing).
			Update("enabled", enabled).Error
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}
	// Use a map insert (rather than struct) so GORM doesn't apply the
	// `default:true` column tag when Enabled is false. With a struct, GORM
	// can't distinguish "explicitly false" from "zero value" and falls back
	// to the column default.
	return database.DB.Model(&models.NotificationPref{}).Create(map[string]any{
		"wallet":  wallet,
		"channel": channel,
		"type":    ntype,
		"enabled": enabled,
	}).Error
}

// ListInbox returns up to limit events for the wallet, newest first. When
// beforeID > 0, only rows with id < beforeID are returned (cursor pagination,
// same shape as GetActivityFeed in social.go).
func (s *AgentService) ListInbox(wallet string, beforeID uint, limit int) ([]models.NotificationEvent, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return nil, fmt.Errorf("wallet required")
	}
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	q := database.DB.Where("wallet = ?", wallet)
	if beforeID > 0 {
		q = q.Where("id < ?", beforeID)
	}
	var rows []models.NotificationEvent
	if err := q.Order("id DESC").Limit(limit).Find(&rows).Error; err != nil {
		return nil, err
	}
	return rows, nil
}

// MarkRead sets ReadAt = now for one event, scoped to the wallet so a foreign
// wallet cannot mark someone else's notification as read.
func (s *AgentService) MarkRead(wallet string, eventID uint) error {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return fmt.Errorf("wallet required")
	}
	now := time.Now()
	res := database.DB.Model(&models.NotificationEvent{}).
		Where("id = ? AND wallet = ? AND read_at IS NULL", eventID, wallet).
		Update("read_at", now)
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		// Either the row doesn't exist, doesn't belong to this wallet, or was
		// already read. We treat all three as success — clients call MarkRead
		// optimistically and shouldn't get an error for already-read rows.
		return nil
	}
	return nil
}

// MarkAllRead bulk-stamps every unread row for the wallet.
func (s *AgentService) MarkAllRead(wallet string) (int64, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return 0, fmt.Errorf("wallet required")
	}
	now := time.Now()
	res := database.DB.Model(&models.NotificationEvent{}).
		Where("wallet = ? AND read_at IS NULL", wallet).
		Update("read_at", now)
	return res.RowsAffected, res.Error
}

// CreateNotification appends a single event for a wallet. Used by future
// trigger sites (CreateAgent / LibraryAdd / LegendExecute) and exposed for
// tests. Honours the wallet's preference: if the relevant (web, type) pref is
// disabled, the event is silently dropped.
//
// Best-effort: failures are returned but callers (background goroutines)
// usually log-and-discard.
func (s *AgentService) CreateNotification(wallet, ntype, title, body, link string) error {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return fmt.Errorf("wallet required")
	}
	if !validNotificationType(ntype) {
		return ErrInvalidNotificationType
	}
	// Honour the user's web channel preference. If absent, default to enabled
	// (matches the seed behaviour in ListPrefs).
	var pref models.NotificationPref
	err := database.DB.
		Where("wallet = ? AND channel = ? AND type = ?", wallet, "web", ntype).
		First(&pref).Error
	if err == nil && !pref.Enabled {
		return nil
	}
	row := models.NotificationEvent{
		Wallet: wallet,
		Type:   ntype,
		Title:  title,
		Body:   body,
		Link:   link,
	}
	return database.DB.Create(&row).Error
}

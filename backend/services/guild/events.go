package guild

// events.go — append-only audit log for guild membership changes.
//
// LogMemberEvent is best-effort (errors logged but not surfaced) so a logging
// failure never blocks the parent operation. Wired into AddMember,
// RemoveMember, JoinGuild, LeaveGuild, and SetMemberPermissions sites in
// service.go and invite.go.

import (
	"encoding/json"
	"log"
	"strings"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
)

// LogMemberEvent appends a single audit row. payload is a free-form map that
// gets JSON-encoded for storage; pass nil for events that need no extra
// context (e.g. simple join/leave).
func (s *GuildService) LogMemberEvent(guildID uint, wallet, eventType string, payload map[string]any) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if guildID == 0 || wallet == "" || eventType == "" {
		return
	}
	if database.DB == nil {
		return
	}
	row := models.GuildMemberEvent{
		GuildID:   guildID,
		Wallet:    wallet,
		EventType: eventType,
	}
	if len(payload) > 0 {
		if b, err := json.Marshal(payload); err == nil {
			row.Payload = string(b)
		}
	}
	if err := database.DB.Create(&row).Error; err != nil {
		log.Printf("[guild.LogMemberEvent] insert failed: %v", err)
	}
}

// ListGuildEvents returns audit-log rows for the guild, newest first. limit
// caps at 50 to bound memory and the JSON payload returned to clients.
func (s *GuildService) ListGuildEvents(guildID uint, limit int) ([]models.GuildMemberEvent, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	var rows []models.GuildMemberEvent
	err := database.DB.Where("guild_id = ?", guildID).
		Order("id DESC").Limit(limit).Find(&rows).Error
	return rows, err
}

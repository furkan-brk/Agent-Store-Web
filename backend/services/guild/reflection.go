package guild

// reflection.go — explicit post-execution reflection notes for a Guild Master
// session.
//
// Triggered by the user (POST /sessions/:id/reflect-on-execution) after they
// watch a Legend run finish. v3.11.4 stays explicit: no auto-record on
// execution complete. The session's wallet is verified before insert so a
// foreign wallet can't graft notes onto someone else's session.

import (
	"errors"
	"strings"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"gorm.io/gorm"
)

// RecordReflection inserts a GuildMasterReflection row tied to (sessionID,
// executionID). Returns the persisted row so the handler can echo it back.
func (s *SessionService) RecordReflection(wallet string, sessionID, executionID uint, summary string) (*models.GuildMasterReflection, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" || sessionID == 0 || executionID == 0 {
		return nil, errors.New("wallet, sessionID, and executionID are required")
	}
	summary = strings.TrimSpace(summary)
	if summary == "" {
		return nil, errors.New("summary required")
	}
	if len(summary) > 4000 {
		summary = summary[:4000]
	}

	// Verify wallet owns the session before insert.
	var session models.GuildMasterSession
	err := database.DB.Where("id = ? AND wallet = ?", sessionID, wallet).First(&session).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrSessionNotFound
	}
	if err != nil {
		return nil, err
	}

	row := models.GuildMasterReflection{
		SessionID:   sessionID,
		ExecutionID: executionID,
		Summary:     summary,
	}
	if err := database.DB.Create(&row).Error; err != nil {
		return nil, err
	}
	return &row, nil
}

// ListReflections returns the session's reflections newest-first. Wallet
// scoping enforced via the same session-ownership check used by RecordReflection.
func (s *SessionService) ListReflections(wallet string, sessionID uint, limit int) ([]models.GuildMasterReflection, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" || sessionID == 0 {
		return nil, errors.New("wallet and sessionID required")
	}
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	var session models.GuildMasterSession
	if err := database.DB.Where("id = ? AND wallet = ?", sessionID, wallet).First(&session).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrSessionNotFound
		}
		return nil, err
	}
	var rows []models.GuildMasterReflection
	err := database.DB.Where("session_id = ?", sessionID).
		Order("id DESC").Limit(limit).Find(&rows).Error
	return rows, err
}

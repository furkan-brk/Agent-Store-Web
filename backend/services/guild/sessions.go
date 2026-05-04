package guild

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"gorm.io/gorm"
)

// SessionService manages persistent Guild Master conversation history.
// Sessions live alongside the rest of the user's data and are scoped per
// wallet — there's no public sharing surface in v3.8.
type SessionService struct{}

// NewSessionService creates a SessionService. The receiver is stateless
// today; the constructor exists so future caching/locking can be added
// without breaking callers.
func NewSessionService() *SessionService { return &SessionService{} }

// SessionMessage is the wire shape for each chat message. The backend
// stores messages opaquely (raw JSON) and only validates the envelope
// fields on append so the frontend can evolve the payload (attachments,
// reactions, etc.) without a backend change.
type SessionMessage struct {
	AgentID    *uint  `json:"agent_id,omitempty"`
	AgentTitle string `json:"agent_title,omitempty"`
	Role       string `json:"role"`
	Content    string `json:"content"`
	SentAt     string `json:"sent_at,omitempty"`
}

// SessionListItem is what /sessions returns: just enough metadata for the
// left-rail list. The full message log is fetched on demand.
type SessionListItem struct {
	ID           uint      `json:"id"`
	Title        string    `json:"title"`
	Problem      string    `json:"problem,omitempty"`
	MessageCount int       `json:"message_count"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// SessionDetail is the full payload for /sessions/:id — metadata + parsed
// message list + last suggest output (if any).
type SessionDetail struct {
	ID           uint              `json:"id"`
	Title        string            `json:"title"`
	Problem      string            `json:"problem,omitempty"`
	Messages     []SessionMessage  `json:"messages"`
	Suggestion   *GuildSuggestion  `json:"suggestion,omitempty"`
	CreatedAt    time.Time         `json:"created_at"`
	UpdatedAt    time.Time         `json:"updated_at"`
	MessageCount int               `json:"message_count"`
}

// CreateSessionInput is the request body for POST /sessions.
type CreateSessionInput struct {
	Title    string           `json:"title"`
	Problem  string           `json:"problem"`
	Messages []SessionMessage `json:"messages,omitempty"`
}

// UpdateSessionInput is the request body for PATCH /sessions/:id —
// limited to title rename + suggestion replacement so callers can't
// arbitrarily rewrite chat history through this endpoint.
type UpdateSessionInput struct {
	Title      *string          `json:"title,omitempty"`
	Suggestion *GuildSuggestion `json:"suggestion,omitempty"`
}

// AppendMessagesInput is the request body for POST /sessions/:id/messages.
type AppendMessagesInput struct {
	Messages []SessionMessage `json:"messages" binding:"required"`
}

// ErrSessionNotFound is returned when a session lookup misses for the
// caller's wallet (either non-existent or owned by someone else — the
// handler MUST NOT distinguish to avoid leaking presence information).
var ErrSessionNotFound = errors.New("session not found")

// ListSessions returns metadata for every session owned by the wallet,
// most-recently-updated first. No message bodies, no suggestion blobs.
func (s *SessionService) ListSessions(wallet string) ([]SessionListItem, error) {
	wallet = strings.ToLower(wallet)
	var rows []models.GuildMasterSession
	if err := database.DB.
		Select("id, title, problem, message_count, created_at, updated_at").
		Where("wallet = ?", wallet).
		Order("updated_at DESC").
		Find(&rows).Error; err != nil {
		return nil, err
	}
	out := make([]SessionListItem, 0, len(rows))
	for _, r := range rows {
		out = append(out, SessionListItem{
			ID:           r.ID,
			Title:        r.Title,
			Problem:      r.Problem,
			MessageCount: r.MessageCount,
			CreatedAt:    r.CreatedAt,
			UpdatedAt:    r.UpdatedAt,
		})
	}
	return out, nil
}

// CreateSession opens a new session for the wallet. Initial messages
// (if any) are validated and stored; on validation failure no row is
// created. Title falls back to the first ~40 chars of the problem so
// the session list is browsable even when the user doesn't name it.
func (s *SessionService) CreateSession(wallet string, input CreateSessionInput) (*SessionDetail, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return nil, errors.New("wallet required")
	}
	title := strings.TrimSpace(input.Title)
	if title == "" {
		title = deriveTitle(input.Problem)
	}
	if len(title) > 120 {
		title = title[:120]
	}

	cleaned, err := validateMessages(input.Messages)
	if err != nil {
		return nil, err
	}
	msgsBlob, err := encodeMessages(cleaned)
	if err != nil {
		return nil, err
	}

	row := &models.GuildMasterSession{
		Wallet:       wallet,
		Title:        title,
		Problem:      strings.TrimSpace(input.Problem),
		MessagesJSON: msgsBlob,
		MessageCount: len(cleaned),
	}
	if err := database.DB.Create(row).Error; err != nil {
		return nil, err
	}
	return s.GetSession(wallet, row.ID)
}

// GetSession fetches a single session for the wallet and decodes the
// blob fields. Returns ErrSessionNotFound if the row is missing or
// owned by a different wallet.
func (s *SessionService) GetSession(wallet string, id uint) (*SessionDetail, error) {
	wallet = strings.ToLower(wallet)
	var row models.GuildMasterSession
	err := database.DB.Where("id = ? AND wallet = ?", id, wallet).First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrSessionNotFound
	}
	if err != nil {
		return nil, err
	}
	return rowToDetail(&row)
}

// UpdateSession applies a title rename and/or replaces the stored
// suggestion in one transaction. Only the listed fields (Title,
// Suggestion) are touched — chat messages are off-limits here.
func (s *SessionService) UpdateSession(wallet string, id uint, input UpdateSessionInput) (*SessionDetail, error) {
	wallet = strings.ToLower(wallet)
	updates := map[string]any{}
	if input.Title != nil {
		t := strings.TrimSpace(*input.Title)
		if t == "" {
			return nil, errors.New("title cannot be empty")
		}
		if len(t) > 120 {
			t = t[:120]
		}
		updates["title"] = t
	}
	if input.Suggestion != nil {
		raw, err := json.Marshal(input.Suggestion)
		if err != nil {
			return nil, fmt.Errorf("encode suggestion: %w", err)
		}
		updates["suggestion_json"] = string(raw)
	}
	if len(updates) == 0 {
		return s.GetSession(wallet, id)
	}
	res := database.DB.Model(&models.GuildMasterSession{}).
		Where("id = ? AND wallet = ?", id, wallet).
		Updates(updates)
	if res.Error != nil {
		return nil, res.Error
	}
	if res.RowsAffected == 0 {
		return nil, ErrSessionNotFound
	}
	return s.GetSession(wallet, id)
}

// AppendMessages adds [msgs] to the session's transcript, bumps the
// message_count column, and refreshes updated_at. The append happens
// inside a transaction with FOR UPDATE so concurrent appends from two
// tabs don't lose messages.
func (s *SessionService) AppendMessages(wallet string, id uint, msgs []SessionMessage) (*SessionDetail, error) {
	wallet = strings.ToLower(wallet)
	cleaned, err := validateMessages(msgs)
	if err != nil {
		return nil, err
	}
	if len(cleaned) == 0 {
		return s.GetSession(wallet, id)
	}
	err = database.DB.Transaction(func(tx *gorm.DB) error {
		var row models.GuildMasterSession
		if err := tx.Set("gorm:query_option", "FOR UPDATE").
			Where("id = ? AND wallet = ?", id, wallet).First(&row).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return ErrSessionNotFound
			}
			return err
		}
		var existing []SessionMessage
		if row.MessagesJSON != "" {
			if jsonErr := json.Unmarshal([]byte(row.MessagesJSON), &existing); jsonErr != nil {
				existing = nil
			}
		}
		merged := append(existing, cleaned...)
		blob, err := encodeMessages(merged)
		if err != nil {
			return err
		}
		return tx.Model(&row).Updates(map[string]any{
			"messages_json": blob,
			"message_count": len(merged),
		}).Error
	})
	if err != nil {
		return nil, err
	}
	return s.GetSession(wallet, id)
}

// DeleteSession removes a session and its history. Hard delete — there's
// no archive surface. Returns ErrSessionNotFound if the row is missing.
func (s *SessionService) DeleteSession(wallet string, id uint) error {
	wallet = strings.ToLower(wallet)
	res := database.DB.Where("id = ? AND wallet = ?", id, wallet).Delete(&models.GuildMasterSession{})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return ErrSessionNotFound
	}
	return nil
}

// validateMessages filters out empty entries, enforces a 4 KB cap per
// message body so a runaway agent reply can't blow up the session row,
// and ensures the role string is recognised.
func validateMessages(in []SessionMessage) ([]SessionMessage, error) {
	const maxLen = 4096
	out := make([]SessionMessage, 0, len(in))
	for _, m := range in {
		role := strings.ToLower(strings.TrimSpace(m.Role))
		if role != "user" && role != "agent" && role != "system" {
			return nil, fmt.Errorf("invalid message role %q", m.Role)
		}
		content := strings.TrimSpace(m.Content)
		if content == "" {
			continue
		}
		if len(content) > maxLen {
			content = content[:maxLen]
		}
		out = append(out, SessionMessage{
			AgentID:    m.AgentID,
			AgentTitle: strings.TrimSpace(m.AgentTitle),
			Role:       role,
			Content:    content,
			SentAt:     strings.TrimSpace(m.SentAt),
		})
	}
	return out, nil
}

func encodeMessages(msgs []SessionMessage) (string, error) {
	if len(msgs) == 0 {
		return "[]", nil
	}
	b, err := json.Marshal(msgs)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

func rowToDetail(row *models.GuildMasterSession) (*SessionDetail, error) {
	var msgs []SessionMessage
	if row.MessagesJSON != "" {
		if err := json.Unmarshal([]byte(row.MessagesJSON), &msgs); err != nil {
			msgs = nil
		}
	}
	if msgs == nil {
		msgs = []SessionMessage{}
	}
	var suggestion *GuildSuggestion
	if row.SuggestionJSON != "" {
		var parsed GuildSuggestion
		if err := json.Unmarshal([]byte(row.SuggestionJSON), &parsed); err == nil {
			suggestion = &parsed
		}
	}
	return &SessionDetail{
		ID:           row.ID,
		Title:        row.Title,
		Problem:      row.Problem,
		Messages:     msgs,
		Suggestion:   suggestion,
		CreatedAt:    row.CreatedAt,
		UpdatedAt:    row.UpdatedAt,
		MessageCount: row.MessageCount,
	}, nil
}

// deriveTitle fabricates a session title from the problem statement
// when the caller didn't supply one. Picks the first ~40 visible
// characters and trims at the last word boundary so titles read
// naturally instead of mid-word truncations.
func deriveTitle(problem string) string {
	t := strings.TrimSpace(problem)
	if t == "" {
		return "New session"
	}
	if len(t) <= 40 {
		return t
	}
	cut := t[:40]
	if idx := strings.LastIndex(cut, " "); idx > 20 {
		cut = cut[:idx]
	}
	return cut + "…"
}

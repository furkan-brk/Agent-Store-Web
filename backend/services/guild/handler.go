package guild

import (
	"errors"
	"log"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

// Handler exposes HTTP endpoints for the Guild Service.
type Handler struct {
	guildSvc   *GuildService
	gmSvc      *GuildMasterService
	sessionSvc *SessionService
	bridgeSvc  *BridgeService
}

// NewHandler creates a Guild handler.
func NewHandler(guildSvc *GuildService, gmSvc *GuildMasterService) *Handler {
	sessionSvc := NewSessionService()
	return &Handler{
		guildSvc:   guildSvc,
		gmSvc:      gmSvc,
		sessionSvc: sessionSvc,
		bridgeSvc:  NewBridgeService(sessionSvc),
	}
}

// ListGuilds handles GET /api/v1/guilds
func (h *Handler) ListGuilds(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 20
	}
	if limit > 50 {
		limit = 50
	}
	guilds, total, err := h.guildSvc.ListGuilds(page, limit)
	if err != nil {
		log.Printf("[GuildHandler.ListGuilds] error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"guilds": guilds, "total": total, "page": page, "limit": limit})
}

// CreateGuild handles POST /api/v1/guilds
func (h *Handler) CreateGuild(c *gin.Context) {
	var input CreateGuildInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if len(input.Name) > 50 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "guild name too long (max 50 characters)"})
		return
	}
	input.CreatorWallet = c.GetString("wallet")
	g, err := h.guildSvc.CreateGuild(input)
	if err != nil {
		log.Printf("[GuildHandler.CreateGuild] error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		return
	}
	c.JSON(http.StatusCreated, g)
}

// GetGuild handles GET /api/v1/guilds/:id
func (h *Handler) GetGuild(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	g, synergies, bonuses, err := h.guildSvc.GetGuild(uint(id))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"guild":   g,
		"synergy": synergies,
		"bonuses": bonuses,
	})
}

// AddMember handles POST /api/v1/guilds/:id/members
func (h *Handler) AddMember(c *gin.Context) {
	guildID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid guild id"})
		return
	}
	var body struct {
		AgentID uint `json:"agent_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := h.guildSvc.AddMember(uint(guildID), body.AgentID, c.GetString("wallet")); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "member added"})
}

// JoinGuild handles POST /api/v1/guilds/:id/join
func (h *Handler) JoinGuild(c *gin.Context) {
	guildID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid guild id"})
		return
	}
	if err := h.guildSvc.JoinGuild(uint(guildID), c.GetString("wallet")); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "joined guild"})
}

// LeaveGuild handles DELETE /api/v1/guilds/:id/join
func (h *Handler) LeaveGuild(c *gin.Context) {
	guildID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid guild id"})
		return
	}
	if err := h.guildSvc.LeaveGuild(uint(guildID), c.GetString("wallet")); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "left guild"})
}

// RemoveMember handles DELETE /api/v1/guilds/:id/members/:agentId
func (h *Handler) RemoveMember(c *gin.Context) {
	guildID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid guild id"})
		return
	}
	agentID, err := strconv.ParseUint(c.Param("agentId"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid agent id"})
		return
	}
	if err := h.guildSvc.RemoveMember(uint(guildID), uint(agentID), c.GetString("wallet")); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "member removed"})
}

// GetCompatibility handles GET /api/v1/guilds/:id/compatibility
func (h *Handler) GetCompatibility(c *gin.Context) {
	guildID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid guild id"})
		return
	}
	result, err := h.guildSvc.CheckCompatibility(uint(guildID))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, result)
}

// Suggest handles POST /api/v1/guild-master/suggest.
//
// v3.8: When SessionID is provided in the body, the resulting GuildSuggestion
// is stored on the session row so the action-bridge endpoints (to-mission,
// to-legend) can reuse it without re-running the AI. Backward compat:
// callers that don't pass SessionID get the unchanged response.
func (h *Handler) Suggest(c *gin.Context) {
	var body struct {
		Problem   string `json:"problem" binding:"required"`
		SessionID *uint  `json:"session_id,omitempty"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	suggestion, err := h.gmSvc.SuggestGuild(body.Problem)
	if err != nil {
		log.Printf("[GuildMasterHandler.Suggest] error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		return
	}
	if body.SessionID != nil {
		wallet := c.GetString("wallet")
		if _, err := h.sessionSvc.UpdateSession(wallet, *body.SessionID, UpdateSessionInput{
			Suggestion: suggestion,
		}); err != nil && !errors.Is(err, ErrSessionNotFound) {
			log.Printf("[GuildMasterHandler.Suggest] persist suggestion: %v", err)
		}
	}
	c.JSON(http.StatusOK, suggestion)
}

// ListSessions handles GET /api/v1/guild-master/sessions — left-rail
// metadata for the wallet's full session history.
func (h *Handler) ListSessions(c *gin.Context) {
	sessions, err := h.sessionSvc.ListSessions(c.GetString("wallet"))
	if err != nil {
		log.Printf("[GuildMasterHandler.ListSessions] error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"sessions": sessions})
}

// CreateSession handles POST /api/v1/guild-master/sessions.
func (h *Handler) CreateSession(c *gin.Context) {
	var input CreateSessionInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	session, err := h.sessionSvc.CreateSession(c.GetString("wallet"), input)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, session)
}

// GetSession handles GET /api/v1/guild-master/sessions/:id.
func (h *Handler) GetSession(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid session id"})
		return
	}
	session, err := h.sessionSvc.GetSession(c.GetString("wallet"), uint(id))
	if err != nil {
		if errors.Is(err, ErrSessionNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "session not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, session)
}

// UpdateSession handles PATCH /api/v1/guild-master/sessions/:id.
func (h *Handler) UpdateSession(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid session id"})
		return
	}
	var input UpdateSessionInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	session, err := h.sessionSvc.UpdateSession(c.GetString("wallet"), uint(id), input)
	if err != nil {
		if errors.Is(err, ErrSessionNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "session not found"})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, session)
}

// AppendMessages handles POST /api/v1/guild-master/sessions/:id/messages.
func (h *Handler) AppendMessages(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid session id"})
		return
	}
	var input AppendMessagesInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	session, err := h.sessionSvc.AppendMessages(c.GetString("wallet"), uint(id), input.Messages)
	if err != nil {
		if errors.Is(err, ErrSessionNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "session not found"})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, session)
}

// DeleteSession handles DELETE /api/v1/guild-master/sessions/:id.
func (h *Handler) DeleteSession(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid session id"})
		return
	}
	if err := h.sessionSvc.DeleteSession(c.GetString("wallet"), uint(id)); err != nil {
		if errors.Is(err, ErrSessionNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "session not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "session deleted"})
}

// SessionToMission handles POST /api/v1/guild-master/sessions/:id/to-mission.
// Bridges the session's stored suggestion into a UserMission draft.
func (h *Handler) SessionToMission(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid session id"})
		return
	}
	result, err := h.bridgeSvc.ToMission(c.GetString("wallet"), uint(id))
	if err != nil {
		if errors.Is(err, ErrSessionNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "session not found"})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, result)
}

// SessionToLegend handles POST /api/v1/guild-master/sessions/:id/to-legend.
// Bridges the session's stored suggestion into a Legend Workflow draft.
func (h *Handler) SessionToLegend(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid session id"})
		return
	}
	result, err := h.bridgeSvc.ToLegend(c.GetString("wallet"), uint(id))
	if err != nil {
		if errors.Is(err, ErrSessionNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "session not found"})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, result)
}

// TeamChat handles POST /api/v1/guild-master/chat
func (h *Handler) TeamChat(c *gin.Context) {
	var body struct {
		Message  string `json:"message" binding:"required"`
		AgentIDs []uint `json:"agent_ids" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	responses, err := h.gmSvc.TeamChat(body.Message, body.AgentIDs)
	if err != nil {
		log.Printf("[GuildMasterHandler.TeamChat] error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"responses": responses})
}

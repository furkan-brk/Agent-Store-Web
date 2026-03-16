package guild

import (
	"log"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

// Handler exposes HTTP endpoints for the Guild Service.
type Handler struct {
	guildSvc *GuildService
	gmSvc    *GuildMasterService
}

// NewHandler creates a Guild handler.
func NewHandler(guildSvc *GuildService, gmSvc *GuildMasterService) *Handler {
	return &Handler{guildSvc: guildSvc, gmSvc: gmSvc}
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

// Suggest handles POST /api/v1/guild-master/suggest
func (h *Handler) Suggest(c *gin.Context) {
	var body struct {
		Problem string `json:"problem" binding:"required"`
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
	c.JSON(http.StatusOK, suggestion)
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

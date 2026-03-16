package handlers

import (
	"log"
	"net/http"
	"strconv"

	"github.com/agentstore/backend/internal/services"
	"github.com/gin-gonic/gin"
)

type GuildHandler struct{ guildSvc *services.GuildService }

func NewGuildHandler(guildSvc *services.GuildService) *GuildHandler { return &GuildHandler{guildSvc} }

func (h *GuildHandler) ListGuilds(c *gin.Context) {
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

func (h *GuildHandler) CreateGuild(c *gin.Context) {
	var input services.CreateGuildInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if len(input.Name) > 50 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "guild name too long (max 50 characters)"})
		return
	}
	input.CreatorWallet = c.GetString("wallet")
	guild, err := h.guildSvc.CreateGuild(input)
	if err != nil {
		log.Printf("[GuildHandler.CreateGuild] error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		return
	}
	c.JSON(http.StatusCreated, guild)
}

func (h *GuildHandler) GetGuild(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	guild, synergies, bonuses, err := h.guildSvc.GetGuild(uint(id))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"guild":    guild,
		"synergy":  synergies,
		"bonuses":  bonuses,
	})
}

func (h *GuildHandler) AddMember(c *gin.Context) {
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

func (h *GuildHandler) JoinGuild(c *gin.Context) {
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

func (h *GuildHandler) LeaveGuild(c *gin.Context) {
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

func (h *GuildHandler) RemoveMember(c *gin.Context) {
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

func (h *GuildHandler) GetCompatibility(c *gin.Context) {
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

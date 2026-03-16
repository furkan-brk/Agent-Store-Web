package handlers

import (
	"log"
	"net/http"

	"github.com/agentstore/backend/internal/services"
	"github.com/gin-gonic/gin"
)

type GuildMasterHandler struct {
	gmSvc *services.GuildMasterService
}

func NewGuildMasterHandler(gmSvc *services.GuildMasterService) *GuildMasterHandler {
	return &GuildMasterHandler{gmSvc: gmSvc}
}

// Suggest handles POST /api/v1/guild-master/suggest
// Body: { "problem": string }
// No auth required.
func (h *GuildMasterHandler) Suggest(c *gin.Context) {
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
// Body: { "message": string, "agent_ids": []uint }
// No auth required.
func (h *GuildMasterHandler) TeamChat(c *gin.Context) {
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

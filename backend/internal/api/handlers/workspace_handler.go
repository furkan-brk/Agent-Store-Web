package handlers

import (
	"net/http"

	"github.com/agentstore/backend/internal/services"
	"github.com/gin-gonic/gin"
)

func (h *AgentHandler) GetMissions(c *gin.Context) {
	missions, err := h.agentSvc.ListUserMissions(c.GetString("wallet"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"missions": missions})
}

func (h *AgentHandler) SaveMission(c *gin.Context) {
	var input services.SaveMissionInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if len(input.Title) > 120 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "title too long (max 120 characters)"})
		return
	}
	if len(input.Slug) > 160 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "slug too long (max 160 characters)"})
		return
	}
	if len(input.Prompt) > 20000 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "prompt too long (max 20000 characters)"})
		return
	}
	mission, err := h.agentSvc.SaveUserMission(c.GetString("wallet"), input)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, mission)
}

func (h *AgentHandler) DeleteMission(c *gin.Context) {
	if err := h.agentSvc.DeleteUserMission(c.GetString("wallet"), c.Param("id")); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "mission deleted"})
}

func (h *AgentHandler) GetLegendWorkflows(c *gin.Context) {
	workflows, err := h.agentSvc.ListUserLegendWorkflows(c.GetString("wallet"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"workflows": workflows})
}

func (h *AgentHandler) SaveLegendWorkflow(c *gin.Context) {
	var input services.SaveLegendWorkflowInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if len(input.Name) > 120 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "name too long (max 120 characters)"})
		return
	}
	workflow, err := h.agentSvc.SaveUserLegendWorkflow(c.GetString("wallet"), input)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, workflow)
}

func (h *AgentHandler) DeleteLegendWorkflow(c *gin.Context) {
	if err := h.agentSvc.DeleteUserLegendWorkflow(c.GetString("wallet"), c.Param("id")); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "workflow deleted"})
}

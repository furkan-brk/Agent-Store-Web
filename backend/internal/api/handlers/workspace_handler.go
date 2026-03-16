package handlers

import (
	"net/http"
	"strconv"

	"github.com/agentstore/backend/internal/services"
	"github.com/gin-gonic/gin"
)

// WorkspaceHandler handles mission and legend workflow HTTP endpoints.
type WorkspaceHandler struct {
	missionSvc *services.MissionService
	legendSvc  *services.LegendService
}

// NewWorkspaceHandler creates a new WorkspaceHandler.
func NewWorkspaceHandler(missionSvc *services.MissionService, legendSvc *services.LegendService) *WorkspaceHandler {
	return &WorkspaceHandler{missionSvc: missionSvc, legendSvc: legendSvc}
}

// GetMissions returns all missions for the authenticated user.
func (h *WorkspaceHandler) GetMissions(c *gin.Context) {
	missions, err := h.missionSvc.ListUserMissions(c.GetString("wallet"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"missions": missions})
}

// SaveMission creates or updates a mission.
func (h *WorkspaceHandler) SaveMission(c *gin.Context) {
	var input services.SaveMissionInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	mission, err := h.missionSvc.SaveUserMission(c.GetString("wallet"), input)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, mission)
}

// DeleteMission deletes a mission by client ID.
func (h *WorkspaceHandler) DeleteMission(c *gin.Context) {
	if err := h.missionSvc.DeleteUserMission(c.GetString("wallet"), c.Param("id")); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "mission deleted"})
}

// ExpandMissions expands #slug references in a text body.
func (h *WorkspaceHandler) ExpandMissions(c *gin.Context) {
	var input services.ExpandMissionInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	result, err := h.missionSvc.ExpandMissionTags(c.GetString("wallet"), input.Text)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, result)
}

// GetLegendWorkflows returns all workflows for the authenticated user.
func (h *WorkspaceHandler) GetLegendWorkflows(c *gin.Context) {
	workflows, err := h.legendSvc.ListUserWorkflows(c.GetString("wallet"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"workflows": workflows})
}

// SaveLegendWorkflow creates or updates a workflow.
func (h *WorkspaceHandler) SaveLegendWorkflow(c *gin.Context) {
	var input services.SaveLegendWorkflowInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	workflow, err := h.legendSvc.SaveUserWorkflow(c.GetString("wallet"), input)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, workflow)
}

// DeleteLegendWorkflow deletes a workflow by client ID.
func (h *WorkspaceHandler) DeleteLegendWorkflow(c *gin.Context) {
	if err := h.legendSvc.DeleteUserWorkflow(c.GetString("wallet"), c.Param("id")); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "workflow deleted"})
}

// ExecuteWorkflow runs a workflow and returns the execution result.
func (h *WorkspaceHandler) ExecuteWorkflow(c *gin.Context) {
	var input services.ExecuteWorkflowInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	result, err := h.legendSvc.ExecuteWorkflow(c.GetString("wallet"), input, c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, result)
}

// GetExecution returns a single execution by ID.
func (h *WorkspaceHandler) GetExecution(c *gin.Context) {
	execID, err := strconv.ParseUint(c.Param("execId"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid execution ID"})
		return
	}
	result, err := h.legendSvc.GetExecution(c.GetString("wallet"), uint(execID))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, result)
}

// ListExecutions returns paginated executions, optionally filtered by workflow_id.
func (h *WorkspaceHandler) ListExecutions(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 20
	}
	workflowID := c.Query("workflow_id")
	executions, total, err := h.legendSvc.ListExecutions(c.GetString("wallet"), workflowID, page, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"executions": executions,
		"total":      total,
		"page":       page,
		"limit":      limit,
	})
}

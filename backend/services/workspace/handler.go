package workspace

import (
	"errors"
	"log"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
)

// Handler exposes HTTP endpoints for the Workspace Service.
type Handler struct {
	missionSvc *MissionService
	legendSvc  *LegendService
}

// NewHandler creates a Workspace handler.
func NewHandler(missionSvc *MissionService, legendSvc *LegendService) *Handler {
	return &Handler{missionSvc: missionSvc, legendSvc: legendSvc}
}

// GetMissions returns all missions for the authenticated user.
func (h *Handler) GetMissions(c *gin.Context) {
	missions, err := h.missionSvc.ListUserMissions(c.GetString("wallet"))
	if err != nil {
		log.Printf("[WorkspaceHandler.GetMissions] error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"missions": missions})
}

// SaveMission creates or updates a mission.
func (h *Handler) SaveMission(c *gin.Context) {
	var input SaveMissionInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// If-Match optimistic concurrency on update path. Absent → opt-out.
	var ifMatchRev *uint64
	if raw := strings.Trim(c.GetHeader("If-Match"), `" `); raw != "" {
		v, perr := strconv.ParseUint(raw, 10, 64)
		if perr != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid If-Match header (must be uint64)"})
			return
		}
		ifMatchRev = &v
	}

	mission, err := h.missionSvc.SaveUserMission(c.GetString("wallet"), input, ifMatchRev)
	if err != nil {
		var revErr *MissionRevisionMismatchError
		if errors.As(err, &revErr) {
			c.JSON(http.StatusConflict, revErr.Current)
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, mission)
}

// DeleteMission deletes a mission by client ID.
func (h *Handler) DeleteMission(c *gin.Context) {
	if err := h.missionSvc.DeleteUserMission(c.GetString("wallet"), c.Param("id")); err != nil {
		log.Printf("[WorkspaceHandler.DeleteMission] error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "mission deleted"})
}

// BatchSyncMissions receives an array of missions from the frontend and upserts
// them all, then returns the complete mission list from the DB.
func (h *Handler) BatchSyncMissions(c *gin.Context) {
	var body struct {
		Missions []SaveMissionInput `json:"missions" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	missions, err := h.missionSvc.BatchSyncMissions(c.GetString("wallet"), body.Missions)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"missions": missions})
}

// ExpandMissions expands #slug references in a text body.
func (h *Handler) ExpandMissions(c *gin.Context) {
	var input ExpandMissionInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	result, err := h.missionSvc.ExpandMissionTags(c.GetString("wallet"), input.Text)
	if err != nil {
		log.Printf("[WorkspaceHandler.ExpandMissions] error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		return
	}
	c.JSON(http.StatusOK, result)
}

// BatchSyncLegendWorkflows receives an array of workflows from the frontend and
// upserts them all, then returns the complete workflow list from the DB.
func (h *Handler) BatchSyncLegendWorkflows(c *gin.Context) {
	var body struct {
		Workflows []SaveLegendWorkflowInput `json:"workflows" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	workflows, err := h.legendSvc.BatchSyncWorkflows(c.GetString("wallet"), body.Workflows)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"workflows": workflows})
}

// GetLegendWorkflows returns all workflows for the authenticated user.
func (h *Handler) GetLegendWorkflows(c *gin.Context) {
	workflows, err := h.legendSvc.ListUserWorkflows(c.GetString("wallet"))
	if err != nil {
		log.Printf("[WorkspaceHandler.GetLegendWorkflows] error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"workflows": workflows})
}

// SaveLegendWorkflow creates or updates a workflow.
func (h *Handler) SaveLegendWorkflow(c *gin.Context) {
	var input SaveLegendWorkflowInput
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
func (h *Handler) DeleteLegendWorkflow(c *gin.Context) {
	if err := h.legendSvc.DeleteUserWorkflow(c.GetString("wallet"), c.Param("id")); err != nil {
		log.Printf("[WorkspaceHandler.DeleteLegendWorkflow] error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "workflow deleted"})
}

// ExecuteWorkflow runs a workflow and returns the execution result.
func (h *Handler) ExecuteWorkflow(c *gin.Context) {
	var input ExecuteWorkflowInput
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
func (h *Handler) GetExecution(c *gin.Context) {
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
func (h *Handler) ListExecutions(c *gin.Context) {
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
		log.Printf("[WorkspaceHandler.ListExecutions] error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"executions": executions,
		"total":      total,
		"page":       page,
		"limit":      limit,
	})
}

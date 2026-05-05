package workspace

import (
	"errors"
	"log"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
)

// MissionLegendBridge is the cross-package contract the workspace handler
// uses to translate a mission into a Legend workflow draft. The concrete
// implementation lives in services/guild (BridgeService) — workspace stays
// independent of the guild package by speaking through this interface.
type MissionLegendBridge interface {
	MissionToLegend(wallet string, missionID uint) (*LegendDraftResult, error)
}

// LegendDraftResult mirrors guild.LegendDraftResult so workspace callers
// don't have to import the guild package. The two structs are kept
// field-compatible and are JSON-marshalled identically.
type LegendDraftResult struct {
	WorkflowID   string `json:"workflow_id"`
	WorkflowName string `json:"workflow_name"`
	NodeCount    int    `json:"node_count"`
	EdgeCount    int    `json:"edge_count"`
	Source       string `json:"source"`
}

// Handler exposes HTTP endpoints for the Workspace Service.
type Handler struct {
	missionSvc *MissionService
	legendSvc  *LegendService
	// missionBridge is optional — when nil, the Mission→Legend endpoint
	// returns 503. The monolith wires guild.BridgeService here via a thin
	// adapter; the standalone workspacesvc binary leaves it nil because
	// the bridge needs cross-service state that only the monolith owns.
	missionBridge MissionLegendBridge
}

// NewHandler creates a Workspace handler. `bridge` is optional — pass nil
// from binaries that don't surface the Mission→Legend feature.
func NewHandler(missionSvc *MissionService, legendSvc *LegendService) *Handler {
	return &Handler{missionSvc: missionSvc, legendSvc: legendSvc}
}

// SetMissionBridge installs the cross-package adapter that powers the
// /missions/:id/to-legend endpoint. Call this once at boot from the
// monolith after both workspace and guild services are constructed.
func (h *Handler) SetMissionBridge(bridge MissionLegendBridge) {
	h.missionBridge = bridge
}

// GetTemplateMetrics handles GET /api/v1/legend/templates/metrics?limit=20.
// v3.11.4: usage counts + success rates per template_id for the gallery's
// trending-templates badge. Public endpoint — no auth required.
func (h *Handler) GetTemplateMetrics(c *gin.Context) {
	limit := 0
	if v := c.Query("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			limit = n
		}
	}
	metrics, err := h.legendSvc.GetTemplateMetrics(limit)
	if err != nil {
		log.Printf("[WorkspaceHandler.GetTemplateMetrics] error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"metrics": metrics, "count": len(metrics)})
}

// RecordTemplateUse handles POST /api/v1/legend/templates/:templateId/used.
// Auth required — wallet attribution.
func (h *Handler) RecordTemplateUse(c *gin.Context) {
	wallet := c.GetString("wallet")
	if wallet == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "auth required"})
		return
	}
	templateID := c.Param("templateId")
	if err := h.legendSvc.RecordTemplateUse(wallet, templateID); err != nil {
		log.Printf("[WorkspaceHandler.RecordTemplateUse] error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"recorded": true})
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
//
// Supports optimistic concurrency via the If-Match header (uint64 revision id).
// Header absent → opt-out, last-write-wins behaviour preserved for older clients.
// Header present and stale → 409 Conflict with the current workflow in the body.
func (h *Handler) SaveLegendWorkflow(c *gin.Context) {
	var input SaveLegendWorkflowInput
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

	workflow, err := h.legendSvc.SaveUserWorkflow(c.GetString("wallet"), input, ifMatchRev)
	if err != nil {
		var revErr *LegendRevisionMismatchError
		if errors.As(err, &revErr) {
			c.JSON(http.StatusConflict, revErr.Current)
			return
		}
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

// ResumeExecution re-runs a previously failed execution, skipping nodes that
// completed successfully. v3.11.3.
func (h *Handler) ResumeExecution(c *gin.Context) {
	execID, err := strconv.ParseUint(c.Param("execId"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid execution ID"})
		return
	}
	result, err := h.legendSvc.ResumeExecution(c.GetString("wallet"), uint(execID))
	if err != nil {
		// "not found" maps to 404; other errors (parse, credits, etc.) are 400.
		msg := err.Error()
		if strings.Contains(msg, "execution not found") || strings.Contains(msg, "workflow not found") {
			c.JSON(http.StatusNotFound, gin.H{"error": msg})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": msg})
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

// PreflightWorkflow validates a workflow and estimates credit cost before execution.
func (h *Handler) PreflightWorkflow(c *gin.Context) {
	report, err := h.legendSvc.PreflightWorkflow(c.GetString("wallet"), c.Param("id"))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, report)
}

// ListWorkflowVersions returns version history for a workflow.
func (h *Handler) ListWorkflowVersions(c *gin.Context) {
	versions, err := h.legendSvc.ListWorkflowVersions(c.GetString("wallet"), c.Param("id"))
	if err != nil {
		log.Printf("[WorkspaceHandler.ListWorkflowVersions] error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"versions": versions})
}

// GetWorkflowVersion returns a single version snapshot with full nodes/edges.
func (h *Handler) GetWorkflowVersion(c *gin.Context) {
	vID, err := strconv.ParseUint(c.Param("versionId"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid version ID"})
		return
	}
	v, err := h.legendSvc.GetWorkflowVersion(c.GetString("wallet"), c.Param("id"), uint(vID))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, v)
}

// GetPublicMissions returns the public mission marketplace listing.
func (h *Handler) GetPublicMissions(c *gin.Context) {
	cat := c.Query("cat")
	missions, err := h.missionSvc.ListPublicMissions(cat)
	if err != nil {
		log.Printf("[WorkspaceHandler.GetPublicMissions] error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"missions": missions})
}

// ImportPublicMission copies a public mission into the user's library.
func (h *Handler) ImportPublicMission(c *gin.Context) {
	mission, err := h.missionSvc.ImportPublicMission(c.GetString("wallet"), c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, mission)
}

// ToLegend handles POST /api/v1/user/missions/:id/to-legend.
//
// Bridges a stored mission into a freshly-created UserLegendWorkflow draft
// (START → MISSION_AGENT → END). Returns the new workflow's client ID +
// display name so the frontend can navigate straight into Legend.
//
// Status codes:
//   - 201: workflow created, body = {workflow_id, workflow_name, ...}
//   - 404: mission not found for this wallet
//   - 422: mission has empty/whitespace prompt (nothing to bridge)
//   - 503: bridge wiring is missing (e.g. running standalone workspacesvc)
func (h *Handler) ToLegend(c *gin.Context) {
	if h.missionBridge == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"error": "mission bridge not configured for this service",
		})
		return
	}
	missionID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid mission id"})
		return
	}
	result, err := h.missionBridge.MissionToLegend(c.GetString("wallet"), uint(missionID))
	if err != nil {
		// Mission lookup failures map to 404 — the bridge returns gorm.ErrRecordNotFound
		// when the (mission_id, wallet) pair has no row. Empty-prompt errors map to 422
		// so the UI can show "this mission has no prompt yet" rather than a generic 4xx.
		msg := err.Error()
		switch {
		case strings.Contains(msg, "no prompt"):
			c.JSON(http.StatusUnprocessableEntity, gin.H{"error": msg})
		case strings.Contains(msg, "record not found"):
			c.JSON(http.StatusNotFound, gin.H{"error": "mission not found"})
		default:
			log.Printf("[WorkspaceHandler.ToLegend] error: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		}
		return
	}
	c.JSON(http.StatusCreated, gin.H{
		"id":   result.WorkflowID,
		"name": result.WorkflowName,
	})
}

// SetMissionPublic toggles the public flag on a mission the user owns.
func (h *Handler) SetMissionPublic(c *gin.Context) {
	var body struct {
		Public bool `json:"public"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := h.missionSvc.SetMissionPublic(c.GetString("wallet"), c.Param("id"), body.Public); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"public": body.Public})
}

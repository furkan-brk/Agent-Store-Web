package workspace

import (
	"net/http"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/middleware"
	"github.com/gin-gonic/gin"
)

// SetupRouter creates the Gin engine for the Workspace Service.
func SetupRouter(handler *Handler) *gin.Engine {
	r := gin.Default()

	// Request body size limit — 2MB
	r.Use(func(c *gin.Context) {
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 2<<20)
		c.Next()
	})

	// DB readiness check
	dbReady := func(c *gin.Context) {
		if !database.IsReady() {
			c.AbortWithStatusJSON(http.StatusServiceUnavailable, gin.H{"error": "database not ready"})
			return
		}
		c.Next()
	}

	auth := middleware.InternalAuth()
	// v3.11.3: dual-auth on the legend resume endpoint so programmatic clients
	// can re-run a failed run via API key with `execute:legend` scope.
	resumeAuth := middleware.AuthOrAPIKey("execute:legend")

	// Rate limiter for workflow execution (expensive — AI calls)
	executeRL := middleware.NewRateLimiter(20, 1*time.Minute)

	v1 := r.Group("/api/v1")
	v1.Use(dbReady)
	{
		user := v1.Group("/user", auth)

		// Mission endpoints
		missions := user.Group("/missions")
		missions.GET("", handler.GetMissions)
		missions.POST("", handler.SaveMission)
		missions.DELETE("/:id", handler.DeleteMission)
		missions.POST("/sync", handler.BatchSyncMissions)
		missions.POST("/expand", handler.ExpandMissions)

		// v3.11.4: template usage metrics (public read; auth-only write)
		v1.GET("/legend/templates/metrics", handler.GetTemplateMetrics)
		v1.POST("/user/legend/templates/:templateId/used", auth, handler.RecordTemplateUse)

		// v3.11.4: mission scheduling (cron-driven re-runs; v3.11.4 fires
		// = UserActivity marker only — actual exec deferred to v3.11.5)
		user.GET("/missions/schedules", handler.ListMissionSchedules)
		user.POST("/missions/:id/schedule", handler.SetMissionSchedule)
		user.DELETE("/missions/:id/schedule", handler.DeleteMissionSchedule)

		// Legend workflow endpoints
		legend := user.Group("/legend")
		legend.GET("/workflows", handler.GetLegendWorkflows)
		legend.POST("/workflows", handler.SaveLegendWorkflow)
		legend.DELETE("/workflows/:id", handler.DeleteLegendWorkflow)
		legend.POST("/workflows/sync", handler.BatchSyncLegendWorkflows)
		legend.POST("/workflows/:id/execute", executeRL.WalletMiddleware(), handler.ExecuteWorkflow)
		legend.GET("/executions", handler.ListExecutions)
		legend.GET("/executions/:execId", handler.GetExecution)
		// v3.10: preflight validator + version history
		legend.GET("/workflows/:id/preflight", handler.PreflightWorkflow)
		legend.GET("/workflows/:id/versions", handler.ListWorkflowVersions)
		legend.GET("/workflows/:id/versions/:versionId", handler.GetWorkflowVersion)

		// Mission marketplace (authenticated: set-public; public: browse/import)
		missions.PATCH("/:id/public", handler.SetMissionPublic)
		missions.POST("/:id/import", handler.ImportPublicMission)

		// v3.11.1: Mission → Legend bridge — one-tap convert mission to workflow.
		missions.POST("/:id/to-legend", handler.ToLegend)

		// Public mission marketplace (no auth needed)
		v1.GET("/missions/public", handler.GetPublicMissions)

		// v3.11.3: resume a failed execution from the last successful node.
		// Dual-auth: JWT (via gateway) OR API key with execute:legend scope.
		// Registered on v1 directly so resumeAuth fully owns auth (no
		// double-auth via the parent user-group middleware).
		v1.POST("/user/legend/executions/:execId/resume",
			resumeAuth, executeRL.WalletMiddleware(), handler.ResumeExecution)
	}

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "workspacesvc", "db_ready": database.IsReady()})
	})

	return r
}

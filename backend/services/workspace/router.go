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

		// Legend workflow endpoints
		legend := user.Group("/legend")
		legend.GET("/workflows", handler.GetLegendWorkflows)
		legend.POST("/workflows", handler.SaveLegendWorkflow)
		legend.DELETE("/workflows/:id", handler.DeleteLegendWorkflow)
		legend.POST("/workflows/sync", handler.BatchSyncLegendWorkflows)
		legend.POST("/workflows/:id/execute", executeRL.WalletMiddleware(), handler.ExecuteWorkflow)
		legend.GET("/executions", handler.ListExecutions)
		legend.GET("/executions/:execId", handler.GetExecution)
	}

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "workspacesvc", "db_ready": database.IsReady()})
	})

	return r
}

package guild

import (
	"net/http"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/middleware"
	"github.com/gin-gonic/gin"
)

// SetupRouter creates the Gin engine for the Guild Service.
func SetupRouter(handler *Handler) *gin.Engine {
	r := gin.Default()

	r.Use(func(c *gin.Context) {
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 2<<20)
		c.Next()
	})

	dbReady := func(c *gin.Context) {
		if !database.IsReady() {
			c.AbortWithStatusJSON(http.StatusServiceUnavailable, gin.H{"error": "database not ready"})
			return
		}
		c.Next()
	}

	auth := middleware.InternalAuth()
	gmRL := middleware.NewRateLimiter(20, 1*time.Minute)

	v1 := r.Group("/api/v1")
	v1.Use(dbReady)
	{
		guilds := v1.Group("/guilds")
		guilds.GET("", handler.ListGuilds)
		guilds.GET("/:id", handler.GetGuild)
		guilds.POST("", auth, handler.CreateGuild)
		guilds.POST("/:id/members", auth, handler.AddMember)
		guilds.DELETE("/:id/members/:agentId", auth, handler.RemoveMember)
		guilds.POST("/:id/join", auth, handler.JoinGuild)
		guilds.DELETE("/:id/join", auth, handler.LeaveGuild)
		guilds.GET("/:id/compatibility", handler.GetCompatibility)

		gm := v1.Group("/guild-master", auth, gmRL.WalletMiddleware())
		gm.POST("/suggest", handler.Suggest)
		gm.POST("/chat", handler.TeamChat)

		// v3.8: persistent chat history + action bridges. Session writes
		// share the gmRL rate limiter with /suggest and /chat so a runaway
		// frontend can't churn the table at unbounded rate.
		gm.GET("/sessions", handler.ListSessions)
		gm.POST("/sessions", handler.CreateSession)
		gm.GET("/sessions/:id", handler.GetSession)
		gm.PATCH("/sessions/:id", handler.UpdateSession)
		gm.DELETE("/sessions/:id", handler.DeleteSession)
		gm.POST("/sessions/:id/messages", handler.AppendMessages)
		gm.POST("/sessions/:id/to-mission", handler.SessionToMission)
		gm.POST("/sessions/:id/to-legend", handler.SessionToLegend)
	}

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "guildsvc", "db_ready": database.IsReady()})
	})

	return r
}

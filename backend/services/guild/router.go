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
	}

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "guildsvc", "db_ready": database.IsReady()})
	})

	return r
}

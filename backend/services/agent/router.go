package agent

import (
	"net/http"
	"path/filepath"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/middleware"
	"github.com/gin-gonic/gin"
)

// SetupRouter creates the Gin engine for the Agent Service.
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

	// Auth middleware reads X-Wallet-Address header from gateway
	auth := middleware.InternalAuth()
	optionalAuth := middleware.OptionalInternalAuth()

	// Per-wallet rate limiters for expensive endpoints
	createRL := middleware.NewRateLimiter(10, 1*time.Hour)
	chatRL := middleware.NewRateLimiter(30, 1*time.Minute)
	forkRL := middleware.NewRateLimiter(10, 1*time.Hour)

	v1 := r.Group("/api/v1")
	v1.Use(dbReady)
	{
		agents := v1.Group("/agents")
		agents.GET("", handler.ListAgents)
		agents.GET("/trending", handler.TrendingAgents)
		agents.GET("/:id", optionalAuth, handler.GetAgent)
		agents.POST("", auth, createRL.WalletMiddleware(), handler.CreateAgent)
		agents.PUT("/:id", auth, handler.UpdateAgent)
		agents.POST("/:id/regenerate-image", auth, createRL.WalletMiddleware(), handler.RegenerateImage)
		agents.POST("/:id/fork", auth, forkRL.WalletMiddleware(), handler.ForkAgent)
		agents.POST("/:id/chat", auth, chatRL.WalletMiddleware(), handler.ChatWithAgent)
		agents.POST("/:id/trial", auth, handler.GenerateTrialToken)
		agents.POST("/:id/purchase", auth, handler.RecordPurchase)
		agents.GET("/:id/purchase-status", auth, handler.GetPurchaseStatus)
		agents.PUT("/:id/price", auth, handler.SetAgentPrice)
		agents.POST("/:id/rate", auth, handler.RateAgent)
		agents.GET("/:id/ratings", handler.GetRatings)

		user := v1.Group("/user", auth)
		user.GET("/library", handler.GetLibrary)
		user.POST("/library/:id", handler.AddToLibrary)
		user.DELETE("/library/:id", handler.RemoveFromLibrary)
		user.GET("/credits", handler.GetCredits)
		user.GET("/credits/history", handler.GetCreditHistory)
		user.POST("/credits/topup", handler.TopUpCredits)
		user.GET("/profile", handler.GetUserProfile)
		user.PATCH("/profile", handler.UpdateProfile)

		// Public trial script endpoint (no auth, token-based)
		v1.GET("/trial/:token/script", handler.GetTrialScript)

		v1.GET("/users/:wallet", handler.GetPublicProfile)
		v1.GET("/leaderboard", handler.GetLeaderboard)
	}

	// Internal endpoints for cross-service communication
	internal := r.Group("/internal")
	{
		internal.GET("/agents/:id", handler.InternalGetAgent)
		internal.POST("/agents/:id/increment-use", handler.InternalIncrementUse)
		internal.POST("/credits/deduct", handler.InternalDeductCredits)
		internal.GET("/credits/:wallet", handler.InternalGetCredits)
	}

	// Serve uploaded images with long-lived cache headers
	r.GET("/api/v1/images/*filepath", func(c *gin.Context) {
		fp := c.Param("filepath")
		if strings.Contains(fp, "..") {
			c.AbortWithStatus(http.StatusBadRequest)
			return
		}
		fullPath := filepath.Join("./uploads", fp)
		c.Header("Cache-Control", "public, max-age=31536000, immutable")
		if strings.HasSuffix(fp, ".webp") {
			c.Header("Content-Type", "image/webp")
		} else if strings.HasSuffix(fp, ".png") {
			c.Header("Content-Type", "image/png")
		}
		c.File(fullPath)
	})

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "agentsvc", "db_ready": database.IsReady()})
	})

	return r
}

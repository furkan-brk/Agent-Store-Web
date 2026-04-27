package auth

import (
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/middleware"
	"github.com/gin-gonic/gin"
)

// SetupRouter creates the Gin engine for the Auth Service.
// Paths match what the gateway forwards: /api/v1/auth/*
func SetupRouter(authSvc *AuthService) *gin.Engine {
	r := gin.Default()

	handler := NewHandler(authSvc)

	// Rate limiter: 20 requests per minute on auth endpoints.
	authRL := middleware.NewRateLimiter(20, 1*time.Minute)

	v1 := r.Group("/api/v1")
	v1.Use(middleware.DBReadiness())
	{
		auth := v1.Group("/auth")
		auth.Use(authRL.Middleware())
		auth.GET("/nonce/:wallet", handler.GetNonce)
		auth.POST("/verify", handler.VerifySignature)
		auth.POST("/abandon", handler.AbandonSignature)
	}

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "auth", "db_ready": database.IsReady()})
	})

	return r
}

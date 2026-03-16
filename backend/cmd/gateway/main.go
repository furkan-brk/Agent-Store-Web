package main

import (
	"log"
	"net/http"

	"github.com/agentstore/backend/pkg/config"
	"github.com/agentstore/backend/pkg/middleware"
	"github.com/agentstore/backend/services/gateway"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	_ = godotenv.Load()
	cfg := config.Load()

	r := gin.Default()
	r.RedirectTrailingSlash = false
	r.RedirectFixedPath = false

	// Request body size limit — 2 MB
	r.Use(func(c *gin.Context) {
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 2<<20)
		c.Next()
	})

	// CORS — gateway is the only entry point for the frontend.
	r.Use(middleware.CORSMiddleware(cfg.AllowedOrigins))

	// JWT extraction — optional on every request.
	// Sets "wallet" in Gin context if a valid JWT is present.
	r.Use(gateway.JWTExtractor(cfg.JWTSecret))

	// Aggregated health check across all downstream services.
	services := []gateway.ServiceHealth{
		{Name: "auth", URL: cfg.AuthServiceURL},
		{Name: "agent", URL: cfg.AgentServiceURL},
		{Name: "aipipeline", URL: cfg.AIPipelineServiceURL},
		{Name: "guild", URL: cfg.GuildServiceURL},
		{Name: "workspace", URL: cfg.WorkspaceServiceURL},
	}
	r.GET("/health", gateway.HealthHandler(services))

	// Reverse proxy — routes all /api/v1/* requests to backend services.
	proxy := gateway.NewProxy(
		cfg.AuthServiceURL,
		cfg.AgentServiceURL,
		cfg.GuildServiceURL,
		cfg.WorkspaceServiceURL,
	)
	r.Any("/api/v1/*path", proxy.Handler())

	port := cfg.Port
	log.Printf("API Gateway starting on :%s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("Gateway error: %v", err)
	}
}

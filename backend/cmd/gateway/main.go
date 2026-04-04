package main

import (
	"crypto/rand"
	"encoding/hex"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/config"
	"github.com/agentstore/backend/pkg/middleware"
	"github.com/agentstore/backend/services/gateway"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
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
	r.GET("/health", gateway.HealthHandler())
	r.GET("/health/full", gateway.FullHealthHandler(services))

	// ── Mock Auth Endpoints (for dev mode when microservices are offline) ──
	
	// Reverse proxy — routes all /api/v1/* requests to backend services.
	proxy := gateway.NewProxy(
		cfg.AuthServiceURL,
		cfg.AgentServiceURL,
		cfg.GuildServiceURL,
		cfg.WorkspaceServiceURL,
	)

	// Handler for all /api/v1/* routes with mock auth bypass
	r.Any("/api/v1/*path", func(c *gin.Context) {
		path := c.Request.URL.Path
		method := c.Request.Method
		
		log.Printf("[DEBUG] Request: %s %s", method, path)
		
		// Mock /auth/nonce/{wallet} endpoint (GET)
		// Path format: /api/v1/auth/nonce/0x...
		if method == "GET" && strings.HasPrefix(path, "/api/v1/auth/nonce/") {
			wallet := strings.TrimPrefix(path, "/api/v1/auth/nonce/")
			if len(wallet) > 0 {
				log.Printf("[MOCK] Generating nonce for wallet: %s", wallet)
				nonce := make([]byte, 16)
				rand.Read(nonce)
				c.JSON(200, gin.H{
					"wallet": wallet,
					"nonce":  hex.EncodeToString(nonce),
				})
				return
			}
		}

		// Mock /auth/verify endpoint (POST)
		if method == "POST" && path == "/api/v1/auth/verify" {
			log.Printf("[MOCK] Processing auth verify")
			var req struct {
				Wallet    string `json:"wallet"`
				Nonce     string `json:"nonce"`
				Signature string `json:"signature"`
			}
			if err := c.BindJSON(&req); err != nil {
				c.JSON(400, gin.H{"error": "invalid request"})
				return
			}

			// Mock JWT — valid for 24 hours
			token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
				"wallet": req.Wallet,
				"exp":    time.Now().Add(24 * time.Hour).Unix(),
			})

			tokenString, err := token.SignedString([]byte(cfg.JWTSecret))
			if err != nil {
				c.JSON(500, gin.H{"error": "token generation failed"})
				return
			}

			// Return 'token' key (not 'jwt') to match Flutter API client expectations
			c.JSON(200, gin.H{
				"token":  tokenString,
				"wallet": req.Wallet,
			})
			return
		}

		// All other routes → proxy to backend services
		log.Printf("[PROXY] Routing %s %s to backend", method, path)
		proxy.Handler()(c)
	})

	port := cfg.Port
	log.Printf("API Gateway starting on :%s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("Gateway error: %v", err)
	}
}

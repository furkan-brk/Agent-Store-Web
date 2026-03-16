package main

import (
	"log"

	"github.com/agentstore/backend/config"
	"github.com/agentstore/backend/internal/api"
	"github.com/agentstore/backend/internal/database"
	"github.com/joho/godotenv"
)

func main() {
	_ = godotenv.Load()
	cfg := config.Load()

	// Connect to DB in background so HTTP server can start immediately
	// (Railway healthcheck hits /health before DB is ready)
	go database.ConnectWithRetry(cfg.PostgresDSN)

	router := api.SetupRouter(cfg.JWTSecret, cfg.AllowedOrigins, cfg.GeminiAPIKey, cfg.ReplicateAPIKey, cfg.RembgURL)
	log.Printf("Agent Store Backend starting on :%s", cfg.Port)
	if err := router.Run(":" + cfg.Port); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}

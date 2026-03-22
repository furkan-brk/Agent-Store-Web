package main

import (
	"log"

	"github.com/agentstore/backend/pkg/cache"
	"github.com/agentstore/backend/pkg/config"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/services/agent"
	"github.com/agentstore/backend/services/agent/client"
	"github.com/joho/godotenv"
)

func main() {
	_ = godotenv.Load()
	cfg := config.Load()

	// Async DB connect — HTTP server starts immediately so Railway healthcheck passes.
	go func() {
		database.ConnectWithRetry(cfg.PostgresDSN)
		agent.Migrate()
	}()

	// Create dependencies.
	aiClient := client.NewAIClient(cfg.AIPipelineServiceURL)
	imageSvc := agent.NewImageService("./uploads", "")
	cacheStore := cache.NewStore()

	agentSvc := agent.NewAgentService(aiClient, imageSvc, cacheStore, cfg.CreditsContract, cfg.TreasuryWallet)
	handler := agent.NewHandler(agentSvc)
	router := agent.SetupRouter(handler)

	port := cfg.Port
	log.Printf("Agent Service starting on :%s", port)
	if err := router.Run(":" + port); err != nil {
		log.Fatalf("Agent Service error: %v", err)
	}
}

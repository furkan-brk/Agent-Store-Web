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

	// Synchronous DB connect — must be ready before serving.
	database.ConnectAndWait(cfg.PostgresDSN)
	agent.Migrate()

	// Create dependencies.
	aiClient := client.NewAIClient(cfg.AIPipelineServiceURL)
	imageSvc := agent.NewImageService("./uploads", "")
	// Restore any missing image files from DB in the background (handles ephemeral disk)
	go imageSvc.HydrateFromDB()
	cacheStore := cache.NewStore()

	agentSvc := agent.NewAgentService(aiClient, imageSvc, cacheStore)
	handler := agent.NewHandler(agentSvc)
	router := agent.SetupRouter(handler)

	port := cfg.Port
	log.Printf("Agent Service starting on :%s", port)
	if err := router.Run(":" + port); err != nil {
		log.Fatalf("Agent Service error: %v", err)
	}
}

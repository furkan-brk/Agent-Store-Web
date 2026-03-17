package main

import (
	"log"

	"github.com/agentstore/backend/pkg/config"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/services/workspace"
	"github.com/agentstore/backend/services/workspace/client"
	"github.com/joho/godotenv"
)

func main() {
	_ = godotenv.Load()
	cfg := config.Load()

	database.ConnectAndWait(cfg.PostgresDSN)
	workspace.Migrate()

	aiClient := client.NewAIClient(cfg.AIPipelineServiceURL)
	agentClient := client.NewAgentClient(cfg.AgentServiceURL)

	missionSvc := workspace.NewMissionService()
	legendSvc := workspace.NewLegendService(aiClient, agentClient, missionSvc)
	handler := workspace.NewHandler(missionSvc, legendSvc)
	router := workspace.SetupRouter(handler)

	port := cfg.Port
	log.Printf("Workspace Service starting on :%s", port)
	if err := router.Run(":" + port); err != nil {
		log.Fatalf("Workspace Service error: %v", err)
	}
}

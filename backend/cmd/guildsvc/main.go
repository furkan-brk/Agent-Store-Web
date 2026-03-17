package main

import (
	"log"

	"github.com/agentstore/backend/pkg/cache"
	"github.com/agentstore/backend/pkg/config"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/services/guild"
	"github.com/agentstore/backend/services/guild/client"
	"github.com/joho/godotenv"
)

func main() {
	_ = godotenv.Load()
	cfg := config.Load()

	database.ConnectAndWait(cfg.PostgresDSN)
	guild.Migrate()

	aiClient := client.NewAIClient(cfg.AIPipelineServiceURL)
	cacheStore := cache.NewStore()

	guildSvc := guild.NewGuildService(aiClient, cacheStore)
	gmSvc := guild.NewGuildMasterService(aiClient)
	handler := guild.NewHandler(guildSvc, gmSvc)
	router := guild.SetupRouter(handler)

	port := cfg.Port
	log.Printf("Guild Service starting on :%s", port)
	if err := router.Run(":" + port); err != nil {
		log.Fatalf("Guild Service error: %v", err)
	}
}

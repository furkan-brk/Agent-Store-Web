package main

import (
	"log"

	"github.com/agentstore/backend/pkg/config"
	"github.com/agentstore/backend/services/aipipeline"
	"github.com/joho/godotenv"
)

func main() {
	_ = godotenv.Load()
	cfg := config.Load()

	// Create all AI sub-services.
	geminiSvc := aipipeline.NewGeminiService(cfg.GeminiAPIKey)
	claudeSvc := aipipeline.NewAIService("") // Claude API key from env if needed
	scoreSvc := aipipeline.NewScoreService(cfg.GeminiAPIKey)

	bgRemover := aipipeline.NewBgRemover(cfg.ClipDropAPIKey)
	pipeline := aipipeline.NewPipelineService(geminiSvc, claudeSvc, scoreSvc, bgRemover)
	router := aipipeline.SetupRouter(pipeline)

	port := cfg.Port
	log.Printf("AI Pipeline Service starting on :%s", port)
	if err := router.Run(":" + port); err != nil {
		log.Fatalf("AI Pipeline service error: %v", err)
	}
}

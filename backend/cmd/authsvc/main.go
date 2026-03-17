package main

import (
	"log"

	"github.com/agentstore/backend/pkg/config"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/services/auth"
	"github.com/joho/godotenv"
)

func main() {
	_ = godotenv.Load()
	cfg := config.Load()

	// Auth service uses synchronous DB connect — must be ready before serving.
	database.ConnectAndWait(cfg.PostgresDSN)
	auth.Migrate()

	authSvc := auth.NewAuthService(cfg.JWTSecret)
	router := auth.SetupRouter(authSvc)

	port := cfg.Port
	log.Printf("Auth Service starting on :%s", port)
	if err := router.Run(":" + port); err != nil {
		log.Fatalf("Auth service error: %v", err)
	}
}

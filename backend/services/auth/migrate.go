package auth

import (
	"log"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
)

// Migrate runs AutoMigrate for the tables owned by the Auth Service.
func Migrate() {
	if err := database.DB.AutoMigrate(&models.User{}); err != nil {
		log.Fatalf("Auth service migration failed: %v", err)
	}
	log.Println("Auth service migration completed")
}

package guild

import (
	"log"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
)

// Migrate runs AutoMigrate for all tables owned by the Guild Service.
func Migrate() {
	if database.DB == nil {
		log.Fatal("Migrate called before database connection established")
	}
	if err := database.DB.AutoMigrate(
		&models.Guild{},
		&models.GuildMember{},
	); err != nil {
		log.Fatalf("Guild Service migration failed: %v", err)
	}
	log.Println("Guild Service migrations complete")
}

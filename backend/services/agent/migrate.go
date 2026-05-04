package agent

import (
	"log"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
)

// Migrate runs AutoMigrate for all tables owned by the Agent Service.
func Migrate() {
	if database.DB == nil {
		log.Fatal("Migrate called before database connection established")
	}
	if err := database.DB.AutoMigrate(
		&models.Agent{},
		&models.LibraryEntry{},
		&models.PurchasedAgent{},
		&models.AgentRating{},
		&models.RatingHelpfulVote{},
		&models.AgentUseLog{},
		&models.TrialUse{},
		&models.TrialToken{},
		&models.CreditTransaction{},
		&models.CreditLedgerEntry{},
		&models.UserFollow{},
		&models.UserActivity{},
	); err != nil {
		log.Fatalf("Agent Service migration failed: %v", err)
	}
	log.Println("Agent Service migrations complete")
}

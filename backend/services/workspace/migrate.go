package workspace

import (
	"log"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
)

// Migrate runs AutoMigrate for all tables owned by the Workspace Service.
func Migrate() {
	if database.DB == nil {
		log.Fatal("Migrate called before database connection established")
	}
	if err := database.DB.AutoMigrate(
		&models.UserMission{},
		&models.UserLegendWorkflow{},
		&models.WorkflowExecution{},
	); err != nil {
		log.Fatalf("Workspace Service migration failed: %v", err)
	}
	log.Println("Workspace Service migrations complete")
}

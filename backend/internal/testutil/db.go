// Package testutil provides shared fixtures for backend service tests.
//
// The DB helper opens an in-memory sqlite connection, runs the same
// AutoMigrate that production uses, and installs it on the global
// database.DB so existing service code (which reads database.DB
// directly) works unchanged.
package testutil

import (
	"testing"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// NewTestDB returns a fresh in-memory sqlite *gorm.DB with all production
// tables migrated. Each call gets an isolated database — perfect for
// parallel tests via t.Parallel().
//
// The returned DB is also installed on database.DB so any code reading the
// global works against the test instance. Tests should call t.Cleanup to
// reset database.DB back to nil.
func NewTestDB(t *testing.T) *gorm.DB {
	t.Helper()

	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatalf("testutil: open sqlite: %v", err)
	}

	if err := db.AutoMigrate(
		&models.User{},
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
		&models.UserMission{},
		&models.UserLegendWorkflow{},
		&models.GuildMasterSession{},
		&models.UserFollow{},
		&models.UserActivity{},
	); err != nil {
		t.Fatalf("testutil: migrate: %v", err)
	}

	prev := database.DB
	database.SetForTest(db)
	t.Cleanup(func() { database.SetForTest(prev) })

	return db
}

package database

import (
	"log"
	"time"

	"github.com/agentstore/backend/internal/models"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

// ConnectWithRetry retries DB connection indefinitely until successful.
// Called in a goroutine so the HTTP server can start (and pass healthcheck) immediately.
func ConnectWithRetry(dsn string) {
	for attempt := 1; ; attempt++ {
		db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
			Logger: logger.Default.LogMode(logger.Info),
		})
		if err == nil {
			DB = db
			log.Println("Database connected")
			// Configure connection pool
			sqlDB, poolErr := db.DB()
			if poolErr == nil {
				sqlDB.SetMaxOpenConns(25)
				sqlDB.SetMaxIdleConns(5)
				sqlDB.SetConnMaxLifetime(5 * time.Minute)
			}
			migrate()
			return
		}
		log.Printf("DB connection attempt %d failed: %v. Retrying in 5s...", attempt, err)
		time.Sleep(5 * time.Second)
	}
}

func migrate() {
	err := DB.AutoMigrate(
		&models.User{},
		&models.Agent{},
		&models.LibraryEntry{},
		&models.Guild{},
		&models.GuildMember{},
		&models.CreditTransaction{},
		&models.PurchasedAgent{},
		&models.AgentRating{},
	)
	if err != nil {
		log.Fatalf("Migration failed: %v", err)
	}
	log.Println("Migration complete")
}

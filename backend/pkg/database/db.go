package database

import (
	"log"
	"os"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// DB is the shared global database connection.
var DB *gorm.DB

// IsReady returns true once the DB connection has been established.
func IsReady() bool {
	return DB != nil
}

// ConnectWithRetry retries DB connection indefinitely until successful.
// Called in a goroutine so the HTTP server can start (and pass healthcheck) immediately.
// Does NOT run migrations — each service calls its own Migrate() after connection.
func ConnectWithRetry(dsn string) {
	logLevel := logger.Info
	if os.Getenv("RAILWAY_ENVIRONMENT") == "production" || os.Getenv("GO_ENV") == "production" {
		logLevel = logger.Warn
	}

	maxAttempts := 30 // give up after ~2.5 minutes
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
			Logger: logger.Default.LogMode(logLevel),
		})
		if err == nil {
			DB = db
			log.Println("Database connected")
			sqlDB, poolErr := db.DB()
			if poolErr == nil {
				sqlDB.SetMaxOpenConns(5)
				sqlDB.SetMaxIdleConns(2)
				sqlDB.SetConnMaxLifetime(5 * time.Minute)
			}
			return
		}
		log.Printf("DB connection attempt %d/%d failed: %v", attempt, maxAttempts, err)
		time.Sleep(5 * time.Second)
	}
	log.Printf("WARNING: database not available after %d attempts, running without DB", maxAttempts)
}

// ConnectAndWait blocks until the DB is connected (synchronous version for services).
func ConnectAndWait(dsn string) {
	ConnectWithRetry(dsn)
}

package guild

import (
	"log"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"gorm.io/gorm"
)

// Migrate runs AutoMigrate for all tables owned by the Guild Service.
func Migrate() {
	if database.DB == nil {
		log.Fatal("Migrate called before database connection established")
	}

	// v3.12-P1-13: prune duplicate GuildMember rows BEFORE AutoMigrate creates
	// the new (guild_id, agent_id) unique index. Without this, AutoMigrate
	// fails on production DBs that accumulated duplicates before the
	// constraint existed.
	if err := dedupeGuildMembers(database.DB); err != nil {
		log.Fatalf("Guild Service dedupe failed: %v", err)
	}

	if err := database.DB.AutoMigrate(
		&models.Guild{},
		&models.GuildMember{},
		&models.GuildInvite{},
		&models.GuildMasterSession{},
		&models.GuildMemberEvent{},
		&models.GuildMasterReflection{},
	); err != nil {
		log.Fatalf("Guild Service migration failed: %v", err)
	}
	log.Println("Guild Service migrations complete")
}

// dedupeGuildMembers removes duplicate GuildMember rows that share the same
// (guild_id, agent_id), keeping only the row with the lowest ID (the original
// join — preserves earliest JoinedAt and lowest-ID-wins is deterministic).
//
// SQL dialect notes:
//   - SQLite accepts the bare subquery `SELECT MIN(id) ... GROUP BY ...` as the
//     RHS of `NOT IN`.
//   - PostgreSQL also accepts it; an inner-table alias is NOT required because
//     no outer name collides with the inner SELECT (we don't reference the
//     outer table inside the subquery). Both dialects work with the same SQL.
//
// Idempotent: if no duplicates exist, the DELETE is a no-op.
func dedupeGuildMembers(db *gorm.DB) error {
	const sql = `DELETE FROM guild_members WHERE id NOT IN (SELECT MIN(id) FROM guild_members GROUP BY guild_id, agent_id)`
	// Skip when the table doesn't exist yet (first-time migration of a fresh
	// DB) — nothing to dedupe.
	if !db.Migrator().HasTable(&models.GuildMember{}) {
		return nil
	}
	return db.Exec(sql).Error
}

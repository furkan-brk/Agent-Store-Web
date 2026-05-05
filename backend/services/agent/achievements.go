package agent

// achievements.go — wallet milestone tracking.
//
// CheckAndAwardAchievements is called from CreateAgent / RecordPurchase /
// ForkAgent (synchronous, best-effort). Each achievement type has a
// deterministic eligibility check; idempotency is enforced via a composite
// unique index (wallet, type) + clause.OnConflict-DoNothing — re-running
// the check after the badge is already awarded is a no-op.
//
// Eligibility rules (v3.11.4):
//   - first_agent     wallet has created at least 1 agent
//   - first_sale      wallet's agent has been purchased at least once
//   - first_fork      wallet has forked at least 1 agent (UserActivity event)
//   - hundred_saves   sum of save_count across wallet's agents >= 100
//   - top_creator     wallet currently sits in the top 10 by save_count
//
// "first_fork" derives from UserActivity rows because Agent doesn't carry a
// parent-link column; the fork sites already RecordActivity with type
// `agent_forked`.

import (
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"gorm.io/gorm/clause"
)

// CheckAndAwardAchievements evaluates all known achievement types for a
// wallet and inserts any newly-earned badges. Always called inline (not via
// goroutine) so the t.Cleanup race documented in v3.9 doesn't bite.
func (s *AgentService) CheckAndAwardAchievements(wallet string) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" || database.DB == nil {
		return
	}

	candidates := []string{}
	if s.qualifiesFirstAgent(wallet) {
		candidates = append(candidates, models.AchievementFirstAgent)
	}
	if s.qualifiesFirstSale(wallet) {
		candidates = append(candidates, models.AchievementFirstSale)
	}
	if s.qualifiesFirstFork(wallet) {
		candidates = append(candidates, models.AchievementFirstFork)
	}
	if s.qualifiesHundredSaves(wallet) {
		candidates = append(candidates, models.AchievementHundredSaves)
	}
	if s.qualifiesTopCreator(wallet) {
		candidates = append(candidates, models.AchievementTopCreator)
	}

	now := time.Now()
	for _, t := range candidates {
		row := models.Achievement{Wallet: wallet, Type: t, EarnedAt: now}
		_ = database.DB.Clauses(clause.OnConflict{DoNothing: true}).Create(&row).Error
	}
}

// ListAchievements returns badges earned by a wallet, newest first.
func (s *AgentService) ListAchievements(wallet string) ([]models.Achievement, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return []models.Achievement{}, nil
	}
	var rows []models.Achievement
	err := database.DB.Where("wallet = ?", wallet).
		Order("earned_at DESC").Find(&rows).Error
	return rows, err
}

func (s *AgentService) qualifiesFirstAgent(wallet string) bool {
	var n int64
	database.DB.Model(&models.Agent{}).
		Where("LOWER(creator_wallet) = ?", wallet).Count(&n)
	return n >= 1
}

func (s *AgentService) qualifiesFirstSale(wallet string) bool {
	// EXISTS subquery joining purchased_agents → agents on agent_id where
	// agent's creator equals the wallet. Dialect-neutral.
	var n int64
	database.DB.Raw(`
		SELECT COUNT(*) FROM purchased_agents p
		INNER JOIN agents a ON a.id = p.agent_id
		WHERE LOWER(a.creator_wallet) = ?`, wallet).Scan(&n)
	return n >= 1
}

func (s *AgentService) qualifiesFirstFork(wallet string) bool {
	var n int64
	database.DB.Model(&models.UserActivity{}).
		Where("wallet = ? AND type = ?", wallet, models.ActivityAgentForked).Count(&n)
	return n >= 1
}

func (s *AgentService) qualifiesHundredSaves(wallet string) bool {
	var sum int64
	database.DB.Raw(`
		SELECT COALESCE(SUM(save_count), 0) FROM agents
		WHERE LOWER(creator_wallet) = ?`, wallet).Scan(&sum)
	return sum >= 100
}

func (s *AgentService) qualifiesTopCreator(wallet string) bool {
	// Top 10 creators by total save_count across their owned agents.
	type row struct {
		CreatorWallet string
		Total         int64
	}
	var rows []row
	database.DB.Raw(`
		SELECT LOWER(creator_wallet) AS creator_wallet, SUM(save_count) AS total
		FROM agents
		GROUP BY LOWER(creator_wallet)
		ORDER BY total DESC
		LIMIT 10`).Scan(&rows)
	for _, r := range rows {
		if r.CreatorWallet == wallet {
			return true
		}
	}
	return false
}

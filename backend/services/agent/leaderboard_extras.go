package agent

// leaderboard_extras.go — v3.11.4 leaderboard extensions:
//   * GetLeaderboardByCategory   — top 10 creators within a single category
//   * GetUserRank                — wallet's rank + 2 above + 2 below neighbors
//   * RecordWeeklyLeaderReward   — pay top 10 creators a credit bonus
//
// Existing GetLeaderboard / GetLeaderboardWindowed in social.go remain
// unchanged and back-compat. These extras share the same dialect-neutral
// SQL pattern (LEFT JOIN with cutoff predicate inside the join condition)
// so the queries run on both sqlite tests and PostgreSQL prod.

import (
	"fmt"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// CategoryLeaderboardEntry is the per-row payload returned by
// GetLeaderboardByCategory. Same shape as LeaderboardEntry plus Category.
type CategoryLeaderboardEntry struct {
	Wallet      string `json:"wallet"`
	Category    string `json:"category"`
	TotalAgents int64  `json:"total_agents"`
	TotalSaves  int64  `json:"total_saves"`
	Rank        int    `json:"rank"`
}

// UserRankEntry is one slot in the "you are here" rail. The 5 returned
// entries are the wallet plus 2 ranks above and 2 below; the IsMe flag tells
// the UI which row to highlight.
type UserRankEntry struct {
	Wallet      string `json:"wallet"`
	Rank        int    `json:"rank"`
	TotalSaves  int64  `json:"total_saves"`
	IsMe        bool   `json:"is_me"`
}

// UserRankResult wraps the rail with a top-level rank so the UI can render
// "Your rank: #42 of 1,238" without a second roundtrip.
type UserRankResult struct {
	Rank      int             `json:"rank"`
	Total     int64           `json:"total_creators"`
	Window    string          `json:"window"`
	Neighbors []UserRankEntry `json:"neighbors"`
}

// WeeklyAwardSummary is the response shape for RecordWeeklyLeaderReward.
type WeeklyAwardSummary struct {
	Week     string                  `json:"week"`
	Skipped  bool                    `json:"skipped"`
	Reason   string                  `json:"reason,omitempty"`
	Rewards  []models.WeeklyLeaderReward `json:"rewards,omitempty"`
}

// rewardSchedule maps rank → credit bonus. v3.11.4 stopgap until a proper
// admin UI lets us tune this per-week.
var rewardSchedule = map[int]int{
	1: 100, 2: 50, 3: 30,
	4: 10, 5: 10, 6: 10, 7: 10, 8: 10, 9: 10, 10: 10,
}

// GetLeaderboardByCategory returns the top-10 creators whose agents fall
// within the given category. window: "7d", "30d", or "all" (default).
func (s *AgentService) GetLeaderboardByCategory(category, window string) ([]CategoryLeaderboardEntry, error) {
	category = strings.ToLower(strings.TrimSpace(category))
	if category == "" {
		return nil, fmt.Errorf("category required")
	}

	cutoff := categoryWindowCutoff(window)

	type row struct {
		Wallet      string
		TotalAgents int64
		TotalSaves  int64
	}
	var rows []row
	if cutoff.IsZero() {
		// "all": straight aggregate from agents.save_count
		err := database.DB.Raw(`
			SELECT
			  creator_wallet AS wallet,
			  COUNT(id)      AS total_agents,
			  SUM(save_count) AS total_saves
			FROM agents
			WHERE creator_wallet != '' AND LOWER(category) = ?
			GROUP BY creator_wallet
			ORDER BY total_saves DESC, total_agents DESC
			LIMIT 10`, category).Scan(&rows).Error
		if err != nil {
			return nil, err
		}
	} else {
		// Windowed: count library_entries within cutoff
		err := database.DB.Raw(`
			SELECT
			  a.creator_wallet AS wallet,
			  COUNT(DISTINCT a.id) AS total_agents,
			  COUNT(DISTINCT le.id) AS total_saves
			FROM agents a
			LEFT JOIN library_entries le ON le.agent_id = a.id AND le.saved_at >= ?
			WHERE a.creator_wallet != '' AND LOWER(a.category) = ?
			GROUP BY a.creator_wallet
			ORDER BY total_saves DESC, total_agents DESC
			LIMIT 10`, cutoff, category).Scan(&rows).Error
		if err != nil {
			return nil, err
		}
	}

	out := make([]CategoryLeaderboardEntry, len(rows))
	for i, r := range rows {
		out[i] = CategoryLeaderboardEntry{
			Wallet: r.Wallet, Category: category,
			TotalAgents: r.TotalAgents, TotalSaves: r.TotalSaves,
			Rank: i + 1,
		}
	}
	return out, nil
}

// rankRow is the internal row shape used by GetUserRank; exported helpers
// take it explicitly to avoid generics gymnastics.
type rankRow struct {
	Wallet     string
	TotalSaves int64
}

// GetUserRank returns the wallet's position in the global leaderboard plus
// up to 4 neighboring rows (2 above + 2 below). When the wallet isn't in the
// ranking at all, Rank=0 and Neighbors holds the bottom 5 as a "join the
// race" hint.
func (s *AgentService) GetUserRank(wallet, window string) (*UserRankResult, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return nil, fmt.Errorf("wallet required")
	}

	cutoff := categoryWindowCutoff(window)
	out := &UserRankResult{Window: normalisedWindowLabel(window)}

	// P1-11: separate COUNT(DISTINCT) so the ordered query can be capped at
	// userRankCandidateLimit without losing the true creator total. Off-board
	// users (rank > limit) fall back to the bottom-5 hint, same as before.
	var totalCreators int64
	var countErr error
	if cutoff.IsZero() {
		countErr = database.DB.Raw(`
			SELECT COUNT(DISTINCT LOWER(creator_wallet))
			FROM agents WHERE creator_wallet != ''`).Scan(&totalCreators).Error
	} else {
		countErr = database.DB.Raw(`
			SELECT COUNT(DISTINCT LOWER(a.creator_wallet))
			FROM agents a
			LEFT JOIN library_entries le ON le.agent_id = a.id AND le.saved_at >= ?
			WHERE a.creator_wallet != ''`, cutoff).Scan(&totalCreators).Error
	}
	if countErr != nil {
		return nil, countErr
	}
	out.Total = totalCreators

	const userRankCandidateLimit = 200

	var rows []rankRow
	var err error
	if cutoff.IsZero() {
		err = database.DB.Raw(`
			SELECT LOWER(creator_wallet) AS wallet, SUM(save_count) AS total_saves
			FROM agents WHERE creator_wallet != ''
			GROUP BY LOWER(creator_wallet)
			ORDER BY total_saves DESC
			LIMIT ?`, userRankCandidateLimit).Scan(&rows).Error
	} else {
		err = database.DB.Raw(`
			SELECT LOWER(a.creator_wallet) AS wallet, COUNT(DISTINCT le.id) AS total_saves
			FROM agents a
			LEFT JOIN library_entries le ON le.agent_id = a.id AND le.saved_at >= ?
			WHERE a.creator_wallet != ''
			GROUP BY LOWER(a.creator_wallet)
			ORDER BY total_saves DESC
			LIMIT ?`, cutoff, userRankCandidateLimit).Scan(&rows).Error
	}
	if err != nil {
		return nil, err
	}

	myIdx := -1
	for i, r := range rows {
		if r.Wallet == wallet {
			myIdx = i
			break
		}
	}

	makeNeighbors := func(slice []rankRow, startRank int) []UserRankEntry {
		ne := make([]UserRankEntry, len(slice))
		for i, r := range slice {
			ne[i] = UserRankEntry{
				Wallet: r.Wallet, Rank: startRank + i, TotalSaves: r.TotalSaves,
				IsMe: r.Wallet == wallet,
			}
		}
		return ne
	}

	if myIdx < 0 {
		// User isn't in the top-N candidate set. Off-board: show the bottom
		// 5 of the (limited) ranked rows as a "join the race" hint. Rank=0
		// signals "off-board" to the UI.
		from := max(len(rows)-5, 0)
		out.Rank = 0
		out.Neighbors = makeNeighbors(rows[from:], from+1)
		return out, nil
	}

	out.Rank = myIdx + 1
	from := max(myIdx-2, 0)
	to := min(myIdx+3, len(rows))
	out.Neighbors = makeNeighbors(rows[from:to], from+1)
	return out, nil
}

// RecordWeeklyLeaderReward picks the current ISO week's top-10 creators
// (all-time leaderboard) and inserts WeeklyLeaderReward rows. Idempotent
// via composite unique on (week, wallet) — the second invocation in the
// same week is a no-op.
//
// Side effect: each rewarded wallet's User.Credits is bumped by the
// rank-appropriate amount. Best-effort: a failed credit update logs but
// doesn't roll back the reward row.
func (s *AgentService) RecordWeeklyLeaderReward() (*WeeklyAwardSummary, error) {
	week := isoWeek(time.Now().UTC())
	out := &WeeklyAwardSummary{Week: week}

	// Idempotency check: have we already paid this week?
	var existing int64
	database.DB.Model(&models.WeeklyLeaderReward{}).
		Where("week = ?", week).Count(&existing)
	if existing > 0 {
		out.Skipped = true
		out.Reason = "already awarded this week"
		return out, nil
	}

	leaders, err := s.GetLeaderboard()
	if err != nil {
		return nil, err
	}
	if len(leaders) == 0 {
		out.Skipped = true
		out.Reason = "no leaderboard entries"
		return out, nil
	}

	rewards := make([]models.WeeklyLeaderReward, 0, len(leaders))
	for _, l := range leaders {
		credits, ok := rewardSchedule[l.Rank]
		if !ok {
			continue
		}
		row := models.WeeklyLeaderReward{
			Week:    week,
			Wallet:  strings.ToLower(l.Wallet),
			Rank:    l.Rank,
			Credits: credits,
		}
		// OnConflict-DoNothing covers the parallel-cron race window.
		res := database.DB.Clauses(clause.OnConflict{DoNothing: true}).Create(&row)
		if res.Error != nil || res.RowsAffected == 0 {
			continue
		}
		// Credit bump: best-effort. A failed update logs but doesn't unwind
		// the reward row — manual reconciliation is preferable to losing
		// the audit trail.
		_ = database.DB.Model(&models.User{}).
			Where("LOWER(wallet_address) = ?", row.Wallet).
			UpdateColumn("credits", gorm.Expr("credits + ?", credits)).Error
		rewards = append(rewards, row)
	}
	out.Rewards = rewards
	return out, nil
}

// ListWeeklyRewards returns the most recent N weeks of paid awards (newest
// first). Used by the FE Weekly Rewards tab.
func (s *AgentService) ListWeeklyRewards(weeks int) ([]models.WeeklyLeaderReward, error) {
	if weeks <= 0 || weeks > 52 {
		weeks = 4
	}
	// Fetch a large enough window (rank 1-10 × N weeks)
	limit := weeks * 10
	var rows []models.WeeklyLeaderReward
	err := database.DB.Order("week DESC, rank ASC").Limit(limit).Find(&rows).Error
	return rows, err
}

// ─── helpers ───────────────────────────────────────────────────────────────

func categoryWindowCutoff(window string) time.Time {
	switch strings.ToLower(strings.TrimSpace(window)) {
	case "7d":
		return time.Now().Add(-7 * 24 * time.Hour)
	case "30d":
		return time.Now().Add(-30 * 24 * time.Hour)
	}
	return time.Time{}
}

func normalisedWindowLabel(window string) string {
	switch strings.ToLower(strings.TrimSpace(window)) {
	case "7d":
		return "7d"
	case "30d":
		return "30d"
	}
	return "all"
}

// isoWeek formats t as "YYYY-Www" with zero-padded week number.
func isoWeek(t time.Time) string {
	year, week := t.ISOWeek()
	return fmt.Sprintf("%04d-W%02d", year, week)
}


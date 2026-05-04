package agent

import (
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
)

// ─── Creator Analytics ────────────────────────────────────────────────────────

// DailyMetric holds a single day's aggregated counts for one agent.
type DailyMetric struct {
	Date   string `json:"date"`    // YYYY-MM-DD
	Saves  int    `json:"saves"`
	Uses   int    `json:"uses"`
	Forks  int    `json:"forks"`
	AgentID uint  `json:"agent_id"`
	AgentTitle string `json:"agent_title"`
}

// AgentInsight bundles totals and daily time-series for one agent.
type AgentInsight struct {
	AgentID    uint          `json:"agent_id"`
	AgentTitle string        `json:"agent_title"`
	TotalSaves int           `json:"total_saves"`
	TotalUses  int           `json:"total_uses"`
	TotalForks int           `json:"total_forks"`
	Daily      []DailyMetric `json:"daily"`
}

// CreatorInsights is the full response for GET /creator/insights.
type CreatorInsights struct {
	Since    string         `json:"since"`
	Agents   []AgentInsight `json:"agents"`
}

// GetCreatorInsights returns per-agent analytics for the creator's agents since a given date.
// since: "7d", "30d", "90d" (default "30d").
func (s *AgentService) GetCreatorInsights(wallet, since string) (*CreatorInsights, error) {
	wallet = strings.ToLower(wallet)

	days := 30
	switch since {
	case "7d":
		days = 7
	case "90d":
		days = 90
	}
	cutoff := time.Now().UTC().AddDate(0, 0, -days)
	sinceLabel := cutoff.Format("2006-01-02")

	// Load creator's agents.
	var agents []models.Agent
	if err := database.DB.
		Select("id, title, save_count, use_count").
		Where("creator_wallet = ?", wallet).
		Find(&agents).Error; err != nil {
		return nil, err
	}
	if len(agents) == 0 {
		return &CreatorInsights{Since: sinceLabel, Agents: []AgentInsight{}}, nil
	}

	agentIDs := make([]uint, len(agents))
	agentMap := make(map[uint]models.Agent, len(agents))
	for i, a := range agents {
		agentIDs[i] = a.ID
		agentMap[a.ID] = a
	}

	// Load timed activity events for the creator's agents.
	var activities []models.UserActivity
	database.DB.
		Where("type IN ? AND ref_id IN ? AND created_at >= ?",
			[]string{models.ActivityAgentSaved, models.ActivityAgentForked, models.ActivityAgentCreated},
			agentIDs, cutoff).
		Order("created_at ASC").
		Find(&activities)

	// Also query library_entries saves (more reliable than activity events for saves).
	type libRow struct {
		AgentID uint
		Day     string
		Count   int
	}
	var libRows []libRow
	database.DB.Raw(`
		SELECT agent_id, strftime('%Y-%m-%d', saved_at) AS day, COUNT(*) AS count
		FROM library_entries
		WHERE agent_id IN ? AND saved_at >= ?
		GROUP BY agent_id, day
	`, agentIDs, cutoff).Scan(&libRows)

	// Use_count rows.
	type useRow struct {
		AgentID uint
		Day     string
		Count   int
	}
	var useRows []useRow
	database.DB.Raw(`
		SELECT agent_id, strftime('%Y-%m-%d', created_at) AS day, COUNT(*) AS count
		FROM agent_use_logs
		WHERE agent_id IN ? AND created_at >= ?
		GROUP BY agent_id, day
	`, agentIDs, cutoff).Scan(&useRows)

	// Build per-agent daily maps.
	type dayKey struct{ agentID uint; day string }
	savesMap := map[dayKey]int{}
	usesMap  := map[dayKey]int{}
	forksMap := map[dayKey]int{}

	for _, r := range libRows {
		savesMap[dayKey{r.AgentID, r.Day}] += r.Count
	}
	for _, r := range useRows {
		usesMap[dayKey{r.AgentID, r.Day}] += r.Count
	}
	for _, a := range activities {
		day := a.CreatedAt.Format("2006-01-02")
		if a.Type == models.ActivityAgentForked {
			forksMap[dayKey{a.RefID, day}]++
		}
	}

	// Build date range.
	var dateRange []string
	for d := 0; d < days; d++ {
		dateRange = append(dateRange, cutoff.AddDate(0, 0, d).Format("2006-01-02"))
	}

	result := make([]AgentInsight, 0, len(agents))
	for _, a := range agents {
		daily := make([]DailyMetric, 0, days)
		totalSaves, totalUses, totalForks := 0, 0, 0

		for _, day := range dateRange {
			s := savesMap[dayKey{a.ID, day}]
			u := usesMap[dayKey{a.ID, day}]
			f := forksMap[dayKey{a.ID, day}]
			totalSaves += s
			totalUses += u
			totalForks += f
			daily = append(daily, DailyMetric{
				Date: day, Saves: s, Uses: u, Forks: f,
				AgentID: a.ID, AgentTitle: a.Title,
			})
		}

		result = append(result, AgentInsight{
			AgentID:    a.ID,
			AgentTitle: a.Title,
			TotalSaves: totalSaves,
			TotalUses:  totalUses,
			TotalForks: totalForks,
			Daily:      daily,
		})
	}

	return &CreatorInsights{Since: sinceLabel, Agents: result}, nil
}

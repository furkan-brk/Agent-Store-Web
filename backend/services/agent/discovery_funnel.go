package agent

// discovery_funnel.go — Store discovery conversion metrics for the KPI panel.
//
// Three ratios derived from user_activities:
//
//   search→save        out of users who ran a search query, how many saved an agent
//   impression→open    out of agent cards rendered, how many were opened
//   open→save          out of agents opened, how many were saved
//
// The numerator/denominator constants match the event types emitted by the
// instrumented handlers (search via ListAgents, impression via batch endpoint,
// open via GetAgent, save via AddToLibrary). This file is a sibling of
// funnel.go (which owns the cross-cutting creator funnel) and reuses
// funnelSinceCutoff + ratio helpers from that file.

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
)

// discovery activity event types — kept distinct from funnel.go's set so the
// two funnels don't share denominators by accident.
const (
	discoveryEventSearch     = "search"
	discoveryEventImpression = "agent_impression"
	discoveryEventOpen       = "agent_open"
	// reuse models.ActivityAgentSaved for the save side
)

// DiscoveryFunnelMetrics is the response shape for GetDiscoveryFunnel.
//
// Each ratio is 0..1 or -1 (no signal) — same -1 sentinel convention as the
// cross-cutting funnel so the KPI panel can render "—" instead of "0%".
type DiscoveryFunnelMetrics struct {
	Wallet            string  `json:"wallet"`
	Since             string  `json:"since"`
	SearchCount       int64   `json:"search_count"`
	ImpressionCount   int64   `json:"impression_count"`
	OpenCount         int64   `json:"open_count"`
	SaveCount         int64   `json:"save_count"`
	SearchToSave      float64 `json:"search_to_save"`
	ImpressionToOpen  float64 `json:"impression_to_open"`
	OpenToSave        float64 `json:"open_to_save"`
}

// GetDiscoveryFunnel returns the wallet's three Store discovery ratios within
// the rolling time window. Cached for 5 min under "discovery_funnel|<wallet>|<since>".
func (s *AgentService) GetDiscoveryFunnel(wallet, since string) (*DiscoveryFunnelMetrics, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return nil, fmt.Errorf("wallet required")
	}

	cutoff, sinceLabel := funnelSinceCutoff(since)
	cacheKey := fmt.Sprintf("discovery_funnel|%s|%s", wallet, since)

	if data, ok := s.cache.Get(cacheKey); ok {
		var cached DiscoveryFunnelMetrics
		if err := json.Unmarshal(data, &cached); err == nil {
			return &cached, nil
		}
	}

	type eventCount struct {
		Type  string
		Count int64
	}
	var counts []eventCount
	database.DB.Raw(`
		SELECT type, COUNT(*) AS count
		FROM user_activities
		WHERE wallet = ? AND created_at >= ?
		GROUP BY type`, wallet, cutoff).Scan(&counts)

	byType := map[string]int64{}
	for _, c := range counts {
		byType[c.Type] = c.Count
	}

	out := &DiscoveryFunnelMetrics{
		Wallet:          wallet,
		Since:           sinceLabel,
		SearchCount:     byType[discoveryEventSearch],
		ImpressionCount: byType[discoveryEventImpression],
		OpenCount:       byType[discoveryEventOpen],
		SaveCount:       byType[models.ActivityAgentSaved],
	}

	out.SearchToSave = ratio(out.SaveCount, out.SearchCount)
	out.ImpressionToOpen = ratio(out.OpenCount, out.ImpressionCount)
	out.OpenToSave = ratio(out.SaveCount, out.OpenCount)

	if b, err := json.Marshal(out); err == nil {
		s.cache.Set(cacheKey, b, 5*time.Minute)
	}
	return out, nil
}

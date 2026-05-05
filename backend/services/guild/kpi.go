package guild

// kpi.go — Guild Master conversion metrics for the KPI panel.
//
// Three derived ratios for the wallet:
//   SuggestAcceptanceRate = bridge_calls / suggest_calls
//   ChatToActionRate      = bridge_calls / chat_calls
//   RerunRate             = (suggest_calls - distinct_sessions) / suggest_calls
//                            (i.e. how often a session re-suggests vs. accepts the first try)
//
// IMPORTANT: this package must NOT import services/agent (would create an
// import cycle with the agent service that already imports types from here in
// the monolith wiring). recordGMActivity therefore writes models.UserActivity
// rows directly via database.DB — same approach as notifyExecutionResult in
// services/workspace/legend_service.go.

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
)

// GM activity event constants (keep in sync with the discovery funnel docs in
// services/agent/funnel.go — these are read by GetGuildMasterKPI here only).
const (
	GMActSuggest        = "gm_suggest"
	GMActBridgeMission  = "gm_bridge_mission"
	GMActBridgeLegend   = "gm_bridge_legend"
	GMActChat           = "gm_chat"
)

// GuildMasterKPI is the struct returned by GetGuildMasterKPI. Each ratio is
// 0.0–1.0 (higher = better) or -1.0 when the denominator is empty so the UI
// can render "—" instead of a misleading "0%". Pattern from v3.11.3 funnel.
type GuildMasterKPI struct {
	Wallet                  string  `json:"wallet"`
	Since                   string  `json:"since"`
	SuggestCount            int64   `json:"suggest_count"`
	ChatCount               int64   `json:"chat_count"`
	BridgeCount             int64   `json:"bridge_count"`
	DistinctSuggestSessions int64   `json:"distinct_suggest_sessions"`
	SuggestAcceptanceRate   float64 `json:"suggest_acceptance_rate"`
	ChatToActionRate        float64 `json:"chat_to_action_rate"`
	RerunRate               float64 `json:"rerun_rate"`
}

// recordGMActivity is the package-internal helper used by handlers/services
// that want to log a Guild Master event. Best-effort: errors do not abort the
// caller. session_id is optional — if non-zero it lands in Metadata so
// RerunRate can group by it.
func recordGMActivity(wallet, actType string, refID, sessionID uint) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" || actType == "" || database.DB == nil {
		return
	}
	row := models.UserActivity{
		Wallet: wallet,
		Type:   actType,
		RefID:  refID,
	}
	if sessionID != 0 {
		if b, err := json.Marshal(map[string]any{"session_id": sessionID}); err == nil {
			row.Metadata = string(b)
		}
	}
	_ = database.DB.Create(&row).Error
}

// GetGuildMasterKPI returns the wallet's three GM conversion ratios within
// the rolling time window. since is "7d", "30d", "90d" or "all" (default).
func (s *GuildMasterService) GetGuildMasterKPI(wallet, since string) (*GuildMasterKPI, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return nil, fmt.Errorf("wallet required")
	}

	cutoff, sinceLabel := parseGMSince(since)

	out := &GuildMasterKPI{Wallet: wallet, Since: sinceLabel}

	// Base query helper — applies the wallet + cutoff filter.
	baseQ := func(actType string) *gormQuery {
		return &gormQuery{
			actType: actType,
			wallet:  wallet,
			cutoff:  cutoff,
		}
	}

	out.SuggestCount = baseQ(GMActSuggest).count()
	out.ChatCount = baseQ(GMActChat).count()
	bridgeMission := baseQ(GMActBridgeMission).count()
	bridgeLegend := baseQ(GMActBridgeLegend).count()
	out.BridgeCount = bridgeMission + bridgeLegend

	// Distinct-session rerun: pull suggest rows + count unique session_ids
	// from Metadata in Go (avoids json_extract dialect divergence).
	out.DistinctSuggestSessions = countDistinctSuggestSessions(wallet, cutoff)

	// Ratios — -1 sentinel when denominator is zero so UI shows "—".
	if out.SuggestCount > 0 {
		out.SuggestAcceptanceRate = float64(out.BridgeCount) / float64(out.SuggestCount)
		// Reruns: extra suggests above the distinct-session count. If the wallet
		// suggests once per session, rerun rate is 0.
		extra := out.SuggestCount - out.DistinctSuggestSessions
		if extra < 0 {
			extra = 0
		}
		out.RerunRate = float64(extra) / float64(out.SuggestCount)
	} else {
		out.SuggestAcceptanceRate = -1
		out.RerunRate = -1
	}
	if out.ChatCount > 0 {
		out.ChatToActionRate = float64(out.BridgeCount) / float64(out.ChatCount)
	} else {
		out.ChatToActionRate = -1
	}
	return out, nil
}

// parseGMSince mirrors the workspace/agent funnel cutoff parser; kept local
// to avoid a cross-package dep.
func parseGMSince(since string) (time.Time, string) {
	switch strings.ToLower(strings.TrimSpace(since)) {
	case "7d":
		return time.Now().Add(-7 * 24 * time.Hour), "7d"
	case "30d", "":
		return time.Now().Add(-30 * 24 * time.Hour), "30d"
	case "90d":
		return time.Now().Add(-90 * 24 * time.Hour), "90d"
	case "all":
		return time.Time{}, "all"
	}
	return time.Now().Add(-30 * 24 * time.Hour), "30d"
}

// countDistinctSuggestSessions iterates suggest rows and counts unique
// session_id values from the JSON metadata column. Rows without a session_id
// are treated as their own session (each contributes 1 unique entry).
func countDistinctSuggestSessions(wallet string, cutoff time.Time) int64 {
	q := database.DB.Model(&models.UserActivity{}).
		Where("wallet = ? AND type = ?", wallet, GMActSuggest)
	if !cutoff.IsZero() {
		q = q.Where("created_at >= ?", cutoff)
	}
	var rows []models.UserActivity
	if err := q.Find(&rows).Error; err != nil {
		return 0
	}
	seen := map[string]bool{}
	noSessionFallback := 0
	for _, r := range rows {
		var meta map[string]any
		if r.Metadata == "" {
			noSessionFallback++
			continue
		}
		if err := json.Unmarshal([]byte(r.Metadata), &meta); err != nil {
			noSessionFallback++
			continue
		}
		sid, ok := meta["session_id"]
		if !ok || sid == nil {
			noSessionFallback++
			continue
		}
		key := fmt.Sprintf("%v", sid)
		seen[key] = true
	}
	return int64(len(seen) + noSessionFallback)
}

// gormQuery is a tiny fluent helper to keep the GetGuildMasterKPI body short.
type gormQuery struct {
	actType string
	wallet  string
	cutoff  time.Time
}

func (q *gormQuery) count() int64 {
	stmt := database.DB.Model(&models.UserActivity{}).
		Where("wallet = ? AND type = ?", q.wallet, q.actType)
	if !q.cutoff.IsZero() {
		stmt = stmt.Where("created_at >= ?", q.cutoff)
	}
	var n int64
	stmt.Count(&n)
	return n
}

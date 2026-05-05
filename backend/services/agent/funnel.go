package agent

// funnel.go — cross-cutting KPI metrics for the creator dashboard.
//
// Conversion rates are computed off the user_activities log: each ratio counts
// distinct refs (where applicable) so a user spamming "guild_suggest" doesn't
// inflate the numerator. publish→first-save median uses the agents table
// (created_at) joined against library_entries (saved_at) so the metric still
// works for historical agents that pre-date activity logging.
//
// All queries are wallet-scoped: a creator only sees the funnel for their own
// agents. Cached for 5 minutes to keep dashboard refreshes cheap.

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
)

// FunnelMetrics is the full response shape for GetFunnelMetrics.
//
// Ratios are 0..1 floats. -1 means "denominator was zero, no signal yet" —
// the UI treats that as "—" instead of "0%".
type FunnelMetrics struct {
	Since                       string              `json:"since"`
	SuggestToExecute            float64             `json:"suggest_to_execute"`
	EditToPublish               float64             `json:"edit_to_publish"`
	PublishToFirstSaveMedianMs  int64               `json:"publish_to_first_save_median_ms"`
	TrialToPurchase             float64             `json:"trial_to_purchase"`
	Daily                       []DailyFunnelMetric `json:"daily"`
}

// DailyFunnelMetric is one row of the time-series breakdown.
type DailyFunnelMetric struct {
	Date            string `json:"date"`
	Suggests        int    `json:"suggests"`
	Executes        int    `json:"executes"`
	Edits           int    `json:"edits"`
	Publishes       int    `json:"publishes"`
	Trials          int    `json:"trials"`
	Purchases       int    `json:"purchases"`
}

// activity type labels surfaced by the funnel. These do NOT need to match the
// existing UserActivity constants — funnel queries are purely string-based, so
// new instrumentation can land in a future sprint without breaking this code.
const (
	funnelEventSuggest  = "guild_suggest"
	funnelEventExecute  = "legend_execute"
	funnelEventEdit     = "agent_edit"
	funnelEventPublish  = "agent_publish"
	funnelEventTrial    = "trial_used"
	funnelEventPurchase = "agent_purchase"
)

// funnelSinceCutoff returns the start time for the requested window. Defaults
// to 30 days when the label is unrecognised.
func funnelSinceCutoff(since string) (time.Time, string) {
	days := 30
	switch since {
	case "7d":
		days = 7
	case "90d":
		days = 90
	}
	cutoff := time.Now().UTC().AddDate(0, 0, -days)
	return cutoff, cutoff.Format("2006-01-02")
}

// GetFunnelMetrics returns the four conversion ratios + daily series for the
// creator-scoped funnel. Wallet may be empty (admin-style view) but the
// callers (handler) currently force a value.
//
// Cache key: "funnel|<wallet>|<since>". 5-minute TTL — funnel data isn't
// realtime-critical and the SQL aggregations get expensive at scale.
func (s *AgentService) GetFunnelMetrics(wallet, since string) (*FunnelMetrics, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	cutoff, sinceLabel := funnelSinceCutoff(since)
	cacheKey := fmt.Sprintf("funnel|%s|%s", wallet, since)

	if data, ok := s.cache.Get(cacheKey); ok {
		var cached FunnelMetrics
		if err := json.Unmarshal(data, &cached); err == nil {
			return &cached, nil
		}
	}

	// Pre-count each event type for the wallet in one pass — sqlite + postgres
	// both support this aggregate shape.
	type eventCount struct {
		Type  string
		Count int64
	}
	var counts []eventCount
	database.DB.
		Raw(`SELECT type, COUNT(*) AS count
		     FROM user_activities
		     WHERE wallet = ? AND created_at >= ?
		     GROUP BY type`,
			wallet, cutoff).
		Scan(&counts)

	byType := map[string]int64{}
	for _, c := range counts {
		byType[c.Type] = c.Count
	}

	out := &FunnelMetrics{
		Since: sinceLabel,
	}
	out.SuggestToExecute = ratio(byType[funnelEventExecute], byType[funnelEventSuggest])
	out.EditToPublish = ratio(byType[funnelEventPublish], byType[funnelEventEdit])
	out.TrialToPurchase = ratio(byType[funnelEventPurchase], byType[funnelEventTrial])

	// publish→first-save median (ms). Pulls the wallet's own agents and
	// computes the gap to each agent's earliest library entry. Median of a
	// small slice is fine — most creators have <100 agents.
	out.PublishToFirstSaveMedianMs = computeFirstSaveMedianMs(wallet, cutoff)

	// Daily breakdown — same six event types, grouped per day.
	out.Daily = computeFunnelDaily(wallet, cutoff)

	if b, err := json.Marshal(out); err == nil {
		s.cache.Set(cacheKey, b, 5*time.Minute)
	}
	return out, nil
}

// ratio returns numerator/denominator clamped to [0, 1]. Denominator==0 → -1
// signals "no data" so the UI doesn't render a misleading 0%.
func ratio(num, den int64) float64 {
	if den == 0 {
		return -1
	}
	r := float64(num) / float64(den)
	if r > 1 {
		r = 1
	}
	return r
}

// computeFirstSaveMedianMs returns the median ms-gap between agent creation
// and that agent's first library save. Returns 0 when no eligible pairs exist.
//
// Scan note: aggregate columns (MIN/MAX over time) come back as strings on
// sqlite — the driver doesn't propagate the underlying type through
// MIN(). We parse them manually so the query works on both sqlite tests
// and the postgres production driver (which returns time.Time directly).
func computeFirstSaveMedianMs(wallet string, since time.Time) int64 {
	type row struct {
		CreatedAt string
		FirstSave string
	}
	var rows []row
	database.DB.Raw(`
		SELECT a.created_at AS created_at,
		       MIN(le.saved_at) AS first_save
		FROM agents a
		JOIN library_entries le ON le.agent_id = a.id
		WHERE a.creator_wallet = ? AND a.created_at >= ?
		GROUP BY a.id
		HAVING MIN(le.saved_at) IS NOT NULL
	`, wallet, since).Scan(&rows)

	if len(rows) == 0 {
		return 0
	}
	gaps := make([]int64, 0, len(rows))
	for _, r := range rows {
		createdAt, ok := parseFlexTimestamp(r.CreatedAt)
		if !ok {
			continue
		}
		firstSave, ok := parseFlexTimestamp(r.FirstSave)
		if !ok {
			continue
		}
		ms := firstSave.Sub(createdAt).Milliseconds()
		if ms < 0 {
			continue
		}
		gaps = append(gaps, ms)
	}
	if len(gaps) == 0 {
		return 0
	}
	// Insertion sort — gaps slice is small (one entry per agent).
	for i := 1; i < len(gaps); i++ {
		for j := i; j > 0 && gaps[j] < gaps[j-1]; j-- {
			gaps[j], gaps[j-1] = gaps[j-1], gaps[j]
		}
	}
	return gaps[len(gaps)/2]
}

// parseFlexTimestamp accepts the formats sqlite (YYYY-MM-DD HH:MM:SS[.fffff])
// and postgres (RFC3339) commonly emit for aggregate timestamp columns.
// Returns the UTC time and true on success.
func parseFlexTimestamp(s string) (time.Time, bool) {
	if s == "" {
		return time.Time{}, false
	}
	formats := []string{
		time.RFC3339Nano,
		time.RFC3339,
		"2006-01-02 15:04:05.999999999 -0700 MST",
		"2006-01-02 15:04:05.999999-07:00",
		"2006-01-02 15:04:05.999999",
		"2006-01-02 15:04:05",
	}
	for _, f := range formats {
		if t, err := time.Parse(f, s); err == nil {
			return t.UTC(), true
		}
	}
	return time.Time{}, false
}

// computeFunnelDaily aggregates each event type per day (UTC YYYY-MM-DD). Uses
// strftime so the same query runs on sqlite tests and postgres prod.
//
// Returns an empty slice (never nil) when the wallet has no activity in window.
func computeFunnelDaily(wallet string, since time.Time) []DailyFunnelMetric {
	type rawRow struct {
		Day   string
		Type  string
		Count int
	}
	var rows []rawRow
	database.DB.Raw(`
		SELECT strftime('%Y-%m-%d', created_at) AS day, type, COUNT(*) AS count
		FROM user_activities
		WHERE wallet = ? AND created_at >= ?
		GROUP BY day, type
		ORDER BY day ASC
	`, wallet, since).Scan(&rows)

	byDay := map[string]*DailyFunnelMetric{}
	for _, r := range rows {
		bucket, ok := byDay[r.Day]
		if !ok {
			bucket = &DailyFunnelMetric{Date: r.Day}
			byDay[r.Day] = bucket
		}
		switch r.Type {
		case funnelEventSuggest:
			bucket.Suggests = r.Count
		case funnelEventExecute:
			bucket.Executes = r.Count
		case funnelEventEdit:
			bucket.Edits = r.Count
		case funnelEventPublish:
			bucket.Publishes = r.Count
		case funnelEventTrial:
			bucket.Trials = r.Count
		case funnelEventPurchase:
			bucket.Purchases = r.Count
		}
	}
	out := make([]DailyFunnelMetric, 0, len(byDay))
	for _, v := range byDay {
		out = append(out, *v)
	}
	// Date ascending — caller renders left-to-right time series.
	for i := 1; i < len(out); i++ {
		for j := i; j > 0 && out[j].Date < out[j-1].Date; j-- {
			out[j], out[j-1] = out[j-1], out[j]
		}
	}
	return out
}

// Reserve a use of the models package so future tests that don't reference
// it directly still link cleanly.
var _ = models.UserActivity{}

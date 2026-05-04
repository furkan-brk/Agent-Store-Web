package agent

// social.go — Follow/Unfollow, activity feed, "For You" recommendations.
// All functions are methods on AgentService so they share the same cache
// and DB handle; no new service type needed.

import (
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// ── Follow / Unfollow ──────────────────────────────────────────────────────

// ErrSelfFollow is returned when a wallet tries to follow itself.
var ErrSelfFollow = fmt.Errorf("cannot follow yourself")

// ErrAlreadyFollowing is returned on duplicate-follow attempts.
var ErrAlreadyFollowing = fmt.Errorf("already following")

// ErrNotFollowing is returned on unfollow when no relationship exists.
var ErrNotFollowing = fmt.Errorf("not following")

// FollowUser creates a follow relationship from followerWallet → followeeWallet.
func (s *AgentService) FollowUser(followerWallet, followeeWallet string) error {
	followerWallet = strings.ToLower(strings.TrimSpace(followerWallet))
	followeeWallet = strings.ToLower(strings.TrimSpace(followeeWallet))
	if followerWallet == followeeWallet {
		return ErrSelfFollow
	}
	f := &models.UserFollow{
		FollowerWallet: followerWallet,
		FolloweeWallet: followeeWallet,
	}
	result := database.DB.
		Clauses(clause.OnConflict{DoNothing: true}).
		Create(f)
	if result.Error != nil {
		return fmt.Errorf("follow: %w", result.Error)
	}
	if result.RowsAffected == 0 {
		return ErrAlreadyFollowing
	}
	return nil
}

// UnfollowUser removes the follow relationship from followerWallet → followeeWallet.
func (s *AgentService) UnfollowUser(followerWallet, followeeWallet string) error {
	followerWallet = strings.ToLower(strings.TrimSpace(followerWallet))
	followeeWallet = strings.ToLower(strings.TrimSpace(followeeWallet))
	result := database.DB.
		Where("follower_wallet = ? AND followee_wallet = ?", followerWallet, followeeWallet).
		Delete(&models.UserFollow{})
	if result.Error != nil {
		return fmt.Errorf("unfollow: %w", result.Error)
	}
	if result.RowsAffected == 0 {
		return ErrNotFollowing
	}
	return nil
}

// IsFollowing returns true if followerWallet currently follows followeeWallet.
func (s *AgentService) IsFollowing(followerWallet, followeeWallet string) bool {
	var f models.UserFollow
	return database.DB.
		Where("follower_wallet = ? AND followee_wallet = ?",
			strings.ToLower(followerWallet),
			strings.ToLower(followeeWallet)).
		First(&f).Error == nil
}

// FollowCounts holds follower and following counts for a profile.
type FollowCounts struct {
	Followers int64 `json:"followers"`
	Following int64 `json:"following"`
}

// GetFollowCounts returns follower/following counts for a wallet.
func (s *AgentService) GetFollowCounts(wallet string) FollowCounts {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	var fc FollowCounts
	database.DB.Model(&models.UserFollow{}).
		Where("followee_wallet = ?", wallet).Count(&fc.Followers)
	database.DB.Model(&models.UserFollow{}).
		Where("follower_wallet = ?", wallet).Count(&fc.Following)
	return fc
}

// FollowerEntry is a compact profile row for a follower/following list.
type FollowerEntry struct {
	Wallet   string `json:"wallet"`
	Username string `json:"username"`
}

// GetFollowers returns wallets that follow the given wallet.
func (s *AgentService) GetFollowers(wallet string) ([]FollowerEntry, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	var follows []models.UserFollow
	if err := database.DB.
		Where("followee_wallet = ?", wallet).
		Order("created_at DESC").
		Limit(100).
		Find(&follows).Error; err != nil {
		return nil, err
	}
	wallets := make([]string, len(follows))
	for i, f := range follows {
		wallets[i] = f.FollowerWallet
	}
	return s.walletsToEntries(wallets), nil
}

// GetFollowing returns wallets that the given wallet follows.
func (s *AgentService) GetFollowing(wallet string) ([]FollowerEntry, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	var follows []models.UserFollow
	if err := database.DB.
		Where("follower_wallet = ?", wallet).
		Order("created_at DESC").
		Limit(100).
		Find(&follows).Error; err != nil {
		return nil, err
	}
	wallets := make([]string, len(follows))
	for i, f := range follows {
		wallets[i] = f.FolloweeWallet
	}
	return s.walletsToEntries(wallets), nil
}

// walletsToEntries looks up usernames for a slice of wallets in one query and
// returns compact FollowerEntry rows. Missing users get an empty username.
func (s *AgentService) walletsToEntries(wallets []string) []FollowerEntry {
	if len(wallets) == 0 {
		return []FollowerEntry{}
	}
	var users []models.User
	database.DB.Where("wallet_address IN ?", wallets).Find(&users)
	byWallet := make(map[string]string, len(users))
	for _, u := range users {
		byWallet[strings.ToLower(u.WalletAddress)] = u.Username
	}
	entries := make([]FollowerEntry, len(wallets))
	for i, w := range wallets {
		entries[i] = FollowerEntry{Wallet: w, Username: byWallet[w]}
	}
	return entries
}

// ── Activity Feed ──────────────────────────────────────────────────────────

// ActivityItem is the public representation of one UserActivity row, with the
// referenced agent's title and character_type hydrated for display.
type ActivityItem struct {
	ID            uint      `json:"id"`
	Type          string    `json:"type"`
	AgentID       uint      `json:"agent_id"`
	AgentTitle    string    `json:"agent_title"`
	CharacterType string    `json:"character_type"`
	Rarity        string    `json:"rarity"`
	ImageURL      string    `json:"image_url"`
	CreatedAt     time.Time `json:"created_at"`
}

// RecordActivity appends one row to the user_activities table.
// Failures are logged but not surfaced — activity recording is best-effort.
func (s *AgentService) RecordActivity(wallet, actType string, refID uint, meta map[string]any) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return
	}
	if database.DB == nil {
		return
	}
	row := &models.UserActivity{
		Wallet: wallet,
		Type:   actType,
		RefID:  refID,
	}
	if len(meta) > 0 {
		if b, err := json.Marshal(meta); err == nil {
			row.Metadata = string(b)
		}
	}
	if err := database.DB.Create(row).Error; err != nil {
		log.Printf("[activity] record %s wallet=%s ref=%d: %v", actType, wallet, refID, err)
	}
}

// GetActivityFeed returns the public activity for a wallet, newest-first, with
// optional ID-cursor pagination (beforeID=0 means start from newest).
func (s *AgentService) GetActivityFeed(wallet string, beforeID uint, limit int) ([]ActivityItem, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	var rows []models.UserActivity
	q := database.DB.Where("wallet = ?", wallet)
	if beforeID > 0 {
		q = q.Where("id < ?", beforeID)
	}
	if err := q.Order("id DESC").Limit(limit).Find(&rows).Error; err != nil {
		return nil, err
	}
	if len(rows) == 0 {
		return []ActivityItem{}, nil
	}
	// Hydrate agent titles/character_type in one batch query.
	refIDs := make([]uint, 0, len(rows))
	seen := map[uint]bool{}
	for _, r := range rows {
		if r.RefID > 0 && !seen[r.RefID] {
			refIDs = append(refIDs, r.RefID)
			seen[r.RefID] = true
		}
	}
	byID := map[uint]models.Agent{}
	if len(refIDs) > 0 {
		var agents []models.Agent
		database.DB.
			Select("id, title, character_type, rarity, image_url").
			Where("id IN ?", refIDs).Find(&agents)
		for _, a := range agents {
			byID[a.ID] = a
		}
	}
	items := make([]ActivityItem, len(rows))
	for i, r := range rows {
		a := byID[r.RefID]
		items[i] = ActivityItem{
			ID:            r.ID,
			Type:          r.Type,
			AgentID:       r.RefID,
			AgentTitle:    a.Title,
			CharacterType: a.CharacterType,
			Rarity:        string(a.Rarity),
			ImageURL:      a.ImageURL,
			CreatedAt:     r.CreatedAt,
		}
	}
	return items, nil
}

// ── "For You" Recommendations ──────────────────────────────────────────────

// GetForYou returns up to 20 agents personalised to the wallet's library. The
// algorithm picks agents whose character_type matches the user's most-saved
// type, not already in their library, ordered by save_count DESC. Falls back
// to trending when the library is empty.
func (s *AgentService) GetForYou(wallet string) ([]models.Agent, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	cacheKey := "for-you|" + wallet
	if data, ok := s.cache.Get(cacheKey); ok {
		var agents []models.Agent
		if err := json.Unmarshal(data, &agents); err == nil {
			return agents, nil
		}
	}

	// 1. Find agent IDs already in the user's library.
	var libEntries []models.LibraryEntry
	database.DB.Where("user_wallet = ?", wallet).Find(&libEntries)
	savedIDs := make([]uint, len(libEntries))
	for i, e := range libEntries {
		savedIDs[i] = e.AgentID
	}

	// 2. Determine preferred character_type from library.
	preferredType := ""
	if len(savedIDs) > 0 {
		type typeCount struct {
			CharacterType string
			Cnt           int64
		}
		var tc typeCount
		database.DB.Model(&models.Agent{}).
			Select("character_type, COUNT(*) as cnt").
			Where("id IN ?", savedIDs).
			Group("character_type").
			Order("cnt DESC").
			Limit(1).
			Scan(&tc)
		preferredType = tc.CharacterType
	}

	// 3. Build recommendation query — exclude already-saved agents.
	q := database.DB.Model(&models.Agent{}).
		Select("id, title, description, service_description, category, creator_wallet, character_type, subclass, rarity, tags, save_count, use_count, image_url, generated_image, price, prompt_score, card_version, created_at")

	if preferredType != "" {
		q = q.Where("character_type = ?", preferredType)
	}
	if len(savedIDs) > 0 {
		q = q.Where("id NOT IN ?", savedIDs)
	}
	// Exclude agents created by this wallet (they see those in their creator dashboard).
	if wallet != "" {
		q = q.Where("creator_wallet != ?", wallet)
	}

	var agents []models.Agent
	if err := q.Order("save_count DESC").Limit(20).Find(&agents).Error; err != nil {
		return nil, err
	}

	// 4. Fallback: if preferred type yields < 5 results, pad with trending.
	if len(agents) < 5 {
		trending, err := s.GetTrending()
		if err == nil {
			existing := map[uint]bool{}
			for _, a := range agents {
				existing[a.ID] = true
			}
			for _, a := range trending {
				alreadySaved := len(savedIDs) > 0 && containsID(savedIDs, a.ID)
				isOwnAgent := wallet != "" && strings.ToLower(a.CreatorWallet) == wallet
				if !existing[a.ID] && !alreadySaved && !isOwnAgent {
					agents = append(agents, a)
					if len(agents) >= 20 {
						break
					}
				}
			}
		}
	}

	if b, err := json.Marshal(agents); err == nil {
		s.cache.Set(cacheKey, b, 5*time.Minute)
	}
	return agents, nil
}

// containsID checks whether id is in the slice (used for small slices).
func containsID(ids []uint, id uint) bool {
	for _, v := range ids {
		if v == id {
			return true
		}
	}
	return false // slices.Contains not used to avoid Go 1.21 dependency constraint
}

// ── Time-windowed Leaderboard ──────────────────────────────────────────────

// GetLeaderboardWindowed returns top-10 creators ranked by saves/uses within
// the requested window. window values: "7d", "30d", "all" (default).
// For windowed queries, counts come from library_entries.saved_at and
// agent_use_logs.created_at so they reflect *recent* activity rather than
// accumulated totals.
func (s *AgentService) GetLeaderboardWindowed(window string) ([]LeaderboardEntry, error) {
	if window == "all" || window == "" {
		return s.GetLeaderboard()
	}

	var cutoff time.Time
	switch window {
	case "7d":
		cutoff = time.Now().Add(-7 * 24 * time.Hour)
	case "30d":
		cutoff = time.Now().Add(-30 * 24 * time.Hour)
	default:
		return s.GetLeaderboard()
	}

	// Join library_entries and agent_use_logs on the cutoff date.
	// Works on both sqlite (? binding → time.Time) and PostgreSQL.
	type row struct {
		Wallet      string
		TotalAgents int64
		TotalSaves  int64
		TotalUses   int64
	}
	var rows []row
	err := database.DB.Raw(`
		SELECT
			a.creator_wallet                         AS wallet,
			COUNT(DISTINCT a.id)                     AS total_agents,
			COUNT(DISTINCT le.id)                    AS total_saves,
			COUNT(DISTINCT ul.id)                    AS total_uses
		FROM agents a
		LEFT JOIN library_entries le
			ON le.agent_id = a.id AND le.saved_at  >= ?
		LEFT JOIN agent_use_logs ul
			ON ul.agent_id = a.id AND ul.created_at >= ?
		WHERE a.creator_wallet != ''
		GROUP BY a.creator_wallet
		ORDER BY total_saves DESC, total_uses DESC
		LIMIT 10
	`, cutoff, cutoff).Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	result := make([]LeaderboardEntry, len(rows))
	for i, r := range rows {
		result[i] = LeaderboardEntry{
			Wallet:      r.Wallet,
			TotalAgents: r.TotalAgents,
			TotalSaves:  r.TotalSaves,
			TotalUses:   r.TotalUses,
			Rank:        i + 1,
		}
	}
	return result, nil
}

// ── OG Meta ───────────────────────────────────────────────────────────────

// OGMeta holds the data needed to render an og: meta HTML fragment.
type OGMeta struct {
	Title       string
	Description string
	ImageURL    string
	AgentURL    string
}

// GetOGMeta returns the Open Graph metadata for one agent, used to build the
// /og/agent/:id HTML response for social crawlers.
func (s *AgentService) GetOGMeta(agentID uint, baseURL string) (*OGMeta, error) {
	var a models.Agent
	if err := database.DB.
		Select("id, title, description, image_url, generated_image").
		First(&a, agentID).Error; err != nil {
		return nil, err
	}
	img := a.ImageURL
	if img == "" {
		// generated_image is base64 stored inline — expose via the /images/ route.
		if a.GeneratedImage != "" {
			img = fmt.Sprintf("%s/api/v1/images/agents/%d.webp", baseURL, a.ID)
		}
	}
	desc := a.Description
	if len(desc) > 160 {
		desc = desc[:157] + "..."
	}
	return &OGMeta{
		Title:       a.Title + " — Agent Store",
		Description: desc,
		ImageURL:    img,
		AgentURL:    fmt.Sprintf("%s/store/%d", baseURL, a.ID),
	}, nil
}

// RenderOGHTML renders a minimal HTML page with og:/twitter: meta tags.
// Social crawlers (Slack, Twitter, OpenGraph) read this; real users get
// redirected to the Flutter SPA via the gateway.
func RenderOGHTML(m *OGMeta) string {
	escape := func(s string) string {
		s = strings.ReplaceAll(s, `&`, "&amp;")
		s = strings.ReplaceAll(s, `"`, "&quot;")
		s = strings.ReplaceAll(s, `<`, "&lt;")
		s = strings.ReplaceAll(s, `>`, "&gt;")
		return s
	}
	return fmt.Sprintf(`<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>%s</title>
<meta property="og:title"       content="%s">
<meta property="og:description" content="%s">
<meta property="og:image"       content="%s">
<meta property="og:url"         content="%s">
<meta property="og:type"        content="website">
<meta name="twitter:card"        content="summary_large_image">
<meta name="twitter:title"       content="%s">
<meta name="twitter:description" content="%s">
<meta name="twitter:image"       content="%s">
<meta http-equiv="refresh" content="0;url=%s">
</head>
<body><a href="%s">%s</a></body>
</html>`,
		escape(m.Title),
		escape(m.Title), escape(m.Description), escape(m.ImageURL), escape(m.AgentURL),
		escape(m.Title), escape(m.Description), escape(m.ImageURL),
		escape(m.AgentURL), escape(m.AgentURL), escape(m.Title),
	)
}

// ── Unused import guard ────────────────────────────────────────────────────
var _ = gorm.ErrRecordNotFound // ensure gorm import is used

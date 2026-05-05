package agent

import (
	"strings"
	"testing"
	"time"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/cache"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// helper: create a minimal AgentService backed by the test DB.
func newSocialTestSvc(t *testing.T) *AgentService {
	t.Helper()
	testutil.NewTestDB(t)
	return NewAgentService(nil, nil, cache.NewStore(), "", "")
}

// ── Follow / Unfollow ──────────────────────────────────────────────────────

func TestFollowUser_CreatesRelationship(t *testing.T) {
	svc := newSocialTestSvc(t)

	err := svc.FollowUser("0xaaa", "0xbbb")
	require.NoError(t, err)
	assert.True(t, svc.IsFollowing("0xaaa", "0xbbb"))
}

func TestFollowUser_RejectsSelfFollow(t *testing.T) {
	svc := newSocialTestSvc(t)

	err := svc.FollowUser("0xaaa", "0xaaa")
	require.ErrorIs(t, err, ErrSelfFollow)
}

func TestFollowUser_DuplicateReturnsAlreadyFollowing(t *testing.T) {
	svc := newSocialTestSvc(t)

	require.NoError(t, svc.FollowUser("0xaaa", "0xbbb"))
	err := svc.FollowUser("0xaaa", "0xbbb")
	require.ErrorIs(t, err, ErrAlreadyFollowing)
}

func TestFollowUser_NormalisesCase(t *testing.T) {
	svc := newSocialTestSvc(t)

	// Upper-case input must be lowercased before storage.
	err := svc.FollowUser("0xAAA", "0xBBB")
	require.NoError(t, err)
	assert.True(t, svc.IsFollowing("0xaaa", "0xbbb"), "lower-case lookup must work after upper-case insert")
}

func TestUnfollowUser_RemovesRelationship(t *testing.T) {
	svc := newSocialTestSvc(t)

	require.NoError(t, svc.FollowUser("0xaaa", "0xbbb"))
	require.NoError(t, svc.UnfollowUser("0xaaa", "0xbbb"))
	assert.False(t, svc.IsFollowing("0xaaa", "0xbbb"))
}

func TestUnfollowUser_NotFollowingReturnsError(t *testing.T) {
	svc := newSocialTestSvc(t)

	err := svc.UnfollowUser("0xaaa", "0xbbb")
	require.ErrorIs(t, err, ErrNotFollowing)
}

func TestGetFollowCounts_Correct(t *testing.T) {
	svc := newSocialTestSvc(t)

	require.NoError(t, svc.FollowUser("0xfan1", "0xstar"))
	require.NoError(t, svc.FollowUser("0xfan2", "0xstar"))
	require.NoError(t, svc.FollowUser("0xstar", "0xsomeone"))

	counts := svc.GetFollowCounts("0xstar")
	assert.Equal(t, int64(2), counts.Followers)
	assert.Equal(t, int64(1), counts.Following)
}

func TestGetFollowers_ReturnsScopedList(t *testing.T) {
	svc := newSocialTestSvc(t)

	require.NoError(t, svc.FollowUser("0xfan1", "0xstar"))
	require.NoError(t, svc.FollowUser("0xfan2", "0xstar"))
	require.NoError(t, svc.FollowUser("0xfan1", "0xother")) // different followee, must not appear

	followers, err := svc.GetFollowers("0xstar")
	require.NoError(t, err)
	require.Len(t, followers, 2)
	wallets := []string{followers[0].Wallet, followers[1].Wallet}
	assert.Contains(t, wallets, "0xfan1")
	assert.Contains(t, wallets, "0xfan2")
}

func TestGetFollowing_ReturnsScopedList(t *testing.T) {
	svc := newSocialTestSvc(t)

	require.NoError(t, svc.FollowUser("0xme", "0xa"))
	require.NoError(t, svc.FollowUser("0xme", "0xb"))
	require.NoError(t, svc.FollowUser("0xother", "0xa")) // different follower, must not appear

	following, err := svc.GetFollowing("0xme")
	require.NoError(t, err)
	require.Len(t, following, 2)
}

// ── Activity Feed ──────────────────────────────────────────────────────────

func TestRecordActivity_PersistsRow(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAgentService(nil, nil, cache.NewStore(), "", "")

	// Create an agent so ref_id is valid (hydration ignores missing refs but
	// the row itself must persist regardless).
	svc.RecordActivity("0xaaa", models.ActivityAgentCreated, 1, map[string]any{
		"title": "My Agent",
	})

	var count int64
	database.DB.Model(&models.UserActivity{}).
		Where("wallet = ? AND type = ?", "0xaaa", models.ActivityAgentCreated).
		Count(&count)
	assert.Equal(t, int64(1), count)
}

func TestRecordActivity_SkipsEmptyWallet(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAgentService(nil, nil, cache.NewStore(), "", "")

	svc.RecordActivity("", models.ActivityAgentCreated, 1, nil)

	var count int64
	database.DB.Model(&models.UserActivity{}).Count(&count)
	assert.Equal(t, int64(0), count, "empty wallet must produce no row")
}

func TestGetActivityFeed_ReturnsCursorPage(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAgentService(nil, nil, cache.NewStore(), "", "")

	// Seed 5 activities.
	for i := 0; i < 5; i++ {
		svc.RecordActivity("0xaaa", models.ActivityAgentSaved, uint(i+1), nil)
	}

	// First page: all 5 (limit 10).
	page1, err := svc.GetActivityFeed("0xaaa", 0, 10)
	require.NoError(t, err)
	require.Len(t, page1, 5)

	// Second page starting before the last item of page1.
	lastID := page1[len(page1)-1].ID
	page2, err := svc.GetActivityFeed("0xaaa", lastID, 10)
	require.NoError(t, err)
	assert.Empty(t, page2, "nothing before the oldest item")
}

func TestGetActivityFeed_ScopedPerWallet(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAgentService(nil, nil, cache.NewStore(), "", "")

	svc.RecordActivity("0xaaa", models.ActivityAgentCreated, 1, nil)
	svc.RecordActivity("0xbbb", models.ActivityAgentCreated, 2, nil)

	feed, err := svc.GetActivityFeed("0xaaa", 0, 20)
	require.NoError(t, err)
	require.Len(t, feed, 1)
	assert.Equal(t, uint(1), feed[0].AgentID)
}

func TestGetActivityFeed_OrderedNewestFirst(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAgentService(nil, nil, cache.NewStore(), "", "")

	// Insert three activities.
	svc.RecordActivity("0xaaa", models.ActivityAgentCreated, 10, nil)
	svc.RecordActivity("0xaaa", models.ActivityAgentSaved, 20, nil)
	svc.RecordActivity("0xaaa", models.ActivityAgentForked, 30, nil)

	feed, err := svc.GetActivityFeed("0xaaa", 0, 20)
	require.NoError(t, err)
	require.Len(t, feed, 3)
	// IDs are auto-incremented so newest has highest ID.
	assert.Greater(t, feed[0].ID, feed[1].ID, "newest item must come first")
	assert.Greater(t, feed[1].ID, feed[2].ID)
}

// ── "For You" Recommendations ──────────────────────────────────────────────

func TestGetForYou_FallsBackToTrendingWhenLibraryEmpty(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAgentService(nil, nil, cache.NewStore(), "", "")

	// Seed two agents so GetTrending returns something.
	a1 := models.Agent{Title: "Wizard Agent", CharacterType: "wizard", Prompt: "x", CreatorWallet: "0xcreator", Rarity: "common"}
	a2 := models.Agent{Title: "Scholar Agent", CharacterType: "scholar", Prompt: "y", CreatorWallet: "0xcreator", Rarity: "common"}
	database.DB.Create(&a1)
	database.DB.Create(&a2)

	recs, err := svc.GetForYou("0xnewuser")
	require.NoError(t, err)
	// Must return at least one agent (trending fallback).
	assert.NotEmpty(t, recs)
}

func TestGetForYou_ExcludesAlreadySavedAgents(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAgentService(nil, nil, cache.NewStore(), "", "")

	a := models.Agent{Title: "Saved Already", CharacterType: "wizard", Prompt: "p", CreatorWallet: "0xcreator", Rarity: "common"}
	database.DB.Create(&a)
	// Put agent in user's library.
	database.DB.Create(&models.LibraryEntry{UserWallet: "0xme", AgentID: a.ID})

	recs, err := svc.GetForYou("0xme")
	require.NoError(t, err)
	for _, r := range recs {
		assert.NotEqual(t, a.ID, r.ID, "already-saved agent must not appear in recommendations")
	}
}

func TestGetForYou_ExcludesSavedWithMixedCaseWallet(t *testing.T) {
	// P1-10: legacy library rows persisted with mixed-case wallets (pre-v3.7
	// lowercasing pass) must still be treated as "saved" when GetForYou is
	// called with the canonical lowercase wallet.
	testutil.NewTestDB(t)
	svc := NewAgentService(nil, nil, cache.NewStore(), "", "")

	a := models.Agent{Title: "Saved Mixed-Case", CharacterType: "wizard", Prompt: "p", CreatorWallet: "0xcreator", Rarity: "common"}
	database.DB.Create(&a)
	// Library row written with the legacy mixed-case wallet.
	database.DB.Create(&models.LibraryEntry{UserWallet: "0xMeMixedCASE", AgentID: a.ID})

	recs, err := svc.GetForYou("0xmemixedcase")
	require.NoError(t, err)
	for _, r := range recs {
		assert.NotEqual(t, a.ID, r.ID, "mixed-case-saved agent must still be excluded from recommendations")
	}
}

func TestGetForYou_ExcludesOwnAgents(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAgentService(nil, nil, cache.NewStore(), "", "")

	myWallet := "0xme"
	a := models.Agent{Title: "My Own Agent", CharacterType: "wizard", Prompt: "p", CreatorWallet: myWallet, Rarity: "common"}
	database.DB.Create(&a)

	recs, err := svc.GetForYou(myWallet)
	require.NoError(t, err)
	for _, r := range recs {
		assert.NotEqual(t, a.ID, r.ID, "creator's own agent must not appear in recommendations")
	}
}

// ── OG Meta ───────────────────────────────────────────────────────────────

func TestGetOGMeta_ReturnsCorrectFields(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAgentService(nil, nil, cache.NewStore(), "", "")

	a := models.Agent{
		Title:       "Wizard Bot",
		Description: "Does wizard things",
		ImageURL:    "https://cdn.example.com/wizard.webp",
		Prompt:      "p",
		CreatorWallet: "0xcreator",
		Rarity:      "common",
	}
	database.DB.Create(&a)

	meta, err := svc.GetOGMeta(a.ID, "https://agentstore.example")
	require.NoError(t, err)
	assert.Contains(t, meta.Title, "Wizard Bot")
	assert.Equal(t, "https://cdn.example.com/wizard.webp", meta.ImageURL)
	assert.Contains(t, meta.AgentURL, "agentstore.example")
}

func TestGetOGMeta_TruncatesLongDescription(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAgentService(nil, nil, cache.NewStore(), "", "")

	a := models.Agent{
		Title:       "Long Desc",
		Description: strings.Repeat("x", 200),
		Prompt:      "p",
		CreatorWallet: "0xcreator",
		Rarity:      "common",
	}
	database.DB.Create(&a)

	meta, err := svc.GetOGMeta(a.ID, "https://example.com")
	require.NoError(t, err)
	assert.LessOrEqual(t, len(meta.Description), 160, "description must be truncated to 160 chars")
}

func TestRenderOGHTML_EscapesSpecialChars(t *testing.T) {
	m := &OGMeta{
		Title:       `Agent <"Store">`,
		Description: "A & B",
		ImageURL:    "https://example.com/img.png",
		AgentURL:    "https://example.com/store/1",
	}
	html := RenderOGHTML(m)
	assert.Contains(t, html, "Agent &lt;&quot;Store&quot;&gt;")
	assert.Contains(t, html, "A &amp; B")
	// Must not contain unescaped < or > inside attribute values.
	assert.NotContains(t, html, `content="Agent <`)
}

// ── Leaderboard time window ────────────────────────────────────────────────

func TestGetLeaderboardWindowed_AllMatchesGetLeaderboard(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAgentService(nil, nil, cache.NewStore(), "", "")

	// Seed one agent with a save_count.
	a := models.Agent{Title: "T", Prompt: "p", CreatorWallet: "0xcreator", Rarity: "common", SaveCount: 5}
	database.DB.Create(&a)

	all, err := svc.GetLeaderboard()
	require.NoError(t, err)

	windowed, err := svc.GetLeaderboardWindowed("all")
	require.NoError(t, err)

	require.Equal(t, len(all), len(windowed))
	if len(all) > 0 {
		assert.Equal(t, all[0].Wallet, windowed[0].Wallet)
	}
}

func TestGetLeaderboardWindowed_7dExcludesOldSaves(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAgentService(nil, nil, cache.NewStore(), "", "")

	a := models.Agent{Title: "T", Prompt: "p", CreatorWallet: "0xcreator", Rarity: "common"}
	database.DB.Create(&a)

	// Insert a library entry saved 30 days ago — must NOT count for 7d window.
	oldSave := models.LibraryEntry{
		UserWallet: "0xold",
		AgentID:    a.ID,
		SavedAt:    time.Now().Add(-30 * 24 * time.Hour),
	}
	database.DB.Create(&oldSave)

	ranked, err := svc.GetLeaderboardWindowed("7d")
	require.NoError(t, err)
	for _, r := range ranked {
		if r.Wallet == "0xcreator" {
			assert.Equal(t, int64(0), r.TotalSaves, "saves from 30 days ago must not count in 7d window")
		}
	}
}

func TestGetLeaderboardWindowed_7dCountsRecentSaves(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAgentService(nil, nil, cache.NewStore(), "", "")

	a := models.Agent{Title: "T", Prompt: "p", CreatorWallet: "0xcreator", Rarity: "common"}
	database.DB.Create(&a)

	// Insert a library entry saved 2 days ago — must count in 7d window.
	recentSave := models.LibraryEntry{
		UserWallet: "0xfan",
		AgentID:    a.ID,
		SavedAt:    time.Now().Add(-2 * 24 * time.Hour),
	}
	database.DB.Create(&recentSave)

	ranked, err := svc.GetLeaderboardWindowed("7d")
	require.NoError(t, err)
	found := false
	for _, r := range ranked {
		if r.Wallet == "0xcreator" {
			assert.Equal(t, int64(1), r.TotalSaves)
			found = true
		}
	}
	assert.True(t, found, "creator with a recent save must appear in leaderboard")
}

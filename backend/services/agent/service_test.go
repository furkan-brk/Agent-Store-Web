package agent

import (
	"encoding/json"
	"errors"
	"strings"
	"testing"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/cache"
	"github.com/agentstore/backend/pkg/models"
	"github.com/agentstore/backend/services/workspace"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// newSvc returns an AgentService backed by the in-memory test DB. AI client
// + image service stay nil — tests must avoid methods that touch them
// (CreateAgent, ForkAgent, ChatWithAgent, RegenerateImage).
func newSvc(t *testing.T) *AgentService {
	t.Helper()
	testutil.NewTestDB(t)
	return NewAgentService(nil, nil, cache.NewStore(), "", "")
}

// ── ListAgents ────────────────────────────────────────────────────────────────

func TestListAgents_EmptyDB(t *testing.T) {
	svc := newSvc(t)
	agents, total, err := svc.ListAgents("", "", "newest", "", 1, 20)
	require.NoError(t, err)
	assert.Empty(t, agents)
	assert.EqualValues(t, 0, total)
}

func TestListAgents_FilterByCategory(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t) // fresh DB to avoid bleed from previous helper
	_ = db
	testutil.NewAgent(t, db, func(a *models.Agent) { a.Category = "backend" })
	testutil.NewAgent(t, db, func(a *models.Agent) { a.Category = "backend" })
	testutil.NewAgent(t, db, func(a *models.Agent) { a.Category = "frontend" })

	got, total, err := svc.ListAgents("backend", "", "newest", "", 1, 20)
	require.NoError(t, err)
	assert.Len(t, got, 2)
	assert.EqualValues(t, 2, total)
}

func TestListAgents_FilterByCreator(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	wallet, _ := testutil.NewWallet(t)
	other, _ := testutil.NewWallet(t)
	testutil.NewAgent(t, db, func(a *models.Agent) { a.CreatorWallet = wallet })
	testutil.NewAgent(t, db, func(a *models.Agent) { a.CreatorWallet = other })

	got, total, err := svc.ListAgents("", "", "newest", wallet, 1, 20)
	require.NoError(t, err)
	assert.Len(t, got, 1)
	assert.EqualValues(t, 1, total)
	assert.Equal(t, wallet, got[0].CreatorWallet)
}

func TestListAgents_Pagination(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	for i := 0; i < 5; i++ {
		testutil.NewAgent(t, db)
	}

	page1, total, err := svc.ListAgents("", "", "newest", "", 1, 2)
	require.NoError(t, err)
	assert.Len(t, page1, 2)
	assert.EqualValues(t, 5, total)

	page3, _, _ := svc.ListAgents("", "", "newest", "", 3, 2)
	assert.Len(t, page3, 1, "last page should have remainder")
}

func TestListAgents_SortPopular(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	a1 := testutil.NewAgent(t, db, func(a *models.Agent) { a.SaveCount = 1; a.UseCount = 1 })
	a2 := testutil.NewAgent(t, db, func(a *models.Agent) { a.SaveCount = 100; a.UseCount = 100 })
	a3 := testutil.NewAgent(t, db, func(a *models.Agent) { a.SaveCount = 10; a.UseCount = 10 })

	got, _, err := svc.ListAgents("", "", "popular", "", 1, 20)
	require.NoError(t, err)
	require.Len(t, got, 3)
	assert.Equal(t, a2.ID, got[0].ID, "highest score first")
	assert.Equal(t, a3.ID, got[1].ID)
	assert.Equal(t, a1.ID, got[2].ID)
}

func TestListAgents_CacheHit(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	testutil.NewAgent(t, db)

	// First call fills cache
	first, _, err := svc.ListAgents("", "", "newest", "", 1, 20)
	require.NoError(t, err)
	require.Len(t, first, 1)

	// Add another row that won't appear because cache wins
	testutil.NewAgent(t, db)
	second, total, _ := svc.ListAgents("", "", "newest", "", 1, 20)
	assert.Len(t, second, 1, "cache should still return stale result")
	assert.EqualValues(t, 1, total)
}

// ── GetAgent ──────────────────────────────────────────────────────────────────

func TestGetAgent_Found(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	a := testutil.NewAgent(t, db)

	got, err := svc.GetAgent(a.ID)
	require.NoError(t, err)
	assert.Equal(t, a.ID, got.ID)
	assert.Equal(t, a.Title, got.Title)
}

func TestGetAgent_NotFound(t *testing.T) {
	svc := newSvc(t)
	_, err := svc.GetAgent(999999)
	assert.Error(t, err)
}

// ── Library ───────────────────────────────────────────────────────────────────

func TestAddToLibrary_IncrementsSaveCount(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	wallet, _ := testutil.NewWallet(t)
	a := testutil.NewAgent(t, db)

	require.NoError(t, svc.AddToLibrary(wallet, a.ID))

	var fresh models.Agent
	db.First(&fresh, a.ID)
	assert.EqualValues(t, 1, fresh.SaveCount)
}

func TestAddToLibrary_Idempotent(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	wallet, _ := testutil.NewWallet(t)
	a := testutil.NewAgent(t, db)

	require.NoError(t, svc.AddToLibrary(wallet, a.ID))
	require.NoError(t, svc.AddToLibrary(wallet, a.ID))

	var count int64
	db.Model(&models.LibraryEntry{}).Count(&count)
	assert.EqualValues(t, 1, count, "duplicate add should be a no-op")

	var fresh models.Agent
	db.First(&fresh, a.ID)
	assert.EqualValues(t, 1, fresh.SaveCount, "save_count must not double-count")
}

func TestRemoveFromLibrary(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	wallet, _ := testutil.NewWallet(t)
	a := testutil.NewAgent(t, db)

	require.NoError(t, svc.AddToLibrary(wallet, a.ID))
	require.NoError(t, svc.RemoveFromLibrary(wallet, a.ID))

	var count int64
	db.Model(&models.LibraryEntry{}).Where("user_wallet = ?", wallet).Count(&count)
	assert.EqualValues(t, 0, count)
}

func TestGetLibrary_OnlyReturnsOwnEntries(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	mine, _ := testutil.NewWallet(t)
	theirs, _ := testutil.NewWallet(t)
	a := testutil.NewAgent(t, db)
	b := testutil.NewAgent(t, db)
	require.NoError(t, svc.AddToLibrary(mine, a.ID))
	require.NoError(t, svc.AddToLibrary(theirs, b.ID))

	got, err := svc.GetLibrary(mine)
	require.NoError(t, err)
	require.Len(t, got, 1)
	assert.Equal(t, a.ID, got[0].AgentID)
}

// ── Credits ───────────────────────────────────────────────────────────────────

func TestGetUserCredits_Existing(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	wallet, _ := testutil.NewWallet(t)
	testutil.NewUser(t, db, wallet)

	got, err := svc.GetUserCredits(wallet)
	require.NoError(t, err)
	assert.EqualValues(t, 100, got)
}

func TestGetUserCredits_UnknownReturnsZeroNotError(t *testing.T) {
	svc := newSvc(t)
	wallet, _ := testutil.NewWallet(t)
	got, err := svc.GetUserCredits(wallet)
	require.NoError(t, err, "unknown wallet should silently return 0")
	assert.EqualValues(t, 0, got)
}

// ── Purchases ─────────────────────────────────────────────────────────────────

func TestIsPurchased_FalseByDefault(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	wallet, _ := testutil.NewWallet(t)
	a := testutil.NewAgent(t, db)
	assert.False(t, svc.IsPurchased(wallet, a.ID))
}

func TestIsPurchased_TrueAfterRecord(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	wallet, _ := testutil.NewWallet(t)
	a := testutil.NewAgent(t, db)
	db.Create(&models.PurchasedAgent{BuyerWallet: wallet, AgentID: a.ID, TxHash: "0xabc"})

	assert.True(t, svc.IsPurchased(wallet, a.ID))
}

// ── UpdateAgent ───────────────────────────────────────────────────────────────

func TestUpdateAgent_OwnerOnly(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	owner, _ := testutil.NewWallet(t)
	intruder, _ := testutil.NewWallet(t)
	a := testutil.NewAgent(t, db, func(a *models.Agent) { a.CreatorWallet = owner })

	newTitle := "Hijacked"
	_, err := svc.UpdateAgent(a.ID, intruder, &UpdateAgentRequest{Title: &newTitle}, nil)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "unauthorized")

	var fresh models.Agent
	db.First(&fresh, a.ID)
	assert.NotEqual(t, "Hijacked", fresh.Title)
}

func TestUpdateAgent_HappyPath(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	owner, _ := testutil.NewWallet(t)
	a := testutil.NewAgent(t, db, func(a *models.Agent) { a.CreatorWallet = owner })

	newTitle := "Renamed"
	newDesc := "fresh desc"
	newPrice := 1.5
	updated, err := svc.UpdateAgent(a.ID, owner, &UpdateAgentRequest{
		Title:       &newTitle,
		Description: &newDesc,
		Price:       &newPrice,
	}, nil)
	require.NoError(t, err)
	assert.Equal(t, "Renamed", updated.Title)
	assert.Equal(t, "fresh desc", updated.Description)
	assert.Equal(t, 1.5, updated.Price)
}

func TestUpdateAgent_TraitsMergedIntoCharacterData(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	owner, _ := testutil.NewWallet(t)
	a := testutil.NewAgent(t, db, func(a *models.Agent) {
		a.CreatorWallet = owner
		a.CharacterData = `{"stats":{"int":5},"traits":["old"]}`
	})

	traits := []string{"new1", "new2"}
	updated, err := svc.UpdateAgent(a.ID, owner, &UpdateAgentRequest{Traits: traits}, nil)
	require.NoError(t, err)

	// stats preserved, traits replaced
	assert.Contains(t, updated.CharacterData, `"int":5`)
	assert.Contains(t, updated.CharacterData, `"new1"`)
	assert.NotContains(t, updated.CharacterData, `"old"`)
}

func TestUpdateAgent_ProfileMoodAndRolePurpose(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	owner, _ := testutil.NewWallet(t)
	a := testutil.NewAgent(t, db, func(a *models.Agent) {
		a.CreatorWallet = owner
		a.CharacterData = `{}`
	})

	mood := "stoic"
	role := "guide"
	updated, err := svc.UpdateAgent(a.ID, owner, &UpdateAgentRequest{
		ProfileMood:        &mood,
		ProfileRolePurpose: &role,
	}, nil)
	require.NoError(t, err)
	assert.Contains(t, updated.CharacterData, `"mood":"stoic"`)
	assert.Contains(t, updated.CharacterData, `"role_purpose":"guide"`)
}

func TestUpdateAgent_IgnoresEmptyStrings(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	owner, _ := testutil.NewWallet(t)
	a := testutil.NewAgent(t, db, func(a *models.Agent) {
		a.CreatorWallet = owner
		a.Title = "Original"
	})

	empty := ""
	updated, err := svc.UpdateAgent(a.ID, owner, &UpdateAgentRequest{Title: &empty}, nil)
	require.NoError(t, err)
	assert.Equal(t, "Original", updated.Title, "empty title is ignored, not applied")
}

// ── BatchGetAgents ────────────────────────────────────────────────────────────

func TestBatchGetAgents_Empty(t *testing.T) {
	svc := newSvc(t)
	got, err := svc.BatchGetAgents(nil, "")
	require.NoError(t, err)
	assert.Empty(t, got)
}

func TestBatchGetAgents_TooMany(t *testing.T) {
	svc := newSvc(t)
	ids := make([]uint, 51)
	_, err := svc.BatchGetAgents(ids, "")
	assert.Error(t, err)
}

func TestBatchGetAgents_HidesPromptForNonOwners(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	owner, _ := testutil.NewWallet(t)
	visitor, _ := testutil.NewWallet(t)
	a := testutil.NewAgent(t, db, func(a *models.Agent) {
		a.CreatorWallet = owner
		a.Prompt = "secret prompt"
	})

	asOwner, _ := svc.BatchGetAgents([]uint{a.ID}, owner)
	require.Len(t, asOwner, 1)
	assert.Equal(t, "secret prompt", asOwner[0].Prompt, "owner sees their prompt")

	asVisitor, _ := svc.BatchGetAgents([]uint{a.ID}, visitor)
	require.Len(t, asVisitor, 1)
	assert.Empty(t, asVisitor[0].Prompt, "non-owner gets empty prompt")
}

// ── IncrementUseCount ─────────────────────────────────────────────────────────

func TestIncrementUseCount(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	a := testutil.NewAgent(t, db)

	svc.IncrementUseCount(a.ID, "", "")
	svc.IncrementUseCount(a.ID, "", "")

	var fresh models.Agent
	db.First(&fresh, a.ID)
	assert.EqualValues(t, 2, fresh.UseCount)
}

// ── GetCategories ─────────────────────────────────────────────────────────────

func TestGetCategories_GroupsAndCounts(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	for range []int{1, 2, 3} {
		testutil.NewAgent(t, db, func(a *models.Agent) { a.Category = "backend" })
	}
	testutil.NewAgent(t, db, func(a *models.Agent) { a.Category = "frontend" })
	testutil.NewAgent(t, db, func(a *models.Agent) { a.Category = "" }) // excluded

	cats, err := svc.GetCategories()
	require.NoError(t, err)
	require.Len(t, cats, 2)

	byKey := map[string]int64{}
	for _, c := range cats {
		byKey[c.Key] = c.Count
	}
	assert.EqualValues(t, 3, byKey["backend"])
	assert.EqualValues(t, 1, byKey["frontend"])
	assert.Equal(t, "Backend", cats[0].Label, "highest-count category is first")
}

// ── GetTrending ───────────────────────────────────────────────────────────────

func TestGetTrending_Top6ByWeightedScore(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	for i := 1; i <= 10; i++ {
		i := i
		testutil.NewAgent(t, db, func(a *models.Agent) {
			a.SaveCount = int64(i)
			a.UseCount = int64(i)
		})
	}

	got, err := svc.GetTrending()
	require.NoError(t, err)
	assert.LessOrEqual(t, len(got), 6, "trending caps at 6")
	if len(got) >= 2 {
		s1 := got[0].SaveCount*3 + got[0].UseCount*2
		s2 := got[1].SaveCount*3 + got[1].UseCount*2
		assert.GreaterOrEqual(t, s1, s2, "results sorted by weighted score desc")
	}
}

// ── Lowercasing/treasury defaults ─────────────────────────────────────────────

func TestNewAgentService_LowercasesAddresses(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAgentService(nil, nil, cache.NewStore(),
		"0xABCDEF0123456789ABCDEF0123456789ABCDEF01",
		"0xFEDCBA9876543210FEDCBA9876543210FEDCBA98",
	)
	assert.Equal(t, strings.ToLower("0xABCDEF0123456789ABCDEF0123456789ABCDEF01"), svc.creditsContract)
	assert.Equal(t, strings.ToLower("0xFEDCBA9876543210FEDCBA9876543210FEDCBA98"), svc.treasuryWallet)
}

// ── Task 1: RevisionID + If-Match ─────────────────────────────────────────────

func TestUpdateAgent_RevisionMatch(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	owner, _ := testutil.NewWallet(t)
	a := testutil.NewAgent(t, db, func(a *models.Agent) { a.CreatorWallet = owner })

	// Default RevisionID after first insert is 1.
	current := a.RevisionID
	require.EqualValues(t, 1, current)

	newTitle := "Approved"
	updated, err := svc.UpdateAgent(a.ID, owner, &UpdateAgentRequest{Title: &newTitle}, &current)
	require.NoError(t, err)
	assert.Equal(t, "Approved", updated.Title)
	assert.EqualValues(t, current+1, updated.RevisionID, "successful update bumps RevisionID by 1")
}

func TestUpdateAgent_RevisionMismatch(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	owner, _ := testutil.NewWallet(t)
	a := testutil.NewAgent(t, db, func(a *models.Agent) { a.CreatorWallet = owner })

	stale := uint64(999)
	hijackTitle := "stolen"
	_, err := svc.UpdateAgent(a.ID, owner, &UpdateAgentRequest{Title: &hijackTitle}, &stale)
	require.Error(t, err)
	var revErr *RevisionMismatchError
	require.True(t, errors.As(err, &revErr), "expected *RevisionMismatchError, got %T", err)
	require.NotNil(t, revErr.Current)
	assert.EqualValues(t, 1, revErr.Current.RevisionID, "current row carries unchanged revision")
	assert.NotEqual(t, "stolen", revErr.Current.Title)

	// Persistent row must be untouched.
	var fresh models.Agent
	db.First(&fresh, a.ID)
	assert.EqualValues(t, 1, fresh.RevisionID)
	assert.NotEqual(t, "stolen", fresh.Title)
}

func TestUpdateAgent_NoIfMatch(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	owner, _ := testutil.NewWallet(t)
	a := testutil.NewAgent(t, db, func(a *models.Agent) { a.CreatorWallet = owner })

	newTitle := "Backwards Compatible"
	updated, err := svc.UpdateAgent(a.ID, owner, &UpdateAgentRequest{Title: &newTitle}, nil)
	require.NoError(t, err, "absent If-Match → backward-compatible behavior")
	assert.Equal(t, "Backwards Compatible", updated.Title)
	assert.EqualValues(t, 2, updated.RevisionID)
}

func TestUpdateAgent_RevisionIncrementsOnSuccess(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	owner, _ := testutil.NewWallet(t)
	a := testutil.NewAgent(t, db, func(a *models.Agent) { a.CreatorWallet = owner })

	t1 := "A"
	t2 := "B"
	t3 := "C"

	_, err := svc.UpdateAgent(a.ID, owner, &UpdateAgentRequest{Title: &t1}, nil)
	require.NoError(t, err)
	_, err = svc.UpdateAgent(a.ID, owner, &UpdateAgentRequest{Title: &t2}, nil)
	require.NoError(t, err)
	final, err := svc.UpdateAgent(a.ID, owner, &UpdateAgentRequest{Title: &t3}, nil)
	require.NoError(t, err)

	assert.EqualValues(t, 4, final.RevisionID, "three updates → revision 1+3=4")
	var fresh models.Agent
	db.First(&fresh, a.ID)
	assert.EqualValues(t, 4, fresh.RevisionID, "DB row reflects bumped revision")
}

// Mission revision tests live alongside the agent tests since the agent_test
// package already has the testutil DB plumbing wired up. testutil.NewTestDB
// installs the in-memory DB on the global database.DB, which workspace.MissionService
// reads directly.
func TestSaveUserMission_RevisionMatchAndMismatch(t *testing.T) {
	db := testutil.NewTestDB(t)
	svc := workspace.NewMissionService()
	wallet, _ := testutil.NewWallet(t)

	in := workspace.SaveMissionInput{
		ID:     "m1",
		Title:  "First Title",
		Slug:   "first-slug",
		Prompt: "Hello prompt body that is long enough.",
	}
	got, err := svc.SaveUserMission(wallet, in, nil)
	require.NoError(t, err)
	require.NotNil(t, got)
	assert.EqualValues(t, 1, got.RevisionID, "fresh row defaults to 1")

	// Match → success, bumps to 2
	rev := got.RevisionID
	in2 := in
	in2.Title = "Updated Title"
	got2, err := svc.SaveUserMission(wallet, in2, &rev)
	require.NoError(t, err)
	assert.EqualValues(t, 2, got2.RevisionID)
	assert.Equal(t, "Updated Title", got2.Title)

	// Mismatch → 409-ish error
	stale := uint64(99)
	_, err = svc.SaveUserMission(wallet, in2, &stale)
	require.Error(t, err)
	var revErr *workspace.MissionRevisionMismatchError
	require.True(t, errors.As(err, &revErr))
	require.NotNil(t, revErr.Current)
	assert.EqualValues(t, 2, revErr.Current.RevisionID)

	// DB row unchanged after mismatch
	var fresh models.UserMission
	db.Where("client_id = ?", "m1").First(&fresh)
	assert.EqualValues(t, 2, fresh.RevisionID)
	assert.Equal(t, "Updated Title", fresh.Title)
}

// ── Task 5: Credit Ledger ─────────────────────────────────────────────────────

func TestAppendLedger_BasicDeduction(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	wallet, _ := testutil.NewWallet(t)
	testutil.NewUser(t, db, wallet)

	require.NoError(t, svc.AppendLedger(wallet, -10, "create_agent", nil, nil))

	var u models.User
	db.Where("wallet_address = ?", wallet).First(&u)
	assert.EqualValues(t, 90, u.Credits)

	var entries []models.CreditLedgerEntry
	db.Where("user_wallet = ?", wallet).Find(&entries)
	require.Len(t, entries, 1)
	assert.EqualValues(t, -10, entries[0].Delta)
	assert.EqualValues(t, 90, entries[0].BalanceAfter)
	assert.Equal(t, "create_agent", entries[0].ActionType)
	assert.Nil(t, entries[0].NodeRef)
	assert.Empty(t, entries[0].CostBreakdown)
}

func TestAppendLedger_WithNodeRef(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	wallet, _ := testutil.NewWallet(t)
	testutil.NewUser(t, db, wallet)

	ref := "wf123:nodeA"
	require.NoError(t, svc.AppendLedger(wallet, -3, "legend_run_node", &ref, nil))

	var entry models.CreditLedgerEntry
	db.Where("user_wallet = ?", wallet).First(&entry)
	require.NotNil(t, entry.NodeRef)
	assert.Equal(t, "wf123:nodeA", *entry.NodeRef)
	assert.Equal(t, "legend_run_node", entry.ActionType)
}

func TestAppendLedger_WithBreakdown(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	wallet, _ := testutil.NewWallet(t)
	testutil.NewUser(t, db, wallet)

	breakdown := map[string]any{
		"model":  "sonnet",
		"tokens": 1234,
	}
	require.NoError(t, svc.AppendLedger(wallet, -3, "legend_run_node", nil, breakdown))

	var entry models.CreditLedgerEntry
	db.Where("user_wallet = ?", wallet).First(&entry)
	require.NotEmpty(t, entry.CostBreakdown)
	var got map[string]any
	require.NoError(t, json.Unmarshal([]byte(entry.CostBreakdown), &got))
	assert.Equal(t, "sonnet", got["model"])
	// JSON numbers come back as float64
	assert.EqualValues(t, 1234, got["tokens"])
}

func TestAppendLedger_InsufficientCredits(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	wallet, _ := testutil.NewWallet(t)
	testutil.NewUser(t, db, wallet) // 100 credits

	err := svc.AppendLedger(wallet, -500, "create_agent", nil, nil)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "insufficient credits")

	var u models.User
	db.Where("wallet_address = ?", wallet).First(&u)
	assert.EqualValues(t, 100, u.Credits, "balance untouched on failure")

	var count int64
	db.Model(&models.CreditLedgerEntry{}).Count(&count)
	assert.EqualValues(t, 0, count, "no ledger row written on failure")
}

func TestGetCreditLedger_Pagination(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	wallet, _ := testutil.NewWallet(t)
	u := testutil.NewUser(t, db, wallet)
	// Bump balance high enough to write 25 deductions.
	db.Model(&models.User{}).Where("wallet_address = ?", u.WalletAddress).
		UpdateColumn("credits", 10000)

	for i := 0; i < 25; i++ {
		require.NoError(t, svc.AppendLedger(wallet, -1, "create_agent", nil, nil))
	}

	page1, total, err := svc.GetCreditLedger(wallet, 1, 10)
	require.NoError(t, err)
	assert.EqualValues(t, 25, total)
	assert.Len(t, page1, 10)

	page3, _, _ := svc.GetCreditLedger(wallet, 3, 10)
	assert.Len(t, page3, 5, "last page has remainder")
}

func TestGetCreditLedger_OnlyMine(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	mine, _ := testutil.NewWallet(t)
	theirs, _ := testutil.NewWallet(t)
	testutil.NewUser(t, db, mine)
	testutil.NewUser(t, db, theirs)

	require.NoError(t, svc.AppendLedger(mine, -5, "create_agent", nil, nil))
	require.NoError(t, svc.AppendLedger(theirs, -10, "create_agent", nil, nil))

	got, total, err := svc.GetCreditLedger(mine, 1, 50)
	require.NoError(t, err)
	require.Len(t, got, 1)
	assert.EqualValues(t, 1, total)
	assert.Equal(t, mine, got[0].UserWallet)
	assert.EqualValues(t, -5, got[0].Delta)
}

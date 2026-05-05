package agent

import (
	"strings"
	"testing"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/cache"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/lib/pq"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// newBulkTestSvc spins up a wallet-scoped AgentService backed by an in-memory
// sqlite. aiClient is nil — bulkRegenerateImage detects that and skips the AI
// call so we can exercise quota + dispatch logic without HTTP plumbing.
func newBulkTestSvc(t *testing.T) *AgentService {
	t.Helper()
	testutil.NewTestDB(t)
	return NewAgentService(nil, nil, cache.NewStore(), "", "")
}

// seedAgent inserts an agent owned by `wallet` and returns its ID.
func seedAgent(t *testing.T, wallet, title string, tags ...string) uint {
	t.Helper()
	agent := &models.Agent{
		Title:         title,
		Prompt:        "stub prompt",
		CreatorWallet: strings.ToLower(wallet),
		CharacterType: "wizard",
		Tags:          pq.StringArray(tags),
	}
	require.NoError(t, database.DB.Create(agent).Error)
	return agent.ID
}

func TestBulkAction_RemoveFromLibrary_SuccessAndIdempotent(t *testing.T) {
	svc := newBulkTestSvc(t)

	// Two agents in library + one not.
	a := seedAgent(t, "0xowner", "A")
	b := seedAgent(t, "0xowner", "B")
	c := seedAgent(t, "0xowner", "C")
	require.NoError(t, svc.AddToLibrary("0xuser", a))
	require.NoError(t, svc.AddToLibrary("0xuser", b))

	res, err := svc.BulkAction("0xuser", "remove_from_library", []uint{a, b, c}, nil)
	require.NoError(t, err)
	require.NotNil(t, res)

	// All three are reported successful — RemoveFromLibrary is a no-op on
	// missing entries, so c must not surface as a failure.
	assert.Len(t, res.Success, 3, "remove_from_library should report all ids as success (idempotent)")
	assert.Len(t, res.Failures, 0)
	assert.EqualValues(t, 0, res.CreditCost, "library remove is free")

	// Verify the library is empty now.
	var entries []models.LibraryEntry
	require.NoError(t, database.DB.Where("user_wallet = ?", "0xuser").Find(&entries).Error)
	assert.Len(t, entries, 0)
}

func TestBulkAction_TagAdd_OwnerOnlyAndIdempotent(t *testing.T) {
	svc := newBulkTestSvc(t)

	mine := seedAgent(t, "0xowner", "Mine", "wizard")
	other := seedAgent(t, "0xother", "Other", "wizard")

	res, err := svc.BulkAction("0xowner", "tag_add",
		[]uint{mine, other},
		map[string]any{"tag": "ai"})
	require.NoError(t, err)
	require.NotNil(t, res)

	// Owned agent succeeds; foreign agent fails (unauthorized).
	assert.Equal(t, []uint{mine}, res.Success)
	require.Len(t, res.Failures, 1)
	assert.Equal(t, other, res.Failures[0].ID)
	assert.Contains(t, res.Failures[0].Error, "unauthorized")

	// Tag was actually appended.
	var refreshed models.Agent
	require.NoError(t, database.DB.First(&refreshed, mine).Error)
	assert.Contains(t, []string(refreshed.Tags), "ai")

	// Calling again is idempotent — no duplicate, still success.
	res2, err := svc.BulkAction("0xowner", "tag_add",
		[]uint{mine},
		map[string]any{"tag": "ai"})
	require.NoError(t, err)
	assert.Len(t, res2.Success, 1)
	require.NoError(t, database.DB.First(&refreshed, mine).Error)
	// Should still be exactly the original tag set + 1 (no dup).
	count := 0
	for _, tg := range refreshed.Tags {
		if strings.EqualFold(tg, "ai") {
			count++
		}
	}
	assert.Equal(t, 1, count, "tag_add must be idempotent — no duplicate insertions")
}

func TestBulkAction_RegenerateImage_QuotaGuardFails(t *testing.T) {
	svc := newBulkTestSvc(t)

	// Owner with low credits (< 3 × 2 = 6 needed).
	user := &models.User{WalletAddress: "0xowner", Credits: 5}
	require.NoError(t, database.DB.Create(user).Error)

	a := seedAgent(t, "0xowner", "A")
	b := seedAgent(t, "0xowner", "B")

	_, err := svc.BulkAction("0xowner", "regenerate_image", []uint{a, b}, nil)
	require.Error(t, err)
	assert.ErrorIs(t, err, ErrBulkInsufficientCredits,
		"quota guard must reject before any regen runs")
}

func TestBulkAction_MaxIDsEnforced(t *testing.T) {
	svc := newBulkTestSvc(t)

	// 101 ids (cap is 100) — we don't even bother seeding, the cap fires first.
	ids := make([]uint, maxBulkIDs+1)
	for i := range ids {
		ids[i] = uint(i + 1)
	}

	_, err := svc.BulkAction("0xowner", "remove_from_library", ids, nil)
	require.Error(t, err)
	assert.ErrorIs(t, err, ErrBulkTooManyIDs)
}

func TestBulkAction_UnknownActionRejected(t *testing.T) {
	svc := newBulkTestSvc(t)

	_, err := svc.BulkAction("0xowner", "delete_agent", []uint{1}, nil)
	require.Error(t, err)
	assert.ErrorIs(t, err, ErrBulkUnknownAction,
		"unknown actions must be rejected before any DB work")
}

func TestBulkAction_WalletIsolation(t *testing.T) {
	svc := newBulkTestSvc(t)

	// Alice owns one agent; Bob (a different wallet) tries to bulk-tag it.
	id := seedAgent(t, "0xalice", "Alice's", "wizard")

	res, err := svc.BulkAction("0xbob", "tag_add",
		[]uint{id},
		map[string]any{"tag": "stolen"})
	require.NoError(t, err)
	require.NotNil(t, res)

	// Bob's request returns success=[] failures=[id]; the agent is untouched.
	assert.Len(t, res.Success, 0)
	require.Len(t, res.Failures, 1)
	assert.Contains(t, res.Failures[0].Error, "unauthorized")

	var refreshed models.Agent
	require.NoError(t, database.DB.First(&refreshed, id).Error)
	for _, tg := range refreshed.Tags {
		assert.NotEqual(t, "stolen", tg, "wallet isolation: foreign caller must not write")
	}
}

// ── v3.12-P0-2 regression tests ──────────────────────────────────────────────
//
// Before FIX 2, bulkRegenerateImage wrote a CreditTransaction row with
// Amount=3 but never decremented users.credits. The wallet got free
// regenerations and the ledger drifted from the actual balance. These tests
// pin the new behavior: balance and ledger move together.

// TestBulkRegenerate_DeductsBalance is the core fix verification —
// after a successful bulk regen, users.credits must drop by 3 × N.
func TestBulkRegenerate_DeductsBalance(t *testing.T) {
	svc := newBulkTestSvc(t)

	// Wallet starts with 10 credits, regen 2 agents (cost = 6) → balance 4.
	user := &models.User{WalletAddress: "0xowner", Credits: 10}
	require.NoError(t, database.DB.Create(user).Error)
	a := seedAgent(t, "0xowner", "A")
	b := seedAgent(t, "0xowner", "B")

	res, err := svc.BulkAction("0xowner", "regenerate_image", []uint{a, b}, nil)
	require.NoError(t, err)
	require.NotNil(t, res)
	assert.Len(t, res.Success, 2, "both agents should succeed")
	assert.Len(t, res.Failures, 0)
	assert.EqualValues(t, 6, res.CreditCost)

	// Balance dropped by exactly 6.
	balance, err := svc.GetUserCredits("0xowner")
	require.NoError(t, err)
	assert.EqualValues(t, 4, balance,
		"users.credits must drop by 3 per agent — bulk regen used to charge the ledger only, never the balance")

	// Ledger has 2 negative spend rows summing to -6 (matches the deduction).
	var txs []models.CreditTransaction
	require.NoError(t, database.DB.Where("wallet = ? AND action = ?", "0xowner", "image_regen").
		Find(&txs).Error)
	require.Len(t, txs, 2, "exactly one ledger row per regen")
	var total int64
	for _, tx := range txs {
		total += tx.Amount
	}
	assert.EqualValues(t, -6, total,
		"ledger amounts are signed: -3 per regen for a total of -6")
}

// TestBulkRegenerate_StopsOnInsufficientBalance covers the up-front quota
// guard. With 5 credits and a 9-credit request (3 × 3), the entire batch
// must be rejected — no partial regen.
func TestBulkRegenerate_StopsOnInsufficientBalance(t *testing.T) {
	svc := newBulkTestSvc(t)

	user := &models.User{WalletAddress: "0xowner", Credits: 5}
	require.NoError(t, database.DB.Create(user).Error)
	a := seedAgent(t, "0xowner", "A")
	b := seedAgent(t, "0xowner", "B")
	c := seedAgent(t, "0xowner", "C")

	_, err := svc.BulkAction("0xowner", "regenerate_image", []uint{a, b, c}, nil)
	require.Error(t, err)
	assert.ErrorIs(t, err, ErrBulkInsufficientCredits)

	// Balance must be unchanged — not even one regen ran.
	balance, gerr := svc.GetUserCredits("0xowner")
	require.NoError(t, gerr)
	assert.EqualValues(t, 5, balance, "quota guard must reject before any regen runs")

	// No ledger rows.
	var n int64
	require.NoError(t, database.DB.Model(&models.CreditTransaction{}).
		Where("wallet = ?", "0xowner").Count(&n).Error)
	assert.EqualValues(t, 0, n, "no ledger writes when the quota guard rejects")
}

// TestBulkRegenerate_PartialFailureRefund covers the per-agent refund path.
// When AI generation succeeds for a (because aiClient is nil and the test
// stub skips the call), but then the per-agent flow fails for b due to a
// foreign-creator check, the per-agent failure path should NOT have charged
// b's wallet — and a's deduction stays.
//
// We simulate the partial-failure shape by feeding ids that include one
// foreign agent: the foreign id fails ownership check BEFORE deduct, so
// the wallet only gets charged for the legitimately-owned ids. This is the
// dispatched per-id contract: each id either succeeds + charges, or fails
// without charging.
func TestBulkRegenerate_PartialFailureRefund(t *testing.T) {
	svc := newBulkTestSvc(t)

	user := &models.User{WalletAddress: "0xowner", Credits: 9}
	require.NoError(t, database.DB.Create(user).Error)

	// Two owned + one foreign. cost = 3 × 3 = 9 ≤ 9, quota guard passes.
	mine1 := seedAgent(t, "0xowner", "Mine1")
	mine2 := seedAgent(t, "0xowner", "Mine2")
	stranger := seedAgent(t, "0xother", "Stranger")

	res, err := svc.BulkAction("0xowner", "regenerate_image",
		[]uint{mine1, mine2, stranger}, nil)
	require.NoError(t, err)
	require.NotNil(t, res)

	assert.Len(t, res.Success, 2, "both owned agents regen")
	require.Len(t, res.Failures, 1)
	assert.Equal(t, stranger, res.Failures[0].ID)
	assert.Contains(t, res.Failures[0].Error, "unauthorized")

	// Charged for the 2 successes only — stranger's failure short-circuits
	// before the deduct (ownership check first), so balance = 9 - 6 = 3.
	balance, gerr := svc.GetUserCredits("0xowner")
	require.NoError(t, gerr)
	assert.EqualValues(t, 3, balance,
		"foreign-agent failure must NOT consume credits — only owned regens deduct")
}

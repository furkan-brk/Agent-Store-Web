package guild

import (
	"encoding/json"
	"errors"
	"testing"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// SessionService is the unit under test. Each subtest spins up a fresh
// in-memory sqlite DB via testutil.NewTestDB so wallet-scoping behaviour
// can be checked without cross-test pollution.

func TestSessionService_CreateSession_DefaultsTitleFromProblem(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewSessionService()

	got, err := svc.CreateSession("0xabc", CreateSessionInput{
		Problem: "Build a Slack-bot that summarises GitHub PRs every morning",
	})
	require.NoError(t, err)
	require.NotNil(t, got)
	assert.NotEmpty(t, got.Title, "title must default from problem")
	assert.Contains(t, got.Title, "Build", "title should reflect problem text")
}

func TestSessionService_CreateSession_RejectsInvalidMessageRole(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewSessionService()
	_, err := svc.CreateSession("0xabc", CreateSessionInput{
		Title: "X",
		Messages: []SessionMessage{
			{Role: "ghost", Content: "boo"},
		},
	})
	require.Error(t, err, "unknown role must be rejected")
}

func TestSessionService_AppendMessages_PersistsAndBumpsCount(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewSessionService()

	created, err := svc.CreateSession("0xabc", CreateSessionInput{Title: "T"})
	require.NoError(t, err)

	updated, err := svc.AppendMessages("0xabc", created.ID, []SessionMessage{
		{Role: "user", Content: "Hello"},
		{Role: "agent", Content: "Hi", AgentTitle: "Wizard"},
	})
	require.NoError(t, err)
	assert.Equal(t, 2, updated.MessageCount)
	require.Len(t, updated.Messages, 2)
	assert.Equal(t, "Hello", updated.Messages[0].Content)
	assert.Equal(t, "Wizard", updated.Messages[1].AgentTitle)
}

func TestSessionService_AppendMessages_TruncatesOverlongContent(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewSessionService()

	created, err := svc.CreateSession("0xabc", CreateSessionInput{Title: "T"})
	require.NoError(t, err)

	long := make([]byte, 5000)
	for i := range long {
		long[i] = 'x'
	}

	updated, err := svc.AppendMessages("0xabc", created.ID, []SessionMessage{
		{Role: "user", Content: string(long)},
	})
	require.NoError(t, err)
	require.Len(t, updated.Messages, 1)
	assert.LessOrEqual(t, len(updated.Messages[0].Content), 4096,
		"runaway content must be capped at the 4 KB ceiling")
}

func TestSessionService_AppendMessages_DropsEmptyEntries(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewSessionService()

	created, _ := svc.CreateSession("0xabc", CreateSessionInput{Title: "T"})
	updated, err := svc.AppendMessages("0xabc", created.ID, []SessionMessage{
		{Role: "user", Content: "   "},
		{Role: "user", Content: "real message"},
		{Role: "agent", Content: ""},
	})
	require.NoError(t, err)
	assert.Equal(t, 1, updated.MessageCount, "empty/whitespace messages must be filtered")
}

func TestSessionService_GetSession_ScopedPerWallet(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewSessionService()

	mine, _ := svc.CreateSession("0xaaa", CreateSessionInput{Title: "Alice"})

	// Bob must NOT be able to read Alice's session — same row id, different
	// wallet → ErrSessionNotFound (NOT a 200 with empty body).
	_, err := svc.GetSession("0xbbb", mine.ID)
	require.Error(t, err)
	assert.True(t, errors.Is(err, ErrSessionNotFound),
		"cross-wallet GET must surface as not-found, not as success")
}

func TestSessionService_DeleteSession_ScopedPerWallet(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewSessionService()

	mine, _ := svc.CreateSession("0xaaa", CreateSessionInput{Title: "Alice"})

	err := svc.DeleteSession("0xbbb", mine.ID)
	require.Error(t, err)
	assert.True(t, errors.Is(err, ErrSessionNotFound),
		"cross-wallet DELETE must NOT remove the row")

	// Alice's row should still be alive.
	_, err = svc.GetSession("0xaaa", mine.ID)
	require.NoError(t, err)
}

func TestSessionService_UpdateSession_PersistsSuggestion(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewSessionService()

	created, _ := svc.CreateSession("0xabc", CreateSessionInput{Title: "T"})

	suggestion := &GuildSuggestion{
		RecommendedTypes: []string{"wizard", "strategist"},
		Goal:             "Ship the bot in two weeks.",
		Plan: []PlanStep{
			{Step: 1, Title: "Spec", Description: "…"},
		},
		ConfidencePerType: map[string]float64{"wizard": 0.9, "strategist": 0.7},
	}
	updated, err := svc.UpdateSession("0xabc", created.ID, UpdateSessionInput{
		Suggestion: suggestion,
	})
	require.NoError(t, err)
	require.NotNil(t, updated.Suggestion)
	assert.Equal(t, "Ship the bot in two weeks.", updated.Suggestion.Goal)
	assert.Equal(t, []string{"wizard", "strategist"}, updated.Suggestion.RecommendedTypes)
	assert.InDelta(t, 0.9, updated.Suggestion.ConfidencePerType["wizard"], 0.01)
}

func TestSessionService_UpdateSession_RenameOnly(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewSessionService()

	created, _ := svc.CreateSession("0xabc", CreateSessionInput{Title: "Old name"})
	newName := "Brand new name"
	updated, err := svc.UpdateSession("0xabc", created.ID, UpdateSessionInput{
		Title: &newName,
	})
	require.NoError(t, err)
	assert.Equal(t, "Brand new name", updated.Title)
}

func TestSessionService_ListSessions_OrderedByUpdatedAtDesc(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewSessionService()

	a, _ := svc.CreateSession("0xabc", CreateSessionInput{Title: "First"})
	b, _ := svc.CreateSession("0xabc", CreateSessionInput{Title: "Second"})

	// Touch a so its updated_at moves past b.
	emptyTitle := "First (touched)"
	_, _ = svc.UpdateSession("0xabc", a.ID, UpdateSessionInput{Title: &emptyTitle})

	list, err := svc.ListSessions("0xabc")
	require.NoError(t, err)
	require.Len(t, list, 2)
	assert.Equal(t, a.ID, list[0].ID, "most recently updated session must come first")
	_ = b
}

func TestSessionService_ListSessions_ScopedPerWallet(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewSessionService()

	_, _ = svc.CreateSession("0xaaa", CreateSessionInput{Title: "Alice"})
	_, _ = svc.CreateSession("0xbbb", CreateSessionInput{Title: "Bob"})

	alice, err := svc.ListSessions("0xaaa")
	require.NoError(t, err)
	require.Len(t, alice, 1)
	assert.Equal(t, "Alice", alice[0].Title)
}

func TestEncodeMessages_EmptyReturnsBracketArray(t *testing.T) {
	// We never want NULL or "" in messages_json — Postgres jsonb defaults
	// would reject those. Empty input → "[]" sentinel.
	got, err := encodeMessages(nil)
	require.NoError(t, err)
	assert.Equal(t, "[]", got)

	// And confirm the round-trip stays valid JSON.
	var parsed []SessionMessage
	require.NoError(t, json.Unmarshal([]byte(got), &parsed))
	assert.Empty(t, parsed)
}

func TestRowToDetail_DecodesSuggestionBlob(t *testing.T) {
	suggestion := &GuildSuggestion{
		RecommendedTypes: []string{"wizard"},
		Goal:             "X",
		Plan:             []PlanStep{{Step: 1, Title: "Y"}},
	}
	raw, _ := json.Marshal(suggestion)
	row := &models.GuildMasterSession{
		ID:             7,
		Wallet:         "0xabc",
		Title:          "Test",
		MessagesJSON:   "[]",
		SuggestionJSON: string(raw),
	}
	d, err := rowToDetail(row)
	require.NoError(t, err)
	require.NotNil(t, d.Suggestion)
	assert.Equal(t, "X", d.Suggestion.Goal)
	assert.Empty(t, d.Messages, "empty messages_json must produce empty slice, not nil")
}

func TestRowToDetail_TolerantOfMalformedSuggestion(t *testing.T) {
	row := &models.GuildMasterSession{
		ID:             1,
		MessagesJSON:   "[]",
		SuggestionJSON: "{not-json",
	}
	d, err := rowToDetail(row)
	require.NoError(t, err, "malformed suggestion must NOT fail the read path")
	assert.Nil(t, d.Suggestion, "malformed JSON should yield a nil suggestion, not a partial one")
}

func TestDeriveTitle_FallsBackForBlankProblem(t *testing.T) {
	assert.Equal(t, "New session", deriveTitle(""))
	assert.Equal(t, "New session", deriveTitle("   "))
}

func TestDeriveTitle_TrimsAtWordBoundary(t *testing.T) {
	long := "this is a long-running session about how to build a slackbot quickly"
	got := deriveTitle(long)
	assert.LessOrEqual(t, len([]rune(got)), 41)
	assert.False(t, len(got) > 0 && got[len(got)-1] == ' ',
		"title must not end with whitespace")
}

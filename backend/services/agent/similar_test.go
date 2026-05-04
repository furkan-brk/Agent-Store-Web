package agent

import (
	"testing"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestGetSimilar_ReturnsSameCharacterType(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	src := testutil.NewAgent(t, db, func(a *models.Agent) {
		a.CharacterType = "wizard"
	})
	// Two more wizards + one strategist (should be excluded).
	testutil.NewAgent(t, db, func(a *models.Agent) { a.CharacterType = "wizard" })
	testutil.NewAgent(t, db, func(a *models.Agent) { a.CharacterType = "wizard" })
	testutil.NewAgent(t, db, func(a *models.Agent) { a.CharacterType = "strategist" })

	got, err := svc.GetSimilar(src.ID, 5)
	require.NoError(t, err)
	require.NotEmpty(t, got)
	for _, a := range got {
		assert.Equal(t, "wizard", a.CharacterType, "all returned agents share source character_type")
	}
}

func TestGetSimilar_ExcludesSourceAgent(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	src := testutil.NewAgent(t, db, func(a *models.Agent) { a.CharacterType = "wizard" })
	testutil.NewAgent(t, db, func(a *models.Agent) { a.CharacterType = "wizard" })

	got, err := svc.GetSimilar(src.ID, 5)
	require.NoError(t, err)
	for _, a := range got {
		assert.NotEqual(t, src.ID, a.ID, "source agent must not appear in similar list")
	}
}

func TestGetSimilar_EmptyResultWhenNoneOfType(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	src := testutil.NewAgent(t, db, func(a *models.Agent) { a.CharacterType = "merchant" })
	// All other agents are wizards.
	testutil.NewAgent(t, db, func(a *models.Agent) { a.CharacterType = "wizard" })
	testutil.NewAgent(t, db, func(a *models.Agent) { a.CharacterType = "wizard" })

	got, err := svc.GetSimilar(src.ID, 5)
	require.NoError(t, err)
	assert.Empty(t, got, "no other merchants → empty (not nil) result")
	assert.NotNil(t, got, "always returns allocated slice for predictable JSON {agents:[]}")
}

func TestGetSimilar_CacheReplaysSameResult(t *testing.T) {
	svc := newSvc(t)
	db := testutil.NewTestDB(t)
	src := testutil.NewAgent(t, db, func(a *models.Agent) { a.CharacterType = "wizard" })
	testutil.NewAgent(t, db, func(a *models.Agent) { a.CharacterType = "wizard" })

	first, err := svc.GetSimilar(src.ID, 5)
	require.NoError(t, err)

	// Add a new wizard — it shouldn't appear because the cache wins.
	testutil.NewAgent(t, db, func(a *models.Agent) { a.CharacterType = "wizard" })
	second, err := svc.GetSimilar(src.ID, 5)
	require.NoError(t, err)

	assert.Equal(t, len(first), len(second), "cache returns same-shape result on repeat call")
}
